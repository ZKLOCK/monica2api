package utils

import (
	"context"
	"encoding/json"
	"fmt"
	"monica-proxy/internal/config"
	"net/http"
	"net/url"
	"os/exec"
	"runtime"
	"strings"
	"time"

	"github.com/go-resty/resty/v2"
)

// CookieValidationResult Cookie 验证结果
type CookieValidationResult struct {
	IsValid   bool   `json:"is_valid"`
	Message   string `json:"message"`
	UserEmail string `json:"user_email,omitempty"`
	ExpiresAt string `json:"expires_at,omitempty"`
}

// ValidateMonicaCookie 验证 Monica Cookie 是否有效
func ValidateMonicaCookie(ctx context.Context, cfg *config.Config, cookie string) (*CookieValidationResult, error) {
	if cookie == "" {
		return &CookieValidationResult{
			IsValid: false,
			Message: "Cookie 不能为空",
		}, nil
	}

	// 创建测试客户端
	client := resty.New().
		SetTimeout(15 * time.Second).
		SetHeaders(map[string]string{
			"accept":           "*/*",
			"accept-language":  "zh-CN,zh;q=0.9,en;q=0.8",
			"content-type":     "application/json",
			"origin":           "https://monica.im",
			"referer":          "https://monica.im/",
			"sec-fetch-dest":   "empty",
			"sec-fetch-mode":   "cors",
			"sec-fetch-site":   "same-site",
			"user-agent":       "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
			"x-client-id":      "3ff5e948-10e9-4a32-8626-f8560b238a42",
			"x-client-locale":  "zh_CN",
			"x-client-type":    "web",
			"x-client-version": "5.4.3",
			"x-product-name":   "Monica",
			"x-time-zone":      "Asia/Shanghai;-480",
			"cookie":           CleanCookie(cookie),
		})

	// 设置代理（如果有）
	if cfg.Proxy.HTTPProxy != "" || cfg.Proxy.HTTPSProxy != "" {
		proxyURL := cfg.Proxy.HTTPProxy
		if proxyURL == "" {
			proxyURL = cfg.Proxy.HTTPSProxy
		}
		client.SetProxy(proxyURL)
	}

	// 尝试调用 Monica 的用户信息接口来验证 Cookie
	// 使用额度查询接口作为验证点
	requestData := map[string]interface{}{
		"modules": []string{"genius_bot", "credits"},
	}

	resp, err := client.R().
		SetContext(ctx).
		SetBody(requestData).
		Post("https://api.monica.im/api/usagev2/get_quotas")

	if err != nil {
		return &CookieValidationResult{
			IsValid: false,
			Message: fmt.Sprintf("网络请求失败：%v", err),
		}, nil
	}

	if resp.StatusCode() != http.StatusOK {
		return &CookieValidationResult{
			IsValid: false,
			Message: fmt.Sprintf("HTTP 错误：%d", resp.StatusCode()),
		}, nil
	}

	// 解析响应
	body := resp.Body()
	var response struct {
		Code int    `json:"code"`
		Msg  string `json:"msg"`
		Data struct {
			ModuleQuotas []struct {
				Module string `json:"module"`
				Quotas []struct {
					Scene          string `json:"scene"`
					CurrentQuota   int    `json:"current_quota"`
					ResetFrequency string `json:"reset_frequency"`
				} `json:"quotas"`
			} `json:"module_quotas"`
		} `json:"data"`
	}

	if err := json.Unmarshal(body, &response); err != nil {
		return &CookieValidationResult{
			IsValid: false,
			Message: fmt.Sprintf("响应解析失败：%v", err),
		}, nil
	}

	// 检查业务错误码
	if response.Code != 0 {
		// Cookie 无效或过期
		if response.Code == 401 || response.Code == 403 {
			return &CookieValidationResult{
				IsValid: false,
				Message: "Cookie 已过期或无效，请重新登录 Monica 获取新 Cookie",
			}, nil
		}
		return &CookieValidationResult{
			IsValid: false,
			Message: fmt.Sprintf("Monica API 错误：%s (code=%d)", response.Msg, response.Code),
		}, nil
	}

	// Cookie 有效，尝试提取用户信息
	var userEmail string
	var expiresAt string

	// 解析 Cookie 查找用户信息
	if cookieData := parseCookie(cookie); cookieData != nil {
		if email, ok := cookieData["user_email"]; ok {
			userEmail = email
		}
		if exp, ok := cookieData["expires"]; ok {
			expiresAt = exp
		}
	}

	// 计算总额度
	var totalQuota int
	for _, module := range response.Data.ModuleQuotas {
		for _, quota := range module.Quotas {
			if quota.Scene == "plan" {
				totalQuota += quota.CurrentQuota
			}
		}
	}

	message := fmt.Sprintf("Cookie 有效！剩余额度：%d", totalQuota)
	if userEmail != "" {
		message = fmt.Sprintf("Cookie 有效！用户：%s，剩余额度：%d", userEmail, totalQuota)
	}

	return &CookieValidationResult{
		IsValid:   true,
		Message:   message,
		UserEmail: userEmail,
		ExpiresAt: expiresAt,
	}, nil
}

