# Monica代理请求处理流程图

## 系统架构概览

```
飞书消息 → OpenClaw网关 → Agent → Monica代理 → 模型API
```

## 详细处理流程

### 1. 请求入口阶段
```
HTTP POST /v1/chat/completions
         ↓
router.go:createChatCompletionHandler()
         ↓
解析请求体: c.Bind(&openai.ChatCompletionRequest)
         ↓
记录调试日志: logger.Info("=== 收到客户端请求 ===")
         ↓
获取User-Agent判断客户端类型
```

### 2. 分支决策阶段
```
调用: shouldUseCustomBot(req.Model, cfg)
         ↓
检查配置: cfg.Monica.EnableCustomBotMode
         ├── 如果false → 返回false (直接调用)
         └── 如果true → 继续判断
                 ↓
         转换模型名: modelLower = strings.ToLower(model)
                 ↓
         检查原生大模型: ["deepseek", "qwen", "kimi"]
                 ├── 如果匹配 → 返回false (直接调用)
                 └── 如果不匹配 → 继续判断
                         ↓
                 检查需要FC的模型: ["gpt-", "claude-", "gemini-", "o1-", "o3", "o4-", "sonar", "grok-"]
                         ├── 如果匹配 → 返回true (走Monica代理)
                         └── 如果不匹配 → 返回false (直接调用)
```

### 3. 分支处理阶段
```
if shouldUseCustomBot() == true:
    ↓
    logger.Info("使用Custom Bot分支处理请求")
    ↓
    customBotService.HandleCustomBotChat(ctx, &req, cfg.Monica.BotUID)
    ↓
    │
    ├── 支持Function Calling
    ├── 可以执行系统命令
    └── 通过Monica API访问需要FC的模型
else:
    ↓
    logger.Info("使用普通Chat分支处理请求")
    ↓
    chatService.HandleChatCompletion(ctx, &req)
    ↓
    │
    ├── 直接调用模型API
    ├── 不支持Function Calling
    └── 适用于原生大模型
```

### 4. 响应处理阶段
```
获取处理结果: result, err
         ↓
判断响应方式: shouldStream = req.Stream && !isOpenClaw
         ↓
if shouldStream == true:
    ↓
    设置响应头: Content-Type: text/event-stream
    ↓
    monica.StreamMonicaSSEToClientWithConfig()
    ↓
    │
    ├── 流式SSE输出
    ├── 实时返回token
    └── 适用于Web界面
else:
    ↓
    c.JSON(http.StatusOK, result)
    ↓
    │
    ├── JSON格式输出
    ├── 一次性返回完整响应
    └── 适用于API调用
```

## 关键类和方法说明

### router.go - 路由处理器
- **`shouldUseCustomBot(model string, cfg *config.Config) bool`**
  - 功能: 判断请求应该走哪个分支
  - 输入: 模型名称字符串，配置对象
  - 输出: true=走Monica代理，false=直接调用

- **`createChatCompletionHandler(chatService, customBotService, cfg)`**
  - 功能: 主请求处理器
  - 职责: 解析请求、决策分支、处理响应

- **`createCustomBotHandler(customBotService, cfg)`**
  - 功能: Custom Bot专用处理器
  - 用于: 直接调用Custom Bot接口

### service/chat_service.go - 普通聊天服务
- **`HandleChatCompletion(ctx, *openai.ChatCompletionRequest)`**
  - 功能: 直接调用模型API
  - 适用于: DeepSeek、Qwen等原生大模型

### service/custom_bot_service.go - Custom Bot服务
- **`HandleCustomBotChat(ctx, *openai.ChatCompletionRequest, botUID)`**
  - 功能: 通过Monica代理处理请求
  - 支持: Function Calling、系统命令执行
  - 适用于: GPT、Claude、Gemini等需要FC的模型

### monica/stream.go - 流式处理
- **`StreamMonicaSSEToClientWithConfig(model, writer, reader, cfg)`**
  - 功能: 转换Monica API响应为SSE格式
  - 支持: 流式输出、配置参数传递

## 配置说明

### config.yaml - Monica代理配置
```yaml
monica:
  enable_custom_bot_mode: true/false  # 是否启用Custom Bot模式
  default_model: "deepseek-chat"      # 默认模型
  bot_uid: "xxx"                      # Monica Bot UID
  cookie: "xxx"                       # Monica Cookie
```

### openclaw.json - OpenClaw客户端配置
```json
{
  "models": {
    "providers": {
      "monica": {
        "baseUrl": "http://localhost:8080/v1",
        "apiKey": "xxx",
        "models": ["gpt-5", "claude-4-sonnet", ...]
      },
      "deepseek": {
        "baseUrl": "https://api.deepseek.com/v1",
        "apiKey": "xxx",
        "models": ["deepseek-chat", "deepseek-coder"]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "deepseek/deepseek-chat",
        "fallbacks": ["monica/claude-4-sonnet", ...]
      }
    }
  }
}
```

## 调试日志关键点

### 请求接收日志
```
=== 收到客户端请求 ===
user_agent: ...
is_openclaw: true/false
request_stream: true/false
model: ...
enable_custom_bot_mode: true/false
default_model: ...
```

### 分支决策日志
```
开始判断模型分支
model: ...
enable_custom_bot_mode: ...
模型名称转换为小写
原生大模型使用直接调用模式
模型需要Monica代理（Function Calling）
```

### 处理过程日志
```
使用Custom Bot分支处理请求
使用普通Chat分支处理请求
响应方式决策
original_stream: ...
is_openclaw: ...
final_stream: ...
```

## 常见问题排查

### 问题1: DeepSeek走了Monica代理
- 检查: `shouldUseCustomBot`函数中的deepseek匹配逻辑
- 验证: Monica代理日志中的model参数
- 修复: 确保deepseek返回false

### 问题2: 飞书消息无响应
- 检查: 响应格式是否为JSON（OpenClaw需要JSON）
- 验证: `isOpenClaw`判断逻辑
- 修复: 强制OpenClaw使用非流式JSON响应

### 问题3: 模型切换后无法回退
- 检查: OpenClaw的模型切换实现
- 验证: Monica代理配置的`enable_custom_bot_mode`
- 修复: 确保切换逻辑正确更新配置

## 版本历史
- 2026-03-17: 创建流程图文档
- 2026-03-17: 修复`shouldUseCustomBot`函数逻辑
- 2026-03-17: 优化模型匹配策略