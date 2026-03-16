package monica

import (
	"bufio"
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"monica-proxy/internal/config"
	"monica-proxy/internal/logger"
	"monica-proxy/internal/types"
	"monica-proxy/internal/utils"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/bytedance/sonic"
	"github.com/sashabaranov/go-openai"
	"go.uber.org/zap"
)

const (
	sseObject     = "chat.completion.chunk"
	sseFinish     = "[DONE]"
	flushInterval = 100 * time.Millisecond // 刷新间隔
	bufferSize    = 4096                   // 缓冲区大小

	dataPrefix    = "data: "
	dataPrefixLen = len(dataPrefix)
	lineEnd       = "\n\n"
)

// SSEData 用于解析 Monica SSE json
type SSEData struct {
	Text        string      `json:"text"`
	Finished    bool        `json:"finished"`
	AgentStatus AgentStatus `json:"agent_status,omitempty"`
}

type AgentStatus struct {
	UID      string `json:"uid"`
	Type     string `json:"type"`
	Text     string `json:"text"`
	Metadata struct {
		Title           string `json:"title"`
		ReasoningDetail string `json:"reasoning_detail"`
	} `json:"metadata"`
}

var (
	sseDataPool = sync.Pool{
		New: func() any {
			return &SSEData{}
		},
	}
	
	// 字符串构建器池，复用strings.Builder
	stringBuilderPool = sync.Pool{
		New: func() any {
			return &strings.Builder{}
		},
	}
	
	// 缓冲区池，复用字节缓冲区
	bufferPool = sync.Pool{
		New: func() any {
			buf := make([]byte, bufferSize)
			return &buf
		},
	}
)

// processMonicaSSE 处理Monica的SSE数据
type processMonicaSSE struct {
	reader *bufio.Reader
	model  string
	ctx    context.Context
	cfg    *config.Config
}

// handleSSEData 处理单条SSE数据
type handleSSEData func(*SSEData) error