// CleanCookie 清理 Cookie 字符串，移除非法字符和多余空格
func CleanCookie(cookie string) string {
	if cookie == "" {
		return ""
	}
	
	// 移除首尾空白字符
	cookie = strings.TrimSpace(cookie)
	
	// 移除可能的换行符和回车符
	cookie = strings.ReplaceAll(cookie, "\n", "")
	cookie = strings.ReplaceAll(cookie, "\r", "")
	
	// 确保 Cookie 格式正确：key=value; key2=value2
	// 修复可能的分号分隔符问题
	cookie = strings.ReplaceAll(cookie, "; ", ";")
	cookie = strings.ReplaceAll(cookie, " ;", ";")
	
	// 检查每个键值对
	var cleanedPairs []string
	pairs := strings.Split(cookie, ";")
	
	for _, pair := range pairs {
		pair = strings.TrimSpace(pair)
		if pair == "" {
			continue
		}
		
		// 分割键值
		parts := strings.SplitN(pair, "=", 2)
		if len(parts) != 2 {
			// 如果格式不正确，跳过这个键值对
			continue
		}
		
		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		
		if key == "" || value == "" {
			continue
		}
		
		// 检查值中是否包含非法字符
		if strings.ContainsAny(value, "\n\r\t") {
			value = strings.ReplaceAll(value, "\n", "")
			value = strings.ReplaceAll(value, "\r", "")
			value = strings.ReplaceAll(value, "\t", "")
		}
		
		cleanedPairs = append(cleanedPairs, fmt.Sprintf("%s=%s", key, value))
	}
	
	return strings.Join(cleanedPairs, "; ")
}

// parseCookie 解析 Cookie 字符串为 map
func parseCookie(cookie string) map[string]string {
	result := make(map[string]string)
	pairs := strings.Split(cookie, ";")

	for _, pair := range pairs {
		pair = strings.TrimSpace(pair)
		if pair == "" {
			continue
		}

		parts := strings.SplitN(pair, "=", 2)
		if len(parts) == 2 {
			key := strings.TrimSpace(parts[0])
			value := strings.TrimSpace(parts[1])
			result[key] = value
		}
	}

	return result
}

// OpenMonicaLogin 在系统默认浏览器中打开 Monica 登录页
func OpenMonicaLogin() error {
	loginURL := "https://monica.im/login"
	return OpenURL(loginURL)
}

// OpenURL 在系统默认浏览器中打开 URL
func OpenURL(urlToOpen string) error {
	var cmd string
	var args []string

	switch runtime.GOOS {
	case "windows":
		cmd = "cmd"
		args = []string{"/c", "start"}
	case "darwin": // macOS
		cmd = "open"
		args = []string{}
	default: // Linux
		cmd = "xdg-open"
		args = []string{}
	}

	args = append(args, urlToOpen)
	return exec.Command(cmd, args...).Start()
}

// GetCookieScript 返回用于在浏览器控制台复制 Cookie 的 JavaScript 代码
func GetCookieScript() string {
	return `// Monica Cookie 复制脚本
// 在 Monica 页面 (https://monica.im) 的浏览器控制台中运行此脚本

(function() {
  // 获取所有 Cookie
  const cookie = document.cookie;
  
  // 复制到剪贴板
  navigator.clipboard.writeText(cookie).then(() => {
    console.log('✅ Cookie 已复制到剪贴板！');
    alert('✅ Cookie 已复制到剪贴板！\\n\\n请回到 Monica Proxy 应用，粘贴到 Cookie 输入框中。');
  }).catch(err => {
    console.error('复制失败:', err);
    // 如果剪贴板 API 失败，显示在控制台
    console.log('\\n====== Cookie 内容 ======');
    console.log(cookie);
    console.log('========================\\n');
    alert('⚠️ 剪贴板 API 失败，Cookie 已输出到控制台，请手动复制。');
  });
  
  // 同时显示 Cookie 概览
  const cookieObj = {};
  cookie.split(';').forEach(pair => {
    const [key, value] = pair.trim().split('=');
    if (key) {
      cookieObj[key] = value ? value.substring(0, 20) + (value.length > 20 ? '...' : '') : '';
    }
  });
  
  console.log('\\n📋 Cookie 概览:', cookieObj);
  console.log('📊 Cookie 总长度:', cookie.length, '字节\\n');
})();`
}

