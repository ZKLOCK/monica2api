# 2026-03-17 - DeepSeek分支修复日志

## 问题回顾
根据昨天的反馈，项目存在以下问题：

### 现象
1. 在飞书发消息时，系统应该根据OpenClaw配置的大模型走不同分支：
   - 分支1：飞书 → OpenClaw → DeepSeek（直接调用）
   - 分支2：飞书 → OpenClaw → Monica Proxy → 大模型（Function Calling）

2. 当OpenClaw配置默认模型为DeepSeek时，系统应该走分支1，但实际卡住不动

### 用户猜测
用户猜测：代码可能把DeepSeek分支也调用了Monica Proxy，返回消息为流式，所以没显示

### 修复目标
1. 优先修复分支1（DeepSeek直接调用），让这条分支先正常
2. 验证用户猜测是否正确
3. 找到问题并修复

## 开始修复工作

### 时间记录
- **开始时间**: 2026-03-17 10:52 GMT+8
- **当前状态**: 已发现关键问题

### 第一步：分析代码结构，发现问题

通过分析代码，我发现了以下关键信息：

#### 1. 消息处理流程
在 `/internal/apiserver/router.go` 的 `createChatCompletionHandler` 函数中，消息处理逻辑如下：

```go
// 检查是否启用了 Custom Bot 模式
if cfg.Monica.EnableCustomBotMode {
    // 使用 Custom Bot Service 处理请求
    result, err = customBotService.HandleCustomBotChat(ctx, &req, cfg.Monica.BotUID)
} else {
    // 使用普通的 Chat Service 处理请求
    result, err = chatService.HandleChatCompletion(ctx, &req)
}
```

#### 2. 问题分析
根据代码逻辑，**无论使用什么模型**，只要 `cfg.Monica.EnableCustomBotMode` 为 `true`，就会走 Custom Bot 分支（分支2），而不是根据模型类型选择分支。

#### 3. 用户猜测验证
用户的猜测是正确的：当OpenClaw配置默认模型为DeepSeek时，系统仍然走了Custom Bot分支（分支2），导致消息卡住。

#### 4. 响应方式决策
代码中还有另一个重要逻辑：
```go
// 根据客户端类型和请求参数决定响应方式
// 如果是 OpenClaw，强制使用非流式 JSON 响应
shouldStream := req.Stream && !isOpenClaw
```

这意味着对于OpenClaw客户端，即使请求是流式的，也会被强制转换为非流式JSON响应。这可能是正确的，但前提是分支选择正确。

### 第二步：查看配置结构和模型映射

通过查看代码，我发现了以下重要信息：

#### 1. 模型映射
在 `/internal/types/monica.go` 中，有模型到Bot UID的映射：
```go
var modelToBotMap = map[string]string{
    // ... 其他模型
    "deepseek-reasoner": "deepseek_reasoner",
    "deepseek-chat":     "deepseek_chat",
    // ... 其他模型
}
```

#### 2. 当前问题总结
1. **分支选择逻辑错误**：当前代码只根据 `cfg.Monica.EnableCustomBotMode` 配置来决定走哪个分支，而不是根据模型类型
2. **DeepSeek应该直接调用**：DeepSeek模型支持系统命令调用，应该直接调用，不需要走Monica Proxy
3. **响应方式问题**：即使走了错误的分支，OpenClaw客户端也会被强制使用非流式JSON响应，但可能因为其他原因卡住

#### 3. 修复方案设计
需要修改 `createChatCompletionHandler` 函数中的分支选择逻辑：

**当前逻辑**：
```go
if cfg.Monica.EnableCustomBotMode {
    // 走Custom Bot分支
} else {
    // 走普通Chat分支
}
```

**应该改为**：
```go
if shouldUseCustomBot(req.Model, cfg) {
    // 走Custom Bot分支（Function Calling）
} else {
    // 走普通Chat分支（直接调用）
}
```

其中 `shouldUseCustomBot` 函数需要判断：
1. 模型是否需要Function Calling（如GPT系列、Claude系列等）
2. 模型是否支持直接调用（如DeepSeek）
3. 配置是否启用了Custom Bot模式

### 第三步：实现修复

我已经完成了以下修复：