// processSSEStream 处理SSE流
func (p *processMonicaSSE) processSSEStream(handler handleSSEData) error {
	var line []byte
	var err error
	var chunkCount int64
	var startTime = time.Now()
	
	// 添加详细日志
	logger.Info("[DEBUG-SSE] 开始处理SSE流",
		zap.String("model", p.model),
		zap.Time("start_time", startTime),
		zap.Bool("has_config", p.cfg != nil),
		zap.Bool("enable_log", p.cfg != nil && p.cfg.Logging.EnableRequestLog),
	)
	
	for {
		// 检查上下文是否已取消
		select {
		case <-p.ctx.Done():
			if p.cfg != nil && p.cfg.Logging.EnableRequestLog {
				logger.Info("SSE流处理被上下文取消",
					zap.String("model", p.model),
					zap.Int64("chunk_count", chunkCount),
					zap.Duration("duration", time.Since(startTime)),
				)
			}
			return p.ctx.Err()
		default:
		}
		
		line, err = p.reader.ReadBytes('\n')
		if err != nil {
			// EOF 和 上下文取消 都是正常结束，不应视为错误
			if err == io.EOF || errors.Is(err, context.Canceled) {
				if p.cfg != nil && p.cfg.Logging.EnableRequestLog {
					logger.Info("[环节3] Monica返回本软件 - SSE流处理完成",
						zap.String("model", p.model),
						zap.Int64("chunk_count", chunkCount),
						zap.Duration("duration", time.Since(startTime)),
					)
				}
				return nil
			}
			
			if p.cfg != nil && p.cfg.Logging.EnableRequestLog {
				logger.Error("SSE流读取错误",
					zap.String("model", p.model),
					zap.Int64("chunk_count", chunkCount),
					zap.Duration("duration", time.Since(startTime)),
					zap.Error(err),
				)
			}
			return fmt.Errorf("read error: %w", err)
		}

		// Monica SSE 的行前缀一般是 "data: "
		if len(line) < dataPrefixLen || !bytes.HasPrefix(line, []byte(dataPrefix)) {
			// 添加调试日志
			if p.cfg != nil && p.cfg.Logging.EnableRequestLog {
				lineStr := strings.TrimSpace(string(line))
				if lineStr != "" && lineStr != "\n" {
					logger.Debug("[DEBUG-SSE] 跳过非data行",
						zap.String("line", lineStr),
						zap.Int("length", len(line)),
					)
				}
			}
			continue
		}

		// 安全地提取JSON字符串，避免slice bounds越界
		if len(line) <= dataPrefixLen+1 { // 需要至少 data: + 至少1个字符 + \n
			logger.Debug("[DEBUG-SSE] 行太短",
				zap.Int("line_length", len(line)),
				zap.Int("min_required", dataPrefixLen+2),
			)
			continue
		}
		jsonStr := line[dataPrefixLen : len(line)-1] // 去掉\n
		if len(jsonStr) == 0 {
			logger.Debug("[DEBUG-SSE] JSON字符串为空")
			continue
		}
		
		// 添加JSON字符串预览
		if p.cfg != nil && p.cfg.Logging.EnableRequestLog {
			jsonPreview := string(jsonStr)
			if len(jsonPreview) > 100 {
				jsonPreview = jsonPreview[:100] + "..."
			}
			logger.Debug("[DEBUG-SSE] 提取的JSON字符串",
				zap.String("json_preview", jsonPreview),
				zap.Int("json_length", len(jsonStr)),
			)
		}

		if p.cfg != nil && p.cfg.Logging.EnableRequestLog {
			rawPreview := string(jsonStr)
			if len(rawPreview) > 500 {
				rawPreview = rawPreview[:500] + "..."
			}
			logger.Info("Monica原始SSE数据",
				zap.String("model", p.model),
				zap.String("raw_data", rawPreview),
			)
		}

		// 如果是 [DONE] 则结束
		if bytes.Equal(jsonStr, []byte(sseFinish)) {
			if p.cfg != nil && p.cfg.Logging.EnableRequestLog {
				logger.Info("[环节3] Monica返回本软件 - SSE流处理完成",
					zap.String("model", p.model),
					zap.String("finish_reason", "normal"),
					zap.Int64("chunk_count", chunkCount),
					zap.Duration("duration", time.Since(startTime)),
				)
			}
			return nil
		}

		// 从对象池获取一个对象
		sseData := sseDataPool.Get().(*SSEData)
		
		// 解析 JSON
		if err := sonic.Unmarshal(jsonStr, sseData); err != nil {
			// 立即归还对象到池中
			*sseData = SSEData{}
			sseDataPool.Put(sseData)
			
			if p.cfg != nil && p.cfg.Logging.EnableRequestLog {
				logger.Error("SSE数据解析错误",
					zap.String("model", p.model),
					zap.Int64("chunk_count", chunkCount),
					zap.String("raw_data", string(jsonStr)),
					zap.Error(err),
				)
			}
			return fmt.Errorf("unmarshal error: %w", err)
		}

		// 记录chunk接收日志
		atomic.AddInt64(&chunkCount, 1)
		if p.cfg != nil && p.cfg.Logging.EnableRequestLog {
			// 对于每个chunk，记录文本内容预览（截断版）
			textPreview := sseData.Text
			if len(textPreview) > 100 {
				textPreview = textPreview[:100] + "..."
			}
			
			logger.Debug("SSE数据chunk接收",
				zap.String("model", p.model),
				zap.Int64("chunk_number", chunkCount),
				zap.Int("text_length", len(sseData.Text)),
				zap.String("text_preview", textPreview),
				zap.Bool("finished", sseData.Finished),
				zap.String("agent_type", sseData.AgentStatus.Type),
			)
		}

		// 调用处理函数
		if err := handler(sseData); err != nil {
			// 立即归还对象到池中
			*sseData = SSEData{}
			sseDataPool.Put(sseData)
			
			if p.cfg != nil && p.cfg.Logging.EnableRequestLog {
				logger.Error("SSE数据处理错误",
					zap.String("model", p.model),
					zap.Int64("chunk_count", chunkCount),
					zap.Error(err),
				)
			}
			return err
		}
		
		// 使用完后立即归还对象到池中
		*sseData = SSEData{}
		sseDataPool.Put(sseData)
	}
}

