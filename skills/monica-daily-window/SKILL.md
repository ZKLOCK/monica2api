# Monica Daily Window Skill

管理Monica API的对话窗口，实现每天一个对话窗口的功能。

## 功能

- **按天管理对话**：每天自动创建一个新的对话窗口，当天内复用同一个conversation_id
- **自动保存对话ID**：本地存储对话ID映射，避免重复创建对话
- **流式响应支持**：支持流式和非流式响应
- **对话历史管理**：查看和管理历史对话记录

## 使用方法

### 基本使用

```python
from monica_daily_window import DailyConversationManager

# 初始化管理器
manager = DailyConversationManager(api_key="your_monica_api_key")

# 发送消息（自动管理对话窗口）
result = manager.chat("今天天气怎么样？", model="claude-3-5-sonnet")
print(result["choices"][0]["message"]["content"])
```

### 在OpenClaw中使用

1. 将技能添加到OpenClaw配置
2. 通过技能调用Monica API
3. 自动享受每天一个对话窗口的功能

## 配置

### 环境变量

- `MONICA_API_KEY`: Monica API密钥
- `MONICA_BASE_URL`: Monica API基础URL（默认: https://openapi.monica.im/v1）

### 本地存储

对话ID存储在：`~/.openclaw/monica_conversations.json`

格式：
```json
{
  "2026-03-16": "conv_aabbcc1122",
  "2026-03-17": "conv_ddeeff3344",
  "2026-03-18": "conv_xxyyzz5566"
}
```

## API参考

### DailyConversationManager类

#### `__init__(api_key: str, base_url: str = "https://openapi.monica.im/v1")`
初始化对话管理器。

#### `chat(message: str, model: str = "claude-sonnet-4-6", stream: bool = False) -> Dict`
发送消息并自动管理对话窗口。

#### `get_today_conv_id() -> Optional[str]`
获取今天已有的conversation_id。

#### `save_today_conv_id(conv_id: str)`
保存今天的conversation_id。

#### `get_conversation_history() -> Dict[str, str]`
获取所有保存的对话历史。

#### `clear_old_conversations(days_to_keep: int = 30)`
清理旧的对话记录。

## 示例

### 示例1：基本使用
```python
import os
from monica_daily_window import DailyConversationManager

api_key = os.getenv("MONICA_API_KEY")
manager = DailyConversationManager(api_key=api_key)

# 第一次调用（新建对话）
response1 = manager.chat("今天是2026年3月18日，这是今天的测试对话。")
print(f"回复: {response1['choices'][0]['message']['content'][:100]}...")

# 第二次调用（复用对话）
response2 = manager.chat("继续我们的对话，请帮我写一个Python函数。")
print(f"回复: {response2['choices'][0]['message']['content'][:100]}...")
```

### 示例2：查看对话历史
```python
history = manager.get_conversation_history()
print(f"对话历史: {history}")
```

### 示例3：清理旧对话
```python
# 只保留最近30天的对话记录
manager.clear_old_conversations(days_to_keep=30)
```

## 集成到OpenClaw

### 步骤1：安装技能
```bash
# 将技能文件夹复制到OpenClaw技能目录
cp -r monica-daily-window ~/.openclaw/workspace/skills/
```

### 步骤2：配置OpenClaw
在OpenClaw配置中启用技能。

### 步骤3：使用技能
通过OpenClaw命令或API调用技能功能。

## 故障排除

### 问题1：API调用失败
- 检查API密钥是否正确
- 检查网络连接
- 检查Monica代理是否运行

### 问题2：对话ID不保存
- 检查文件权限：`~/.openclaw/monica_conversations.json`
- 检查存储目录是否存在

### 问题3：流式响应问题
- 确保Monica代理支持流式响应
- 检查超时设置
- 考虑禁用流式响应：`stream=False`

## 更新日志

### v1.0.0 (2026-03-18)
- 初始版本
- 实现按天对话管理
- 支持流式和非流式响应
- 添加对话历史管理功能

## 许可证

MIT License