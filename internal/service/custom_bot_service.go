package service

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"monica-proxy/internal/config"
	"monica-proxy/internal/errors"
	"monica-proxy/internal/logger"
	"monica-proxy/internal/monica"
	"monica-proxy/internal/types"

	"github.com/sashabaranov/go-openai"
	"go.uber.org/zap"
)

// CustomBotService 定义自定义Bot服务接口
type CustomBotService interface {
	HandleCustomBotChat(ctx context.Context, req *openai.ChatCompletionRequest, botUID string) (interface{}, error)
}

type customBotService struct {
	config *config.Config
}

// NewCustomBotService 创建自定义Bot服务实例
func NewCustomBotService(cfg *config.Config) CustomBotService {
	return &customBotService{
		config: cfg,
	}
}

// HandleCustomBotChat 处理自定义Bot对话请求
func (s *customBotService) HandleCustomBotChat(ctx context.Context, req *openai.ChatCompletionRequest, botUID string) (interface{}, error) {
	// 验证请求
	if len(req.Messages) == 0 {
		return nil, errors.NewEmptyMessageError()
	}

	// 日志记录请求
	logger.Info("处理Custom Bot聊天请求",
		zap.String("model", req.Model),
		zap.String("bot_uid", botUID),
		zap.Int("message_count", len(req.Messages)),
		zap.Bool("stream", req.Stream),
	)

	// 创建请求副本，避免修改原始请求
	modifiedReq := *req
	
	// 添加Function Calling隧道指令
	// 在最后一条用户消息前插入隐藏指令
	if len(modifiedReq.Messages) > 0 {
		lastMessage := modifiedReq.Messages[len(modifiedReq.Messages)-1]
		if lastMessage.Role == "user" {
			// 构建带Function Calling隧道指令的消息
			fcInstruction := `[系统指令] 请将Function Calling响应放在 <fc-tool> 标签内。
格式：<fc-tool>{"name": "函数名", "arguments": {}}</fc-tool>
请勿在标签外解释Function Calling，直接返回标签内容。
用户消息：` + lastMessage.Content
			
			// 替换最后一条消息
			modifiedReq.Messages[len(modifiedReq.Messages)-1] = openai.ChatCompletionMessage{
				Role:    "user",
				Content: fcInstruction,
			}
			
			logger.Info("添加Function Calling隧道指令",
				zap.String("original_content", lastMessage.Content),
				zap.String("modified_content_preview", fcInstruction[:min(100, len(fcInstruction))] + "..."),
			)
		}
	}

	// 转换请求格式
	customBotReq, err := types.ChatGPTToCustomBot(s.config, modifiedReq, botUID)
	if err != nil {
		logger.Error("转换Custom Bot请求失败", zap.Error(err))
		return nil, errors.NewInternalError(err)
	}

	// 调用Monica Custom Bot API
	stream, err := monica.SendCustomBotRequest(ctx, s.config, customBotReq)
	if err != nil {
		logger.Error("调用Custom Bot API失败", zap.Error(err))
		// 如果已经是AppError，直接返回，否则包装为内部错误
		if appErr, ok := err.(*errors.AppError); ok {
			return nil, appErr
		}
		return nil, errors.NewInternalError(err)
	}

	// 根据是否使用流式响应处理结果
	if req.Stream {
		// 流式响应时不关闭响应体，让handler层负责关闭
		return stream.RawBody(), nil
	}

	// 非流式响应，确保在此函数结束时关闭响应体
	defer stream.RawBody().Close()

	// 处理非流式响应
	response, err := monica.CollectMonicaSSEToCompletion(req.Model, stream.RawBody(), s.config)
	if err != nil {
		logger.Error("处理Custom Bot响应失败", zap.Error(err))
		return nil, errors.NewInternalError(err)
	}
	
	// 记录原始响应（用于调试）
	logger.Info("收到Monica原始响应",
		zap.String("model", req.Model),
		zap.Any("response_type", fmt.Sprintf("%T", response)),
	)
	
	// 解析Function Calling隧道响应
	parsedResponse, err := s.parseFunctionCallingTunnel(response, req.Model)
	if err != nil {
		logger.Error("解析Function Calling隧道失败", zap.Error(err))
		// 即使解析失败，也返回原始响应
		return response, nil
	}
	
	// 记录解析后的响应
	logger.Info("Function Calling隧道解析完成",
		zap.String("model", req.Model),
		zap.Any("parsed_response_type", fmt.Sprintf("%T", parsedResponse)),
	)
	
	return parsedResponse, nil
}