// parseToolCallJSON 解析tool_call JSON字符串
func parseToolCallJSON(jsonStr string) (*openai.ToolCall, error) {
	logger.Info("解析Function Call JSON", 
		zap.String("json", jsonStr))
	
	// 尝试修复常见的JSON格式问题
	jsonStr = strings.TrimSpace(jsonStr)
	
	// 尝试1: 标准解析
	var toolCall struct {
		Name      string                 `json:"name"`
		Arguments map[string]interface{} `json:"arguments"`
	}
	
	err := sonic.Unmarshal([]byte(jsonStr), &toolCall)
	if err != nil {
		// 尝试2: 修复单引号
		jsonStr = strings.ReplaceAll(jsonStr, "'", "\"")
		err = sonic.Unmarshal([]byte(jsonStr), &toolCall)
		
		if err != nil {
			// 尝试3: 修复缺少引号的属性名
			// 简单的修复：在冒号前添加引号
			re := regexp.MustCompile(`(\w+):`)
			jsonStr = re.ReplaceAllString(jsonStr, `"$1":`)
			err = sonic.Unmarshal([]byte(jsonStr), &toolCall)
			
			if err != nil {
				logger.Error("多次尝试解析tool_call JSON均失败", 
					zap.String("original_json", jsonStr),
					zap.Error(err))
				return nil, fmt.Errorf("解析tool_call JSON失败: %v", err)
			}
		}
	}
	
	// 验证必需字段
	if toolCall.Name == "" {
		return nil, fmt.Errorf("tool_call缺少name字段")
	}
	
	if toolCall.Arguments == nil {
		toolCall.Arguments = make(map[string]interface{})
	}
	
	// 将arguments转换为JSON字符串
	argsBytes, err := sonic.Marshal(toolCall.Arguments)
	if err != nil {
		return nil, fmt.Errorf("序列化arguments失败: %v", err)
	}
	
	// 创建OpenAI格式的ToolCall
	return &openai.ToolCall{
		ID:   fmt.Sprintf("call_%s", utils.RandStringUsingMathRand(16)),
		Type: "function",
		Function: openai.FunctionCall{
			Name:      toolCall.Name,
			Arguments: string(argsBytes),
		},
	}, nil
}

// parseFunctionCallFromContent 从内容中解析Function Call
func parseFunctionCallFromContent(content string) (*openai.ToolCall, error) {
	// 查找 <tool_call> 标签
	startTag := "<tool_call>"
	endTag := "</tool_call>"
	
	startIdx := strings.Index(content, startTag)
	if startIdx == -1 {
		return nil, nil // 没有找到tool_call标签
	}
	
	endIdx := strings.Index(content, endTag)
	if endIdx == -1 {
		return nil, fmt.Errorf("找到开始标签但未找到结束标签")
	}
	
	// 提取JSON内容
	jsonStart := startIdx + len(startTag)
	jsonStr := strings.TrimSpace(content[jsonStart:endIdx])
	
	return parseToolCallJSON(jsonStr)
}

