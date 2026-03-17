package apiserver

import (
	"fmt"
	"io"
	"monica-proxy/internal/config"
	"monica-proxy/internal/errors"
	"monica-proxy/internal/logger"
	"monica-proxy/internal/middleware"
	"monica-proxy/internal/monica"
	"monica-proxy/internal/service"
	"monica-proxy/internal/types"
	"net/http"
	"strings"

	"github.com/labstack/echo/v4"
	"github.com/sashabaranov/go-openai"
	"go.uber.org/zap"
)

// shouldUseCustomBot 判断是否应该使用Custom Bot模式
// 返回true表示需要走Custom Bot分支（Function Calling）
// 返回false表示直接调用模型
func shouldUseCustomBot(model string, cfg *config.Config) bool {
	logger.Debug("开始判断模型分支",
		zap.String("model", model),
		zap.Bool("enable_custom_bot_mode", cfg.Monica.EnableCustomBotMode),
	)
	
	// 如果未启用Custom Bot模式，直接返回false
	if !cfg.Monica.EnableCustomBotMode {
		logger.Info("Custom Bot模式未启用，使用直接调用",
			zap.String("model", model),
		)
		return false
	}

	// 将模型转换为小写以便比较
	modelLower := strings.ToLower(model)
	logger.Debug("模型名称转换为小写",
		zap.String("original", model),
		zap.String("lowercase", modelLower),
	)
	
	// 首先检查是否是应该直接调用的原生大模型
	// DeepSeek、Qwen、Kimi等原生大模型直接调用
	directCallModels := []string{
		"deepseek",  // 所有DeepSeek模型
		"qwen",      // 所有Qwen模型
		"kimi",      // Kimi模型
	}
	
	for _, prefix := range directCallModels {
		if strings.Contains(modelLower, prefix) {
			logger.Info("原生大模型使用直接调用模式", 
				zap.String("model", model),
				zap.String("matched_prefix", prefix),
				zap.String("model_lower", modelLower),
			)
			return false
		}
	}
	
	// 定义需要走Monica代理（Custom Bot分支）的模型
	// 这些是需要Function Calling的模型
	monicaProxyModels := []string{
		// GPT系列（需要Function Calling）
		"gpt-", "gpt4", "gpt5",
		
		// Claude系列（需要Function Calling）
		"claude-",
		
		// Gemini系列（需要Function Calling）
		"gemini-",
		
		// OpenAI o系列（需要Function Calling）
		"o1-", "o3", "o4-",
		
		// 其他需要Function Calling的模型
		"sonar",
		"grok-",
	}
	
	// 检查模型是否需要走Monica代理
	for _, prefix := range monicaProxyModels {
		if strings.Contains(modelLower, prefix) {
			logger.Info("模型需要Monica代理（Function Calling）", 
				zap.String("model", model),
				zap.String("matched_prefix", prefix),
				zap.String("model_lower", modelLower),
			)
			return true
		}
	}
	
	// 默认情况下，其他模型也直接调用
	logger.Info("未知模型使用直接调用模式", 
		zap.String("model", model),
		zap.String("model_lower", modelLower),
	)
	return false
}

// RegisterRoutes 注册 Echo 路由
func RegisterRoutes(e *echo.Echo, cfg *config.Config) {
	// 设置自定义错误处理器
	e.HTTPErrorHandler = middleware.ErrorHandler()

	// 添加中间件
	e.Use(middleware.BearerAuth(cfg))
	e.Use(middleware.RequestLogger(cfg))

	// 初始化服务实例
	chatService := service.NewChatService(cfg)
	modelService := service.NewModelService(cfg)
	imageService := service.NewImageService(cfg)
	customBotService := service.NewCustomBotService(cfg)
	fileService := service.NewFileService(cfg)

	// ChatGPT 风格的请求转发到 /v1/chat/completions
	e.POST("/v1/chat/completions", createChatCompletionHandler(chatService, customBotService, cfg))
	// 获取支持的模型列表
	e.GET("/v1/models", createListModelsHandler(modelService))
	// DALL-E 风格的图片生成请求
	e.POST("/v1/images/generations", createImageGenerationHandler(imageService))

	// OpenAI兼容的文件管理API
	e.POST("/v1/files", createFileUploadHandler(fileService))
	e.GET("/v1/files/:file_id", createGetFileHandler(fileService))
	e.GET("/v1/files", createListFilesHandler(fileService))
	e.DELETE("/v1/files/:file_id", createDeleteFileHandler(fileService))

	// Custom Bot 测试接口
	e.POST("/v1/chat/custom-bot/:bot_uid", createCustomBotHandler(customBotService, cfg))
	// 新增不带bot_uid的路由，使用环境变量中的BOT_UID
	e.POST("/v1/chat/custom-bot", createCustomBotHandler(customBotService, cfg))
}

