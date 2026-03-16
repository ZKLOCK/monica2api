看一段分析：🔍 核心真相：Function Calling 到底是谁的能力？

你观察到 DeepSeek 返回了 tool_calls（或 function_call）字段，这是对的。目前业界（包括 OpenClaw）几乎都把 OpenAI 的 API 格式 当作了通用标准。

  

但是，Function Calling 并不是一段可以到处复制的“通用代码”，它是一个端到端（Client-Server）的配合过程：

  

客户端 (OpenClaw)：负责把系统命令（如“执行 git 提交”）打包成一段 JSON 描述（即 tools 字段），发给大模型。

服务端 (大模型 API，如 DeepSeek)：模型本身经过了特殊训练，它能看懂这段 JSON。当它觉得需要执行命令时，它会停止输出人类语言，转而输出一段特定格式的 JSON（即 tool_calls 字段）。

客户端 (OpenClaw)：收到这段 JSON，解析它，然后在你的电脑上真正执行 git commit。

🚧 为什么不能直接“复用 OpenClaw 的代码”？

你设想的“把 OpenClaw 的代码加到代理层”，在架构上是不成立的，原因如下：

  

角色错位：OpenClaw 是发指令和干活的人（Client），而你的 Monica Proxy 是个传话筒（中间件）。

能力缺失在源头：OpenClaw 的代码只是用来解析模型返回的 tool_calls 并执行它。如果 Monica 的接口根本就不返回 tool_calls，你把 OpenClaw 的解析代码拷到代理层也没用，因为“巧妇难为无米之炊”。

🕵️‍♂️ 问题的真正症结：Monica 接口到底支不支持？

你的 Monica Proxy 夹在 OpenClaw 和 Monica 官方服务器之间。现在 OpenClaw 发送了带有 tools 的请求，但流程断了。只有两种可能：

  

可能性一：代理层“弄丢”了参数（这是最好的情况，几乎零开发成本）

现状：你的 Proxy 在把 OpenClaw 的请求转发给 Monica 时，可能只提取了 messages（对话内容），而漏掉了 tools 字段。

验证与解决：如果是这样，你根本不需要抄什么复杂代码。只需要在 Proxy 的转发逻辑里加一行代码，把 tools 字段原封不动地透传给 Monica 即可。如果 Monica 底层其实支持这个字段，那问题瞬间解决！

可能性二：Monica 官方接口“阉割”了这个能力（需要二次开发）

现状：Monica 是一个面向 C 端用户的产品，它的内部 API 可能只接受纯文本对话，根本不认识、或者直接忽略了你传过去的 tools 字段。模型（如 GPT-5）虽然聪明，但因为没收到工具列表，自然不会返回 tool_calls。

验证与解决：这就是我上一次说的“方案二”的难点。如果 Monica 官方不认这个字段，我们就必须在 Proxy 层做“欺骗”：

Proxy 拦截 OpenClaw 的 tools。

Proxy 把这些工具翻译成一段纯文本的 Prompt（例如：“你现在是一个可以执行命令的AI，如果你要执行命令，请输出 <execute>命令</execute>”），强行塞进对话里发给 Monica。

Monica 返回文本 <execute>ls</execute>。

Proxy 拦截这个文本，把它伪装成标准的 tool_calls JSON 格式，返回给 OpenClaw。

💡 结论与行动建议

你不需要（也不能）去抄 OpenClaw 的代码。我们现在的当务之急，是确定我们面临的是可能性一还是可能性二。

  

我们只需要做一个极其简单的测试：

  

找到你目前运行 Monica Proxy 的代码（比如是 Python 的 FastAPI 脚本，或者是 Node.js 脚本）。

在接收 OpenClaw 请求的地方，把原始的 Request Payload 打印出来（print(request.json())）。

在转发给 Monica 之前，看看你构造的新 Payload 里，有没有把 tools 加进去。

如果你愿意，你可以把你的 Monica Proxy 的核心转发代码（去掉真实的 Token/Cookie）发给我看看。我一眼就能看出是代理层漏传了参数，还是我们需要上“硬核魔改”方案。 这样评估成本才最准确。