// sendToolCallStream 发送tool_call流式响应
func sendToolCallStream(writer *bufio.Writer, w io.Writer, chatId string, now int64, model string, fingerprint string, toolCall *openai.ToolCall) error {
	// 发送tool_call开始消息
	toolCallStartMsg := types.ChatCompletionStreamResponse{
		ID:                "chatcmpl-" + chatId,
		Object:            sseObject,
		SystemFingerprint: fingerprint,
		Created:           now,
		Model:             model,
		Choices: []types.ChatCompletionStreamChoice{
			{
				Index: 0,
				Delta: openai.ChatCompletionStreamChoiceDelta{
					Role: openai.ChatMessageRoleAssistant,
				},
				FinishReason: openai.FinishReasonNull,
			},
		},
	}
	
	// 发送tool_call内容
	toolCallMsg := types.ChatCompletionStreamResponse{
		ID:                "chatcmpl-" + chatId,
		Object:            sseObject,
		SystemFingerprint: fingerprint,
		Created:           now,
		Model:             model,
		Choices: []types.ChatCompletionStreamChoice{
			{
				Index: 0,
				Delta: openai.ChatCompletionStreamChoiceDelta{
					ToolCalls: []openai.ToolCall{*toolCall},
				},
				FinishReason: openai.FinishReasonNull,
			},
		},
	}
	
	// 发送完成消息
	toolCallFinishMsg := types.ChatCompletionStreamResponse{
		ID:                "chatcmpl-" + chatId,
		Object:            sseObject,
		SystemFingerprint: fingerprint,
		Created:           now,
		Model:             model,
		Choices: []types.ChatCompletionStreamChoice{
			{
				Index:        0,
				FinishReason: openai.FinishReasonToolCalls,
			},
		},
	}
	
	// 发送所有消息
	messages := []types.ChatCompletionStreamResponse{toolCallStartMsg, toolCallMsg, toolCallFinishMsg}
	for _, msg := range messages {
		sb := stringBuilderPool.Get().(*strings.Builder)
		sb.WriteString("data: ")
		sendLine, _ := sonic.MarshalString(msg)
		sb.WriteString(sendLine)
		sb.WriteString("\n\n")
		
		if _, err := writer.WriteString(sb.String()); err != nil {
			sb.Reset()
			stringBuilderPool.Put(sb)
			return fmt.Errorf("write tool_call error: %w", err)
		}
		
		sb.Reset()
		stringBuilderPool.Put(sb)
	}
	
	// 刷新缓冲区
	writer.Flush()
	if f, ok := w.(http.Flusher); ok {
		f.Flush()
	}
	
	logger.Info("已发送tool_call流式响应",
		zap.String("tool_name", toolCall.Function.Name),
		zap.String("tool_arguments", toolCall.Function.Arguments))
	
	return nil
}