// createChatCompletionHandler 创建聊天完成处理器
func createChatCompletionHandler(chatService service.ChatService, customBotService service.CustomBotService, cfg *config.Config) echo.HandlerFunc {
	return func(c echo.Context) error {
		var req openai.ChatCompletionRequest
		if err := c.Bind(&req); err != nil {
			return errors.NewBadRequestError("无效的请求数据", err)
		}

		ctx := c.Request().Context()
		var result interface{}
		var err error

		// 获取 User-Agent 来判断客户端类型
		userAgent := c.Request().UserAgent()
		isOpenClaw := strings.Contains(strings.ToLower(userAgent), "openclaw")
		
		// 记录完整的请求信息（用于调试）
		logger.Info("=== 收到客户端请求 ===",
			zap.String("user_agent", userAgent),
			zap.Bool("is_openclaw", isOpenClaw),
			zap.Bool("request_stream", req.Stream),
			zap.String("model", req.Model),
			zap.Int("message_count", len(req.Messages)),
			zap.Bool("enable_custom_bot_mode", cfg.Monica.EnableCustomBotMode),
			zap.String("default_model", cfg.Monica.DefaultModel),
			zap.String("bot_uid", cfg.Monica.BotUID),
			zap.Bool("has_cookie", cfg.Monica.Cookie != ""),
		)
		
		// 记录消息内容（前100字符）
		if len(req.Messages) > 0 {
			lastMessage := req.Messages[len(req.Messages)-1]
			contentPreview := lastMessage.Content
			if len(contentPreview) > 100 {
				contentPreview = contentPreview[:100] + "..."
			}
			logger.Info("最后一条消息预览",
				zap.String("role", lastMessage.Role),
				zap.String("content_preview", contentPreview),
			)
		}

		// 根据模型类型决定使用哪个分支
		// DeepSeek等支持直接调用的模型走普通Chat分支
		// 需要Function Calling的模型走Custom Bot分支
		if shouldUseCustomBot(req.Model, cfg) {
			// 使用 Custom Bot Service 处理请求（Function Calling）
			logger.Info("使用Custom Bot分支处理请求",
				zap.String("model", req.Model),
				zap.String("bot_uid", cfg.Monica.BotUID),
				zap.Bool("enable_custom_bot_mode", cfg.Monica.EnableCustomBotMode),
			)
			result, err = customBotService.HandleCustomBotChat(ctx, &req, cfg.Monica.BotUID)
		} else {
			// 使用普通的 Chat Service 处理请求（直接调用）
			logger.Info("使用普通Chat分支处理请求",
				zap.String("model", req.Model),
				zap.Bool("enable_custom_bot_mode", cfg.Monica.EnableCustomBotMode),
			)
			result, err = chatService.HandleChatCompletion(ctx, &req)
		}

		if err != nil {
			logger.Error("处理请求时发生错误", zap.Error(err))
			return err
		}

		// 记录结果类型（用于调试）
		logger.Info("请求处理完成",
			zap.Any("result_type", fmt.Sprintf("%T", result)),
			zap.Bool("is_openclaw", isOpenClaw),
		)

		// 根据客户端类型和请求参数决定响应方式
		// 如果是 OpenClaw，强制使用非流式 JSON 响应
		// 否则，按照请求的 stream 参数处理
		shouldStream := req.Stream && !isOpenClaw
		
		logger.Info("响应方式决策",
			zap.Bool("original_stream", req.Stream),
			zap.Bool("is_openclaw", isOpenClaw),
			zap.Bool("final_stream", shouldStream),
		)

		if shouldStream {
			// 对于流式请求，result是一个io.ReadCloser
			rawBody, ok := result.(io.Reader)
			if !ok {
				return errors.NewInternalError(nil)
			}

			// 确保关闭响应体
			closer, isCloser := rawBody.(io.Closer)
			if isCloser {
				defer closer.Close()
			}

			// 设置响应头
			c.Response().Header().Set(echo.HeaderContentType, "text/event-stream")
			c.Response().Header().Set("Cache-Control", "no-cache")
			c.Response().Header().Set("Transfer-Encoding", "chunked")
			c.Response().WriteHeader(http.StatusOK)

			// 流式处理响应（带配置参数）
			if err := monica.StreamMonicaSSEToClientWithConfig(req.Model, c.Response().Writer, rawBody, cfg); err != nil {
				return errors.NewInternalError(err)
			}
			return nil
		} else {
			// 对于非流式请求，直接返回JSON响应
			logger.Info("返回JSON响应",
				zap.Any("response", result),
				zap.Bool("is_openclaw", isOpenClaw),
			)
			return c.JSON(http.StatusOK, result)
		}
	}
}

// createListModelsHandler 创建模型列表处理器
func createListModelsHandler(modelService service.ModelService) echo.HandlerFunc {
	return func(c echo.Context) error {
		// 调用服务获取模型列表
		models := modelService.GetSupportedModels()

		// 构造响应格式
		result := make(map[string][]struct {
			Id string `json:"id"`
		})

		result["data"] = make([]struct {
			Id string `json:"id"`
		}, 0)

		for _, model := range models {
			result["data"] = append(result["data"], struct {
				Id string `json:"id"`
			}{
				Id: model,
			})
		}
		return c.JSON(http.StatusOK, result)
	}
}

