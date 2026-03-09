package monica

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"monica-proxy/internal/config"
	"monica-proxy/internal/errors"
	"monica-proxy/internal/logger"
	"monica-proxy/internal/types"
	"monica-proxy/internal/utils"
	"strconv"
	"strings"
	"time"

	"github.com/go-resty/resty/v2"
	"go.uber.org/zap"
)

// SendMonicaRequest 发起对 Monica AI 的请求(使用 resty)
func SendMonicaRequest(ctx context.Context, cfg *config.Config, mReq *types.MonicaRequest) (*resty.Response, error) {
	startTime := time.Now()
	requestID := fmt.Sprintf("monica-%d", startTime.UnixNano())

	// 记录请求详情（基础链路日志始终输出，便于排障）
	logger.Info("[环节2] 本软件请求Monica - 准备发送Monica API请求",
		zap.String("request_id", requestID),
		zap.String("api_type", "monica_chat"),
		zap.String("url", types.BotChatURL),
		zap.String("method", "POST"),
		zap.Bool("enable_request_log", cfg.Logging.EnableRequestLog),
	)

	if cfg.Logging.EnableRequestLog {
		requestBody, _ := json.Marshal(mReq)
		fields := []zap.Field{}

		if cfg.Logging.MaskSensitive {
			fields = append(fields, zap.String("request_body", maskMonicaRequestData(string(requestBody))))
		} else {
			fields = append(fields, zap.String("request_body", string(requestBody)))
		}

		logger.Info("[环节2] 本软件请求Monica - 请求体详情", fields...)
	}

	// 发起请求
	resp, err := utils.RestySSEClient.R().
		SetContext(ctx).
		SetHeader("cookie", utils.CleanCookie(cfg.Monica.Cookie)).
		SetBody(mReq).
		Post(types.BotChatURL)

	var rawRespBody string
	if err == nil && resp != nil && resp.RawResponse != nil && resp.RawBody() != nil {
		bodyBytes, readErr := io.ReadAll(resp.RawBody())
		if readErr != nil {
			logger.Warn("读取Monica原始响应体失败",
				zap.String("request_id", requestID),
				zap.Error(readErr),
			)
		} else {
			rawRespBody = string(bodyBytes)
			resp.RawResponse.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
		}
	}

	duration := time.Since(startTime)

	// 记录响应详情（基础链路日志始终输出）
	if err != nil {
		logger.Error("Monica API请求失败",
			zap.String("request_id", requestID),
			zap.String("api_type", "monica_chat"),
			zap.Duration("duration", duration),
			zap.Error(err),
		)
	} else {
		contentType := ""
		if resp.RawResponse != nil {
			contentType = resp.RawResponse.Header.Get("Content-Type")
		}
		logger.Info("[环节3] Monica返回本软件 - Monica API请求完成",
			zap.String("request_id", requestID),
			zap.String("api_type", "monica_chat"),
			zap.Duration("duration", duration),
			zap.Int("status_code", resp.StatusCode()),
			zap.Int64("response_size", resp.Size()),
			zap.String("content_type", contentType),
		)

		serialized := rawRespBody
		if cfg.Logging.MaskSensitive {
			serialized = maskMonicaResponseData(rawRespBody)
		}
		if len(serialized) > 2000 {
			serialized = serialized[:2000] + "..."
		}
		logger.Info("Monica API响应体序列化字符串",
			zap.String("request_id", requestID),
			zap.String("response_body", serialized),
		)

		if resp.StatusCode() >= 400 {
			logger.Warn("Monica API错误响应体预览",
				zap.String("request_id", requestID),
				zap.Int("status_code", resp.StatusCode()),
				zap.String("response_body_preview", serialized),
			)
		}
	}

	if err != nil {
		return nil, errors.NewRequestFailedError("Monica API调用失败", err)
	}

	// Monica有时返回HTTP 200但业务code非0，这里显式转为错误，避免进入后续流式空响应
	if rawRespBody != "" {
		var monicaBizResp struct {
			Code int    `json:"code"`
			Msg  string `json:"msg"`
		}
		if parseErr := json.Unmarshal([]byte(rawRespBody), &monicaBizResp); parseErr == nil {
			if monicaBizResp.Code != 0 {
				if monicaBizResp.Msg == "" {
					monicaBizResp.Msg = "Monica business error"
				}

				// B方案：当custom_bot/chat返回403权限错误时，自动降级重试preview_chat
				if monicaBizResp.Code == 403 {
					logger.Warn("检测到permission error，尝试降级到preview_chat重试",
						zap.String("request_id", requestID),
					)
					fallbackResp, fallbackErr := retryPreviewChat(ctx, cfg, mReq, requestID)
					if fallbackErr == nil && fallbackResp != nil {
						logger.Info("降级preview_chat重试成功",
							zap.String("request_id", requestID),
						)
						return fallbackResp, nil
					}
					if fallbackErr != nil {
						logger.Warn("降级preview_chat重试失败",
							zap.String("request_id", requestID),
							zap.Error(fallbackErr),
						)
					}
				}

				status := 502
				switch monicaBizResp.Code {
				case 401:
					status = 401
				case 403:
					status = 403
				case 404:
					status = 404
				case 408:
					status = 408
				case 429:
					status = 429
				}

				return nil, errors.NewRequestFailedWithStatus(
					fmt.Sprintf("Monica业务错误: code=%d, msg=%s", monicaBizResp.Code, monicaBizResp.Msg),
					nil,
					status,
				)
			}
		}
	}

	return resp, nil
}