// CollectMonicaSSEToCompletion 将 Monica SSE 转换为完整的 ChatCompletion 响应
func CollectMonicaSSEToCompletion(model string, r io.Reader, cfg *config.Config) (*openai.ChatCompletionResponse, error) {
	ctx := context.Background()
	
	// 从池中获取字符串构建器
	fullContentBuilder := stringBuilderPool.Get().(*strings.Builder)
	defer func() {
		fullContentBuilder.Reset()
		stringBuilderPool.Put(fullContentBuilder)
	}()
	
	processor := &processMonicaSSE{
		reader: bufio.NewReaderSize(r, bufferSize),
		model:  model,
		ctx:    ctx,
		cfg:    cfg,
	}

	// 添加详细日志
	logger.Info("[DEBUG] 开始CollectMonicaSSEToCompletion",
		zap.String("model", model),
		zap.Bool("has_config", cfg != nil),
	)

	// 处理SSE数据
	err := processor.processSSEStream(func(sseData *SSEData) error {
		// 添加详细日志
		logger.Debug("[DEBUG] 处理SSE数据",
			zap.String("text_preview", func() string {
				if len(sseData.Text) > 50 {
					return sseData.Text[:50] + "..."
				}
				return sseData.Text
			}()),
			zap.Bool("finished", sseData.Finished),
			zap.String("agent_status_type", sseData.AgentStatus.Type),
			zap.Int("text_length", len(sseData.Text)),
		)
		
		// 如果是 agent_status，跳过
		if sseData.AgentStatus.Type != "" {
			logger.Debug("[DEBUG] 跳过agent_status")
			return nil
		}
		// 累积内容
		fullContentBuilder.WriteString(sseData.Text)
		return nil
	})

	if err != nil {
		return nil, err
	}

	// 记录完整的响应内容
	fullContent := fullContentBuilder.String()
	
	// 添加详细日志
	logger.Info("[DEBUG] CollectMonicaSSEToCompletion 完成",
		zap.String("model", model),
		zap.Int("content_length", len(fullContent)),
		zap.Bool("has_error", err != nil),
		zap.String("error", func() string {
			if err != nil {
				return err.Error()
			}
			return ""
		}()),
	)
	
	if len(fullContent) > 0 {
		logger.Info("Monica完整响应内容",
			zap.String("model", model),
			zap.Int("content_length", len(fullContent)),
			zap.String("content_preview", func() string {
				if len(fullContent) > 200 {
					return fullContent[:200] + "..."
				}
				return fullContent
			}()),
		)
	} else if cfg != nil && cfg.Logging.EnableRequestLog {
		logger.Warn("Monica响应内容为空",
			zap.String("model", model),
			zap.String("hint", "请检查上方Monica原始SSE数据日志中的字段是否包含text"),
		)
	}

	// 检查是否包含Function Call
	var toolCalls []openai.ToolCall
	var finishReason openai.FinishReason
	var responseContent string
	
	// 尝试解析Function Call
	toolCall, err := parseFunctionCallFromContent(fullContent)
	if err != nil {
		logger.Error("解析Function Call失败", zap.Error(err))
		// 解析失败，返回原始内容
		responseContent = fullContent
		finishReason = openai.FinishReasonStop
	} else if toolCall != nil {
		// 找到Function Call
		toolCalls = []openai.ToolCall{*toolCall}
		responseContent = "" // Function Call时content为空
		finishReason = openai.FinishReasonToolCalls
		logger.Info("检测到Function Call", 
			zap.String("tool_name", toolCall.Function.Name),
			zap.String("tool_arguments", toolCall.Function.Arguments))
	} else {
		// 没有Function Call，返回原始内容
		responseContent = fullContent
		finishReason = openai.FinishReasonStop
	}

	// 构造完整的响应
	response := &openai.ChatCompletionResponse{
		ID:      fmt.Sprintf("chatcmpl-%s", utils.RandStringUsingMathRand(29)),
		Object:  "chat.completion",
		Created: time.Now().Unix(),
		Model:   model,
		Choices: []openai.ChatCompletionChoice{
			{
				Index: 0,
				Message: openai.ChatCompletionMessage{
					Role:      "assistant",
					Content:   responseContent,
					ToolCalls: toolCalls,
				},
				FinishReason: finishReason,
			},
		},
		Usage: openai.Usage{
			// Monica API 不提供 token 使用信息，这里暂时填 0
			PromptTokens:     0,
			CompletionTokens: 0,
			TotalTokens:      0,
		},
	}

	return response, nil
}

// StreamMonicaSSEToClient 将 Monica SSE 转成前端可用的流
func StreamMonicaSSEToClient(model string, w io.Writer, r io.Reader) error {
	return StreamMonicaSSEToClientWithConfig(model, w, r, nil)
}

// streamFunctionCallParser 流式Function Call解析器
type streamFunctionCallParser struct {
	buffer        strings.Builder
	inToolCall    bool
	toolCallStart int
	toolCallEnd   int
	hasToolCall   bool
	toolCallJSON  string
}

// newStreamFunctionCallParser 创建新的流式解析器
func newStreamFunctionCallParser() *streamFunctionCallParser {
	return &streamFunctionCallParser{}
}