// createImageGenerationHandler 创建图片生成处理器
func createImageGenerationHandler(imageService service.ImageService) echo.HandlerFunc {
	return func(c echo.Context) error {
		// 解析请求
		var req types.ImageGenerationRequest
		if err := c.Bind(&req); err != nil {
			return errors.NewBadRequestError("无效的请求数据", err)
		}

		// 调用服务生成图片
		resp, err := imageService.GenerateImage(c.Request().Context(), &req)
		if err != nil {
			return err
		}

		// 返回结果
		return c.JSON(http.StatusOK, resp)
	}
}

// createCustomBotHandler 创建Custom Bot处理器
func createCustomBotHandler(service service.CustomBotService, cfg *config.Config) echo.HandlerFunc {
	return func(c echo.Context) error {
		// 获取bot UID，优先从路由参数获取，如果没有则从环境变量获取
		botUID := c.Param("bot_uid")
		if botUID == "" {
			// 从配置（环境变量）中获取
			botUID = cfg.Monica.BotUID
			if botUID == "" {
				return errors.NewBadRequestError("bot_uid参数不能为空，请在URL中指定或设置BOT_UID环境变量", nil)
			}
		}

		var req openai.ChatCompletionRequest
		if err := c.Bind(&req); err != nil {
			return errors.NewBadRequestError("请求体解析失败", err)
		}

		ctx := c.Request().Context()
		result, err := service.HandleCustomBotChat(ctx, &req, botUID)
		if err != nil {
			return err
		}

		// 如果是流式响应
		if req.Stream {
			// 设置响应头
			c.Response().Header().Set("Content-Type", "text/event-stream")
			c.Response().Header().Set("Cache-Control", "no-cache")
			c.Response().Header().Set("Connection", "keep-alive")
			c.Response().Header().Set("Transfer-Encoding", "chunked")

			// 获取响应体（io.ReadCloser）
			stream, ok := result.(io.ReadCloser)
			if !ok {
				return errors.NewInternalError(fmt.Errorf("流式响应类型错误"))
			}
			defer stream.Close()

			// 转换并写入响应（带配置参数）
			err := monica.StreamMonicaSSEToClientWithConfig(req.Model, c.Response().Writer, stream, cfg)
			if err != nil {
				logger.Error("流式响应写入失败", zap.Error(err))
				return err
			}

			c.Response().Flush()
			return nil
		}

		// 非流式响应
		return c.JSON(http.StatusOK, result)
	}
}

// createFileUploadHandler 创建文件上传处理器
func createFileUploadHandler(fileService service.FileService) echo.HandlerFunc {
	return func(c echo.Context) error {
		// 解析multipart form
		form, err := c.MultipartForm()
		if err != nil {
			return errors.NewBadRequestError("解析multipart form失败", err)
		}
		defer form.RemoveAll()

		// 获取上传的文件
		files := form.File["file"]
		if len(files) == 0 {
			return errors.NewBadRequestError("未找到上传的文件", nil)
		}

		fileHeader := files[0]

		// 获取purpose参数
		purpose := c.FormValue("purpose")
		if purpose == "" {
			purpose = "assistants" // 默认用途
		}

		// 上传文件
		fileObject, err := fileService.UploadFile(c.Request().Context(), fileHeader, purpose)
		if err != nil {
			return err
		}

		return c.JSON(http.StatusOK, fileObject)
	}
}

// createGetFileHandler 创建获取文件处理器
func createGetFileHandler(fileService service.FileService) echo.HandlerFunc {
	return func(c echo.Context) error {
		fileID := c.Param("file_id")
		if fileID == "" {
			return errors.NewBadRequestError("file_id参数不能为空", nil)
		}

		fileObject, err := fileService.GetFile(c.Request().Context(), fileID)
		if err != nil {
			return err
		}

		return c.JSON(http.StatusOK, fileObject)
	}
}

// createListFilesHandler 创建文件列表处理器
func createListFilesHandler(fileService service.FileService) echo.HandlerFunc {
	return func(c echo.Context) error {
		files, err := fileService.ListFiles(c.Request().Context())
		if err != nil {
			return err
		}

		response := types.FileListResponse{
			Object: "list",
			Data:   make([]types.FileObject, len(files)),
		}

		for i, file := range files {
			response.Data[i] = *file
		}

		return c.JSON(http.StatusOK, response)
	}
}

// createDeleteFileHandler 创建删除文件处理器
func createDeleteFileHandler(fileService service.FileService) echo.HandlerFunc {
	return func(c echo.Context) error {
		fileID := c.Param("file_id")
		if fileID == "" {
			return errors.NewBadRequestError("file_id参数不能为空", nil)
		}

		err := fileService.DeleteFile(c.Request().Context(), fileID)
		if err != nil {
			return err
		}

		response := types.DeleteFileResponse{
			ID:      fileID,
			Object:  "file",
			Deleted: true,
		}

		return c.JSON(http.StatusOK, response)
	}
}