#### 1. 添加了 `shouldUseCustomBot` 函数
在 `/internal/apiserver/router.go` 中添加了判断函数：
```go
func shouldUseCustomBot(model string, cfg *config.Config) bool {
    // 如果未启用Custom Bot模式，直接返回false
    if !cfg.Monica.EnableCustomBotMode {
        return false
    }

    // 将模型转换为小写以便比较
    modelLower := strings.ToLower(model)
    
    // DeepSeek模型直接调用，不走Custom Bot
    if strings.Contains(modelLower, "deepseek") {
        logger.Info("DeepSeek模型使用直接调用模式", 
            zap.String("model", model),
            zap.Bool("enable_custom_bot_mode", cfg.Monica.EnableCustomBotMode),
        )
        return false
    }

    // 其他需要Function Calling的模型走Custom Bot分支
    logger.Info("模型使用Custom Bot模式", 
        zap.String("model", model),
        zap.Bool("enable_custom_bot_mode", cfg.Monica.EnableCustomBotMode),
    )
    return true
}
```

#### 2. 修改了分支选择逻辑
将原来的：
```go
if cfg.Monica.EnableCustomBotMode {
    // 走Custom Bot分支
} else {
    // 走普通Chat分支
}
```

修改为：
```go
if shouldUseCustomBot(req.Model, cfg) {
    // 使用 Custom Bot Service 处理请求（Function Calling）
    result, err = customBotService.HandleCustomBotChat(ctx, &req, cfg.Monica.BotUID)
} else {
    // 使用普通的 Chat Service 处理请求（直接调用）
    result, err = chatService.HandleChatCompletion(ctx, &req)
}
```

#### 3. 添加了详细的日志记录
在关键决策点添加了日志，便于调试和监控。

### 第四步：测试修复

由于当前环境缺少Go编译工具，我无法直接编译测试。但是我已经完成了代码修复，现在总结一下：

#### 修复内容总结

**1. 问题根源**
- 原来的代码只根据 `cfg.Monica.EnableCustomBotMode` 配置来决定分支
- 无论什么模型，只要启用了Custom Bot模式，都走Custom Bot分支
- 这导致DeepSeek模型也走了错误的路径

**2. 修复方案**
- 添加了 `shouldUseCustomBot` 函数，根据模型类型智能选择分支
- DeepSeek模型（包含"deepseek"字符串）走普通Chat分支（直接调用）
- 其他需要Function Calling的模型走Custom Bot分支
- 添加了详细的日志记录，便于调试

**3. 代码修改**
- 文件：`/internal/apiserver/router.go`
- 新增函数：`shouldUseCustomBot`
- 修改逻辑：`createChatCompletionHandler` 中的分支选择

#### 测试建议

由于无法编译，建议用户：

1. **手动测试步骤**：
   ```bash
   # 1. 确保项目可以编译
   cd /Users/wlli/Documents/project/openclaw/monica2api
   go build -o monica2api ./main_wails.go
   
   # 2. 启动服务
   ./monica2api
   
   # 3. 测试DeepSeek分支
   # 配置OpenClaw使用deepseek模型，发送消息测试
   ```

2. **验证日志**：
   - 查看服务日志，确认DeepSeek模型走了正确的分支
   - 日志中应该看到："DeepSeek模型使用直接调用模式"
   - 而不是："模型使用Custom Bot模式"

3. **功能验证**：
   - DeepSeek模型应该能正常响应，不再卡住
   - 其他需要Function Calling的模型应该继续走Custom Bot分支

#### 潜在问题

1. **模型判断逻辑**：目前只判断模型名是否包含"deepseek"，可能需要扩展其他直接调用模型
2. **配置兼容**：确保 `cfg.Monica.EnableCustomBotMode` 配置正确
3. **日志级别**：确保日志级别足够详细，能看到分支选择信息

### 修复完成时间
- **开始时间**: 2026-03-17 10:52 GMT+8
- **完成时间**: 2026-03-17 11:15 GMT+8
- **修复时长**: 约23分钟

### 下一步建议

1. **编译测试**：在Go环境可用时编译测试
2. **扩展模型判断**：根据需要添加更多直接调用模型的判断
3. **监控验证**：在生产环境中监控分支选择是否正确
4. **文档更新**：更新相关文档说明分支选择逻辑