// processChunk 处理一个数据块，返回是否找到完整的tool_call
func (p *streamFunctionCallParser) processChunk(text string) (bool, string) {
	// 将文本添加到缓冲区
	p.buffer.WriteString(text)
	
	content := p.buffer.String()
	
	// 如果已经在tool_call中，检查是否结束
	if p.inToolCall {
		endIdx := strings.Index(content[p.toolCallStart:], "</tool_call>")
		if endIdx != -1 {
			// 找到结束标签
			p.toolCallEnd = p.toolCallStart + endIdx
			p.toolCallJSON = strings.TrimSpace(content[p.toolCallStart+len("<tool_call>"):p.toolCallEnd])
			p.hasToolCall = true
			p.inToolCall = false
			return true, p.toolCallJSON
		}
		return false, ""
	}
	
	// 检查是否开始新的tool_call
	startIdx := strings.Index(content, "<tool_call>")
	if startIdx != -1 {
		p.inToolCall = true
		p.toolCallStart = startIdx
		
		// 检查是否在同一数据块中结束
		remaining := content[startIdx:]
		endIdx := strings.Index(remaining, "</tool_call>")
		if endIdx != -1 {
			// 在同一数据块中完成
			p.toolCallEnd = startIdx + endIdx
			p.toolCallJSON = strings.TrimSpace(content[startIdx+len("<tool_call>"):p.toolCallEnd])
			p.hasToolCall = true
			p.inToolCall = false
			return true, p.toolCallJSON
		}
	}
	
	return false, ""
}

// reset 重置解析器状态
func (p *streamFunctionCallParser) reset() {
	p.buffer.Reset()
	p.inToolCall = false
	p.toolCallStart = 0
	p.toolCallEnd = 0
	p.hasToolCall = false
	p.toolCallJSON = ""
}

