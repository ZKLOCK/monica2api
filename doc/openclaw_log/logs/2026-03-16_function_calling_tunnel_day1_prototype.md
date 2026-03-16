# Function Calling隧道 - 第一天原型开发日志
## 时间：2025年3月16日 11:55 GMT+8
## 开发者：小龙虾 (Xiao Long Xia)

## 1. 已完成的工作

### 1.1 代码修改
1. **修改了 `internal/types/monica.go`**:
   - 在 `ChatGPTToMonica` 函数中添加了Function Calling隧道支持
   - 检测OpenAI请求中的 `tools` 数组
   - 将tools信息序列化为JSON字符串
   - 在最后一个用户消息中添加隐藏的Function Calling指令

2. **修改了 `internal/monica/sse.go`**:
   - 添加了 `parseFunctionCallFromContent` 函数
   - 修改了 `CollectMonicaSSEToCompletion` 函数
   - 添加了Function Call解析逻辑
   - 支持将隐藏格式转换为OpenAI标准格式

### 1.2 实现细节
#### 发送时（序列化）：
- 检测 `chatReq.Tools` 数组
- 序列化为JSON：`<function_calling_tools>{...}</function_calling_tools>`
- 添加到最后一个用户消息中
- 包含调用指令：`<function_calling_instruction>...</function_calling_instruction>`

#### 接收时（反序列化）：
- 解析响应中的 `<tool_call>{...}</tool_call>` 标签
- 转换为OpenAI标准 `ToolCall` 格式
- 设置正确的 `finish_reason: "tool_calls"`

## 2. 技术要点

### 2.1 隐藏格式设计
```xml
<!-- 发送时添加到用户消息 -->
<function_calling_tools>
{"tools": [{"type": "function", "function": {"name": "run_command", ...}}]}
</function_calling_tools>

<function_calling_instruction>
当你需要调用工具时，请严格按以下格式输出，不要添加任何其他文字：
<tool_call>
{"name": "工具名", "arguments": {...}}
</tool_call>
</function_calling_instruction>

<!-- GPT返回格式 -->
<tool_call>
{"name": "run_command", "arguments": {"cmd": "ls -la"}}
</tool_call>
```

### 2.2 解析逻辑
1. 使用 `strings.Index` 查找标签
2. 提取JSON内容
3. 使用 `sonic.Unmarshal` 解析
4. 转换为OpenAI格式

## 3. 待解决的问题

### 3.1 流式响应支持
- 当前只实现了非流式响应的Function Calling解析
- 流式响应需要累积内容后再解析

### 3.2 容错处理
- GPT可能不严格按格式输出
- 需要添加更健壮的解析逻辑

### 3.3 性能优化
- 当前每次响应都进行字符串搜索
- 可以考虑优化搜索算法

## 4. 测试计划

### 4.1 单元测试
1. 测试 `parseFunctionCallFromContent` 函数
2. 测试工具序列化/反序列化
3. 测试边界情况

### 4.2 集成测试
1. 测试完整的Function Calling流程
2. 测试多工具场景
3. 测试错误处理

## 5. 下一步工作

### 第二天计划：
1. **添加流式响应支持**
   - 修改 `StreamMonicaSSEToClientWithConfig` 函数
   - 实现流式内容的累积和解析

2. **增强容错处理**
   - 添加正则表达式解析
   - 添加格式验证
   - 添加降级策略

3. **编写测试用例**
   - 创建单元测试
   - 创建集成测试

## 6. 风险评估

1. **GPT输出格式不稳定** - 中风险
   - 应对：严格的Prompt设计 + 容错解析

2. **性能影响** - 低风险
   - 应对：字符串操作开销很小

3. **Monica未来可能检查消息内容** - 低风险
   - 应对：可升级为Base64编码

## 7. 总结

第一天原型开发完成，实现了：
- ✅ Function Calling隧道的基本框架
- ✅ 工具信息的序列化/隐藏
- ✅ 响应内容的解析/反序列化
- ✅ 非流式响应的完整支持

明天将重点解决流式响应和容错处理。

---
**状态：** 原型开发完成
**代码位置：** 
- `internal/types/monica.go` (修改了ChatGPTToMonica函数)
- `internal/monica/sse.go` (添加了parseFunctionCallFromContent函数)
**下一步：** 测试原型功能