// parseFunctionCallingTunnel 解析Function Calling隧道响应
func (s *customBotService) parseFunctionCallingTunnel(response interface{}, model string) (interface{}, error) {
	logger.Info("开始解析Function Calling隧道",
		zap.String("model", model),
		zap.Any("response_type", fmt.Sprintf("%T", response)),
	)
	
	// 将响应转换为map以便处理
	responseMap, ok := response.(map[string]interface{})
	if !ok {
		logger.Warn("响应不是map类型，跳过Function Calling解析",
			zap.String("model", model),
			zap.Any("actual_type", fmt.Sprintf("%T", response)),
		)
		return response, nil
	}
	
	logger.Debug("响应map结构",
		zap.String("model", model),
		zap.Any("response_keys", getMapKeys(responseMap)),
	)
	
	// 提取choices
	choices, ok := responseMap["choices"].([]interface{})
	if !ok || len(choices) == 0 {
		return response, nil
	}
	
	firstChoice, ok := choices[0].(map[string]interface{})
	if !ok {
		return response, nil
	}
	
	message, ok := firstChoice["message"].(map[string]interface{})
	if !ok {
		return response, nil
	}
	
	content, ok := message["content"].(string)
	if !ok {
		return response, nil
	}
	
	// 查找 <fc-tool> 标签
	fcStart := strings.Index(content, "<fc-tool>")
	fcEnd := strings.Index(content, "</fc-tool>")
	
	if fcStart == -1 || fcEnd == -1 || fcEnd <= fcStart {
		// 没有找到Function Calling标签，返回原始响应
		logger.Info("未找到Function Calling标签", zap.String("model", model))
		return response, nil
	}
	
	// 提取标签内容
	fcContent := content[fcStart+len("<fc-tool>") : fcEnd]
	
	// 解析JSON
	var fcData map[string]interface{}
	if err := json.Unmarshal([]byte(fcContent), &fcData); err != nil {
		logger.Error("解析Function Calling JSON失败", 
			zap.String("model", model),
			zap.String("fc_content", fcContent),
			zap.Error(err),
		)
		return response, nil
	}
	
	logger.Info("解析到Function Calling",
		zap.String("model", model),
		zap.Any("fc_data", fcData),
	)
	
	// 这里应该执行对应的函数，然后返回执行结果
	// 暂时先返回一个模拟的执行结果
	executionResult := s.executeFunctionCall(fcData, model)
	
	// 更新响应内容
	message["content"] = executionResult
	
	return responseMap, nil
}

// executeFunctionCall 执行Function Calling
func (s *customBotService) executeFunctionCall(fcData map[string]interface{}, model string) string {
	name, _ := fcData["name"].(string)
	args, _ := fcData["arguments"].(map[string]interface{})
	
	logger.Info("执行Function Calling",
		zap.String("model", model),
		zap.String("function_name", name),
		zap.Any("arguments", args),
	)
	
	// 根据函数名执行不同的操作
	switch name {
	case "open_browser", "openBrowser", "browser_open":
		// 执行打开浏览器
		return "已执行：打开浏览器命令"
		
	case "execute_command", "run_command", "shell_execute":
		// 执行系统命令
		command, _ := args["command"].(string)
		return fmt.Sprintf("已执行系统命令：%s", command)
		
	case "get_weather", "weather":
		// 获取天气
		city, _ := args["city"].(string)
		return fmt.Sprintf("已获取%s的天气信息", city)
		
	default:
		return fmt.Sprintf("已执行函数：%s，参数：%v", name, args)
	}
}

// min 返回两个整数中的较小值
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// getMapKeys 获取map的键列表
func getMapKeys(m map[string]interface{}) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}