// StreamMonicaSSEToClientWithConfig 将 Monica SSE 转成前端可用的流（带配置）
func StreamMonicaSSEToClientWithConfig(model string, w io.Writer, r io.Reader, cfg *config.Config) error {
	ctx := context.Background()
	writer := bufio.NewWriterSize(w, bufferSize)
	defer writer.Flush()

	chatId := utils.RandStringUsingMathRand(29)
	now := time.Now().Unix()
	fingerprint := utils.RandStringUsingMathRand(10)
	var startTime = time.Now()
	var chunkCount int64

	// 创建Function Call解析器
	fcParser := newStreamFunctionCallParser()
	var hasSentToolCall bool

	if cfg != nil && cfg.Logging.EnableRequestLog {
		logger.Info("开始SSE流式响应",
			zap.String("model", model),
			zap.String("chat_id", chatId),
		)
	}

	// 创建一个定时刷新的 ticker
	ticker := time.NewTicker(flushInterval)
	defer ticker.Stop()

	// 创建一个 done channel 用于清理
	done := make(chan struct{})
	defer close(done)

	// 启动一个 goroutine 定期刷新缓冲区
	go func() {
		for {
			select {
			case <-ticker.C:
				if f, ok := w.(http.Flusher); ok {
					writer.Flush()
					f.Flush()
				}
			case <-done:
				return
			}
		}
	}()

	processor := &processMonicaSSE{
		reader: bufio.NewReaderSize(r, bufferSize),
		model:  model,
		ctx:    ctx,
		cfg:    cfg,
	}

	var thinkFlag bool
	return processor.processSSEStream(func(sseData *SSEData) error {
		atomic.AddInt64(&chunkCount, 1)
		
		// 检查是否已经发送了tool_call
		if hasSentToolCall {
			// 如果已经发送了tool_call，跳过后续内容
			logger.Debug("已发送tool_call，跳过后续内容")
			return nil
		}
		
		// 处理Function Call检测
		if !hasSentToolCall && sseData.Text != "" {
			found, toolCallJSON := fcParser.processChunk(sseData.Text)
			if found {
				// 解析tool_call
				toolCall, err := parseToolCallJSON(toolCallJSON)
				if err != nil {
					logger.Error("解析流式tool_call失败", zap.Error(err))
					// 解析失败，继续发送普通文本
				} else {
					// 发送tool_call流式响应
					hasSentToolCall = true
					return sendToolCallStream(writer, w, chatId, now, model, fingerprint, toolCall)
				}
			}
		}
		
		var sseMsg types.ChatCompletionStreamResponse
		switch {
		case sseData.Finished:
			sseMsg = types.ChatCompletionStreamResponse{
				ID:      "chatcmpl-" + chatId,
				Object:  sseObject,
				Created: now,
				Model:   model,
				Choices: []types.ChatCompletionStreamChoice{
					{
						Index: 0,
						Delta: openai.ChatCompletionStreamChoiceDelta{
							Role: openai.ChatMessageRoleAssistant,
						},
						FinishReason: openai.FinishReasonStop,
					},
				},
			}
		case sseData.AgentStatus.Type == "thinking":
			thinkFlag = true
			sseMsg = types.ChatCompletionStreamResponse{
				ID:                "chatcmpl-" + chatId,
				Object:            sseObject,
				SystemFingerprint: fingerprint,
				Created:           now,
				Model:             model,
				Choices: []types.ChatCompletionStreamChoice{
					{
						Index: 0,
						Delta: openai.ChatCompletionStreamChoiceDelta{
							Role:    openai.ChatMessageRoleAssistant,
							Content: `<think>`,
						},
						FinishReason: openai.FinishReasonNull,
					},
				},
			}
		case sseData.AgentStatus.Type == "thinking_detail_stream":
			sseMsg = types.ChatCompletionStreamResponse{
				ID:                "chatcmpl-" + chatId,
				Object:            sseObject,
				SystemFingerprint: fingerprint,
				Created:           now,
				Model:             model,
				Choices: []types.ChatCompletionStreamChoice{
					{
						Index: 0,
						Delta: openai.ChatCompletionStreamChoiceDelta{
							Role:    openai.ChatMessageRoleAssistant,
							Content: sseData.AgentStatus.Metadata.ReasoningDetail,
						},
						FinishReason: openai.FinishReasonNull,
					},
				},
			}
		default:
			if thinkFlag {
				sseData.Text = "</think>" + sseData.Text
				thinkFlag = false
			}
			sseMsg = types.ChatCompletionStreamResponse{
				ID:                "chatcmpl-" + chatId,
				Object:            sseObject,
				SystemFingerprint: fingerprint,
				Created:           now,
				Model:             model,
				Choices: []types.ChatCompletionStreamChoice{
					{
						Index: 0,
						Delta: openai.ChatCompletionStreamChoiceDelta{
							Role:    openai.ChatMessageRoleAssistant,
							Content: sseData.Text,
						},
						FinishReason: openai.FinishReasonNull,
					},
				},
			}
		}

		// 从池中获取字符串构建器
		sb := stringBuilderPool.Get().(*strings.Builder)
		sb.WriteString("data: ")
		sendLine, _ := sonic.MarshalString(sseMsg)
		sb.WriteString(sendLine)
		sb.WriteString("\n\n")

		// 写入缓冲区
		if _, err := writer.WriteString(sb.String()); err != nil {
			// 归还字符串构建器到池中
			sb.Reset()
			stringBuilderPool.Put(sb)
			return fmt.Errorf("write error: %w", err)
		}
		
		// 使用完毕，归还字符串构建器到池中
		sb.Reset()
		stringBuilderPool.Put(sb)

		// 如果发现 finished=true，就可以结束
		if sseData.Finished {
			if cfg != nil && cfg.Logging.EnableRequestLog {
				logger.Info("SSE流式响应完成",
					zap.String("model", model),
					zap.String("chat_id", chatId),
					zap.String("finish_reason", "stream_finished"),
					zap.Int64("chunk_count", chunkCount),
					zap.Duration("duration", time.Since(startTime)),
				)
			}
			
			writer.WriteString(dataPrefix)
			writer.WriteString(sseFinish)
			writer.WriteString(lineEnd)
			writer.Flush()
			if f, ok := w.(http.Flusher); ok {
				f.Flush()
			}
			return nil
		}

		// 定期记录处理进度
		if cfg != nil && cfg.Logging.EnableRequestLog && chunkCount%20 == 0 {
			logger.Debug("SSE流式响应进度",
				zap.String("model", model),
				zap.String("chat_id", chatId),
				zap.Int64("chunk_count", chunkCount),
				zap.Duration("duration", time.Since(startTime)),
				zap.Int("current_text_length", len(sseData.Text)),
				zap.Bool("thinking_mode", thinkFlag),
			)
		}

		sseData.AgentStatus.Type = ""
		sseData.Finished = false
		return nil
	})
}
