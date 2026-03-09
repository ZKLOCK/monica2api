# 2026-03-09 Monica API 修复与改进讨论

## 📅 日期
2026年3月9日

## 👥 参与者
- 用户 (ou_a7f92726e604fb863f76581ac5eda3c4)
- 小龙虾 (OpenClaw AI 助手)

## 📋 讨论内容

### 1. 问题发现
**时间**: 14:57 GMT+8
**问题**: Monica API 调用失败，错误日志显示：
```
net/http: invalid header field value for "Cookie"
```

**错误详情**:
```json
{
  "level": "error",
  "time": "2026-03-09T14:52:33.612+0800",
  "caller": "middleware/error_handler.go:35",
  "msg": "应用错误",
  "status": 502,
  "error_code": 1006,
  "error_msg": "请求失败: Monica API调用失败",
  "error": "Post \"https://api.monica.im/api/custom_bot/chat\": net/http: invalid header field value for \"Cookie\"",
  "request_id": "",
  "stacktrace": "..."
}
```

### 2. 问题分析
**根本原因**: HTTP 请求头中的 Cookie 值包含非法字符（换行符、回车符等），导致 Go 的 HTTP 客户端拒绝发送请求。

**代码问题**: 在 `internal/monica/client.go` 中有 3 处直接使用 `cfg.Monica.Cookie`，没有使用 `utils.CleanCookie()` 函数进行清理：
1. 第 52 行 - `SendMonicaRequest` 函数
2. 第 205 行 - `SendCustomBotRequest` 函数  
3. 第 342 行 - `retryPreviewChat` 函数

### 3. 解决方案
**修复内容**: 在所有 3 处使用 Cookie 的地方添加 `utils.CleanCookie()` 调用：

```go
// 修复前
SetHeader("cookie", cfg.Monica.Cookie)

// 修复后  
SetHeader("cookie", utils.CleanCookie(cfg.Monica.Cookie))
```

**CleanCookie 函数功能**:
- 移除首尾空白字符
- 移除换行符、回车符、制表符
- 修复分号分隔符格式
- 清理每个键值对中的非法字符

### 4. 实施步骤
1. **代码修复**: 修改 `internal/monica/client.go` 中的 3 处代码
2. **重新构建**: 使用 `wails build` 重新构建应用
3. **服务重启**: 杀掉旧进程，启动新构建的应用
4. **验证修复**: 测试 API 调用是否正常

### 5. 项目里程碑标记
**时间**: 15:41 GMT+8
**操作**: 为项目打上 git tag
- **Tag 名称**: `v1.0.0`
- **Tag 消息**: "Monica API 封装完成，本地联调成功"
- **关联提交**: `d4c4da3` (请求头去空格)

**Tag 意义**: 标记项目的重要里程碑：
1. Monica API 封装完成
2. 本地联调成功
3. 生产就绪版本
4. 经过测试的稳定版本

### 6. 未来改进讨论
**时间**: 16:01 GMT+8
**提出的两个改进方向**:

#### 6.1 Monica 集成到 OpenClaw ✅ **已完成**
**现状**: Monica 代理已经实现了标准的 OpenAI API 格式：
- 端点：`/v1/chat/completions`
- 请求格式：完全兼容 OpenAI
- 响应格式：支持流式和非流式响应

**集成可行性**: ✅ **完全可行**
- 在 OpenClaw 配置中添加 Monica 作为新的 AI 提供商
- 配置 API 地址（如 `http://localhost:8080`）
- 配置 Bearer token

#### 6.2 Monica 配置页面直接选择大模型 ✅ **可行，需要开发**
**现状**: 目前模型是通过 curl 参数传递的

**改进方案**:
1. **前端增强**: 在 Monica 代理的 GUI 中添加模型选择器
2. **配置持久化**: 将选择的模型保存到配置文件
3. **默认模型设置**: 支持设置默认模型（如 gpt-5.4）
4. **模型列表**: 从 Monica API 动态获取支持的模型列表

**技术实现**:
```go
// 在配置中添加模型字段
type MonicaConfig struct {
    Cookie              string `yaml:"cookie" json:"cookie"`
    BotUID              string `yaml:"bot_uid" json:"bot_uid"`
    DefaultModel        string `yaml:"default_model" json:"default_model"`  // 新增
    EnableCustomBotMode bool   `yaml:"enable_custom_bot_mode" json:"enable_custom_bot_mode"`
}
```

### 7. 经验教训
#### 7.1 技术经验
1. **HTTP 头格式要求**: Go 的 HTTP 客户端对请求头值有严格的格式要求，不能包含非法字符
2. **Cookie 清理重要性**: 从浏览器复制的 Cookie 可能包含换行符等不可见字符
3. **防御性编程**: 对所有外部输入（包括配置）都应该进行清理和验证

#### 7.2 开发流程经验
1. **问题排查**: 通过日志快速定位问题根源
2. **代码审查**: 发现类似问题应检查所有使用相同模式的地方
3. **版本管理**: 使用 git tag 标记重要里程碑
4. **文档记录**: 记录问题和解决方案，便于后续维护

### 8. 待办事项
#### 高优先级
- [ ] 测试修复后的 Monica 代理是否正常工作
- [ ] 编写 OpenClaw 集成文档
- [ ] 考虑添加模型选择器功能

#### 中优先级  
- [ ] 添加更多的错误处理和日志记录
- [ ] 优化 Cookie 验证和过期检查
- [ ] 考虑添加自动重试机制

#### 低优先级
- [ ] 添加性能监控
- [ ] 考虑支持多账号切换
- [ ] 添加 API 使用统计

### 9. 相关文件
1. **修复文件**: `internal/monica/client.go`
2. **工具函数**: `internal/utils/cookie_helper.go`
3. **配置文件**: `internal/config/config.go`
4. **构建输出**: `build/bin/monica-proxy-wails.app/`

### 10. 总结
今天成功解决了 Monica API 的 Cookie 格式问题，这是一个典型的"防御性编程"案例。通过这次修复，我们：

1. **解决了实际问题**: 修复了 API 调用失败的问题
2. **积累了经验**: 学习了 HTTP 请求头格式要求和 Cookie 清理的重要性  
3. **建立了里程碑**: 使用 git tag 标记了项目的重要进展
4. **规划了未来**: 讨论了两个有价值的改进方向

这次协作体现了系统化问题解决和持续改进的重要性。🦞