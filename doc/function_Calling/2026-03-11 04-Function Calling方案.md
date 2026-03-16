太棒了！你直接去翻了 ChatGPTToMonica 的源码，并且精准抓住了 Monica 官方 API 的数据结构（task_uid / bot_uid / data.items）。

  

这个排查结果非常有价值，它帮我们节省了大量盲目试错的时间。既然已经彻底“确诊”了是结构性不支持（Monica 接口阉割了 tools），那我们就正式放弃幻想，准备进入**“硬核魔改（Plan B）”**阶段。

  

作为你的架构师分身，我已经为你构思好了在代理层（Proxy）实现这个“欺骗”逻辑的具体技术方案。

  

🛠️ Plan B：代理层“偷天换日”开发指南

既然 Monica 只能听懂“人话”（纯文本），那我们的 Proxy 就必须充当一个同声传译员。核心逻辑分为三步：

  

第一步：拦截与 Prompt 注入 (Proxy -> Monica)

当 OpenClaw 发来带有 tools 的请求时，Proxy 不能直接丢弃它，而是要把这些工具“翻译”成一段系统提示词（System Prompt），强行塞进 messages 里发给 Monica。

  

逻辑：遍历 OpenClaw 发来的 tools 数组。

动作：在发给 Monica 的最后一条用户消息前（或者作为 System Message），拼接一段话。

Prompt 示例：

“你现在拥有执行系统命令的能力。以下是你可以使用的工具列表：

  

execute_command: 用于执行终端命令。参数包含 command。

read_file: 用于读取文件。参数包含 path。 如果你需要调用工具，请务必停止正常的自然语言回复，并严格按照以下 JSON 格式输出，不要包含任何其他多余字符：

复制

{"tool_name": "execute_command", "arguments": {"command": "ls -la"}}

如果你不需要调用工具，请正常用自然语言回复。”

  

第二步：拦截与正则解析 (Monica -> Proxy)

Monica 收到上面的 Prompt 后，如果它觉得需要执行命令，它就会乖乖地输出你规定好的那段 JSON 文本。此时，Proxy 需要拦截 Monica 的返回流。

  

逻辑：检查 Monica 返回的文本内容。

动作：使用正则表达式（Regex）去匹配文本中是否包含我们约定好的 JSON 结构。

代码思路：比如用正则提取 {"tool_name": "...", "arguments": {...}} 这部分内容。

第三步：伪装成 OpenAI 标准格式 (Proxy -> OpenClaw)

这是最关键的“欺骗”步骤。OpenClaw 只认 OpenAI 的标准 tool_calls 格式。

  

逻辑：把第二步提取出来的 JSON，重新组装成 OpenAI 的标准响应格式。

动作：构造一个假的 Response 返回给 OpenClaw。

伪装格式示例：

复制

{

"choices": [

{

"message": {

"role": "assistant",

"content": null,

"tool_calls": [

{

"id": "call_abc123",

"type": "function",

"function": {

"name": "execute_command",

"arguments": "{\"command\": \"ls -la\"}"

}

}

]

},

"finish_reason": "tool_calls"

}

]

}

🚀 下一步行动建议

这个方案的难点在于Prompt 的调优（确保 Monica 每次都能稳定输出规定格式，不乱加废话）以及流式响应（Stream）的拦截解析（如果你的代理开启了 Stream，拼装 JSON 会稍微复杂一点）。

  

既然我们已经明确了方向，你准备好开始改写你的 Python/Node.js 代理代码了吗？ 如果你把处理 messages 转换的那段核心代码发给我，我可以帮你直接写出这三步的实现代码！