// GetCookieGuide 返回 Cookie 获取指南
func GetCookieGuide() map[string]interface{} {
	return map[string]interface{}{
		"title":       "如何获取 Monica Cookie",
		"description": "按照以下步骤获取您的 Monica Cookie",
		"steps": []map[string]string{
			{
				"step":   "1",
				"title":  "打开 Monica 官网",
				"detail": "点击下方\"打开登录页\"按钮，在浏览器中打开 Monica 登录页面",
			},
			{
				"step":   "2",
				"title":  "登录账号",
				"detail": "使用您的 Monica 账号登录（支持 Google、GitHub 等第三方登录）",
			},
			{
				"step":   "3",
				"title":  "打开开发者工具",
				"detail": "登录成功后，按 F12 (Windows/Linux) 或 Cmd+Option+I (Mac) 打开开发者工具",
			},
			{
				"step":   "4",
				"title":  "运行复制脚本",
				"detail": "切换到 Console (控制台) 标签，粘贴并运行下方提供的 JavaScript 代码",
			},
			{
				"step":   "5",
				"title":  "粘贴 Cookie",
				"detail": "脚本会自动复制 Cookie 到剪贴板，回到本应用粘贴到 Cookie 输入框中",
			},
			{
				"step":   "6",
				"title":  "测试验证",
				"detail": "点击\"测试 Cookie\"按钮验证是否有效",
			},
		},
		"tips": []string{
			"Cookie 通常有效期为 7-30 天，过期后需要重新获取",
			"不要在公共电脑上使用此功能",
			"如果 Cookie 验证失败，请尝试清除浏览器缓存后重新登录",
			"确保登录的是您的付费订阅账号（如有需要）",
		},
		"warnings": []string{
			"Cookie 包含您的账号认证信息，请勿分享给他人",
			"本应用仅将 Cookie 用于 API 请求，不会存储或上传",
		},
	}
}

// CheckCookieExpiry 检查 Cookie 是否可能过期（基于简单规则）
func CheckCookieExpiry(cookie string) (maybeExpired bool, reason string) {
	if cookie == "" {
		return true, "Cookie 为空"
	}

	// 检查 Cookie 中是否包含过期时间相关的字段
	cookieMap := parseCookie(cookie)

	// 检查一些常见的过期标识
	if token, ok := cookieMap["__Secure-next-auth.session-token"]; ok {
		// Session token 通常较长，如果太短可能已失效
		if len(token) < 50 {
			return true, "Session token 异常短，可能已失效"
		}
	}

	// 检查 Cookie 总长度
	if len(cookie) < 100 {
		return true, "Cookie 长度异常，可能不完整"
	}

	return false, ""
}

// FormatCookieForDisplay 格式化 Cookie 用于显示（脱敏）
func FormatCookieForDisplay(cookie string) string {
	if cookie == "" {
		return "(未设置)"
	}

	cookieMap := parseCookie(cookie)
	var parts []string

	for key, value := range cookieMap {
		masked := "***"
		if len(value) > 10 {
			masked = value[:5] + "..." + value[len(value)-5:]
		}
		parts = append(parts, fmt.Sprintf("%s=%s", key, masked))
	}

	return strings.Join(parts, "; ")
}

// GetCookieFromBrowser 尝试从系统浏览器获取 Cookie（实验性功能）
// 注意：这个功能受限于浏览器安全策略，可能不适用于所有浏览器
func GetCookieFromBrowser(browser string, domain string) (string, error) {
	// 这个功能需要访问浏览器的 Cookie 数据库，实现复杂且有风险
	// 暂时返回错误，引导用户使用手动方式
	return "", fmt.Errorf("自动获取 Cookie 功能暂不支持，请手动复制 Cookie")
}

// TestMonicaConnection 测试与 Monica API 的连接
func TestMonicaConnection(cfg *config.Config) error {
	client := resty.New().
		SetTimeout(10 * time.Second).
		SetHeader("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36")

	// 设置代理
	if cfg.Proxy.HTTPProxy != "" || cfg.Proxy.HTTPSProxy != "" {
		proxyURL := cfg.Proxy.HTTPProxy
		if proxyURL == "" {
			proxyURL = cfg.Proxy.HTTPSProxy
		}
		if parsedURL, err := url.Parse(proxyURL); err == nil {
			client.SetProxy(proxyURL)
			_ = parsedURL
		}
	}

	resp, err := client.R().Get("https://api.monica.im/health")
	if err != nil {
		return fmt.Errorf("无法连接 Monica API: %v", err)
	}

	if resp.StatusCode() != http.StatusOK {
		return fmt.Errorf("Monica API 返回异常状态码：%d", resp.StatusCode())
	}

	return nil
}