// SendCustomBotRequest 发送custom bot请求
func SendCustomBotRequest(ctx context.Context, cfg *config.Config, customBotReq *types.CustomBotRequest) (*resty.Response, error) {
	startTime := time.Now()
	requestID := fmt.Sprintf("custombot-%d", startTime.UnixNano())

	// 记录请求详情
	if cfg.Logging.EnableRequestLog {
		requestBody, _ := json.Marshal(customBotReq)
		fields := []zap.Field{
			zap.String("request_id", requestID),
			zap.String("api_type", "custom_bot"),
			zap.String("url", types.CustomBotChatURL),
			zap.String("method", "POST"),
			zap.String("bot_uid", customBotReq.BotUID),
		}

		if cfg.Logging.MaskSensitive {
			fields = append(fields, zap.String("request_body", maskMonicaRequestData(string(requestBody))))
		} else {
			fields = append(fields, zap.String("request_body", string(requestBody)))
		}

		logger.Info("发送Custom Bot API请求", fields...)
	}

	// 发起请求
	resp, err := utils.RestySSEClient.R().
		SetContext(ctx).
		SetHeader("cookie", utils.CleanCookie(cfg.Monica.Cookie)).
		SetBody(customBotReq).
		Post(types.CustomBotChatURL)

	var rawRespBody string
	if err == nil && resp != nil && resp.RawResponse != nil && resp.RawBody() != nil {
		bodyBytes, readErr := io.ReadAll(resp.RawBody())
		if readErr != nil {
			logger.Warn("读取Custom Bot原始响应体失败",
				zap.String("request_id", requestID),
				zap.Error(readErr),
			)
		} else {
			rawRespBody = string(bodyBytes)
			resp.RawResponse.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
		}
	}

	duration := time.Since(startTime)

	if err != nil {
		logger.Error("Custom Bot API请求失败",
			zap.String("request_id", requestID),
			zap.String("api_type", "custom_bot"),
			zap.Duration("duration", duration),
			zap.String("bot_uid", customBotReq.BotUID),
			zap.Error(err),
		)
	} else {
		contentType := ""
		if resp.RawResponse != nil {
			contentType = resp.RawResponse.Header.Get("Content-Type")
		}
		logger.Info("Custom Bot API请求完成",
			zap.String("request_id", requestID),
			zap.String("api_type", "custom_bot"),
			zap.Duration("duration", duration),
			zap.String("bot_uid", customBotReq.BotUID),
			zap.Int("status_code", resp.StatusCode()),
			zap.Int64("response_size", resp.Size()),
			zap.String("content_type", contentType),
		)

		serialized := rawRespBody
		if cfg.Logging.MaskSensitive {
			serialized = maskMonicaResponseData(rawRespBody)
		}
		if len(serialized) > 2000 {
			serialized = serialized[:2000] + "..."
		}
		logger.Info("Custom Bot API响应体序列化字符串",
			zap.String("request_id", requestID),
			zap.String("response_body", serialized),
		)
	}

	if err != nil {
		return nil, errors.NewRequestFailedError("Custom Bot API调用失败", err)
	}

	if rawRespBody != "" {
		var monicaBizResp struct {
			Code int    `json:"code"`
			Msg  string `json:"msg"`
		}
		if parseErr := json.Unmarshal([]byte(rawRespBody), &monicaBizResp); parseErr == nil {
			if monicaBizResp.Code != 0 {
				if monicaBizResp.Msg == "" {
					monicaBizResp.Msg = "Monica business error"
				}
				status := 502
				switch monicaBizResp.Code {
				case 401:
					status = 401
				case 403:
					status = 403
				case 404:
					status = 404
				case 408:
					status = 408
				case 429:
					status = 429
				}
				return nil, errors.NewRequestFailedWithStatus(
					fmt.Sprintf("Custom Bot业务错误: code=%d, msg=%s", monicaBizResp.Code, monicaBizResp.Msg),
					nil,
					status,
				)
			}
		}
	}

	return resp, nil
}

// retryPreviewChat 在permission error时降级重试preview_chat端点
func retryPreviewChat(ctx context.Context, cfg *config.Config, mReq *types.MonicaRequest, requestID string) (*resty.Response, error) {
	fallbackReq := map[string]interface{}{
		"task_uid": mReq.TaskUID,
		"bot_uid":  mReq.BotUID,
		"data": map[string]interface{}{
			"conversation_id":        mReq.Data.ConversationID,
			"items":                  mReq.Data.Items,
			"pre_generated_reply_id": "msg:" + strconv.FormatInt(time.Now().UnixNano(), 10),
			"pre_parent_item_id":     mReq.Data.PreParentItemID,
			"origin":                 fmt.Sprintf("https://monica.im/bots/%s", mReq.BotUID),
			"origin_page_title":      "Monica Bot Test",
			"trigger_by":             "auto",
			"use_model":              mReq.BotUID,
			"is_incognito":           true,
			"use_new_memory":         true,
			"use_memory_suggestion":  true,
		},
		"language":  "auto",
		"locale":    "zh_CN",
		"task_type": "chat",
		"bot_data": map[string]interface{}{
			"description":    "fallback bot",
			"logo_url":       "https://assets.monica.im/assets/img/default_bot_icon.jpg",
			"name":           "fallback bot",
			"classification": "custom",
			"prompt":         "",
			"type":           "custom_bot",
			"uid":            mReq.BotUID,
			"example_list":   []interface{}{},
			"tool_data": map[string]interface{}{
				"knowledge_list":     []interface{}{},
				"user_skill_list":    []interface{}{},
				"sys_skill_list":     []interface{}{},
				"use_model":          mReq.BotUID,
				"schedule_task_list": []interface{}{},
			},
		},
	}

	resp, err := utils.RestySSEClient.R().
		SetContext(ctx).
		SetHeader("cookie", utils.CleanCookie(cfg.Monica.Cookie)).
		SetBody(fallbackReq).
		Post(types.CustomBotChatURL)
	if err != nil {
		return nil, err
	}

	if resp != nil && resp.RawBody() != nil {
		bodyBytes, readErr := io.ReadAll(resp.RawBody())
		if readErr == nil {
			raw := string(bodyBytes)
			resp.RawResponse.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
			logger.Info("preview_chat降级响应体",
				zap.String("request_id", requestID),
				zap.String("response_body", raw),
			)

			var monicaBizResp struct {
				Code int    `json:"code"`
				Msg  string `json:"msg"`
			}
			if parseErr := json.Unmarshal(bodyBytes, &monicaBizResp); parseErr == nil && monicaBizResp.Code != 0 {
				return nil, errors.NewRequestFailedWithStatus(
					fmt.Sprintf("PreviewChat业务错误: code=%d, msg=%s", monicaBizResp.Code, monicaBizResp.Msg),
					nil,
					403,
				)
			}
		}
	}

	return resp, nil
}

// maskMonicaRequestData 脱敏Monica请求中的敏感数据
func maskMonicaRequestData(data string) string {
	var request map[string]interface{}
	if err := json.Unmarshal([]byte(data), &request); err == nil {
		return maskMonicaJSONFields(request)
	}
	return data
}

// maskMonicaResponseData 脱敏Monica响应中的敏感数据
func maskMonicaResponseData(data string) string {
	// 对于SSE流数据，按行处理
	lines := strings.Split(data, "\n")
	for i, line := range lines {
		if strings.HasPrefix(line, "data: ") {
			jsonData := strings.TrimPrefix(line, "data: ")
			var response map[string]interface{}
			if err := json.Unmarshal([]byte(jsonData), &response); err == nil {
				masked := maskMonicaJSONFields(response)
				lines[i] = "data: " + masked
			}
		}
	}
	return strings.Join(lines, "\n")
}

// maskMonicaJSONFields 脱敏Monica JSON中的敏感字段
func maskMonicaJSONFields(data map[string]interface{}) string {
	masked := make(map[string]interface{})

	for key, value := range data {
		lowerKey := strings.ToLower(key)
		switch {
		case strings.Contains(lowerKey, "cookie") ||
			strings.Contains(lowerKey, "token") ||
			strings.Contains(lowerKey, "secret") ||
			strings.Contains(lowerKey, "key") ||
			strings.Contains(lowerKey, "password"):
			masked[key] = "***"
		case strings.Contains(lowerKey, "data"):
			// 对data字段进行递归处理
			if dataMap, ok := value.(map[string]interface{}); ok {
				masked[key] = maskMonicaDataFields(dataMap)
			} else {
				masked[key] = value
			}
		default:
			masked[key] = value
		}
	}

	if result, err := json.Marshal(masked); err == nil {
		return string(result)
	}
	return "*** 数据已脱敏 ***"
}

// maskMonicaDataFields 脱敏Monica数据字段中的敏感信息
func maskMonicaDataFields(data map[string]interface{}) map[string]interface{} {
	masked := make(map[string]interface{})

	for key, value := range data {
		lowerKey := strings.ToLower(key)
		switch {
		case strings.Contains(lowerKey, "cookie") ||
			strings.Contains(lowerKey, "token") ||
			strings.Contains(lowerKey, "secret"):
			masked[key] = "***"
		default:
			masked[key] = value
		}
	}

	return masked
}
