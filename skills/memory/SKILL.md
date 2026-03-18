# Memory Skill - 长期记忆管理

管理OpenClaw的长期记忆系统。

## 功能
- 存储和检索长期记忆
- 记忆分类和标签
- 记忆搜索和过滤

## 使用方法
```bash
# 保存记忆
openclaw memory save --key "project-ideas" --value "AI助手项目" --tags "ideas,projects"

# 检索记忆
openclaw memory get --key "project-ideas"

# 搜索记忆
openclaw memory search --query "AI助手"

# 列出所有记忆
openclaw memory list
```

## 文件结构
```
~/.openclaw/memory/
├── long-term/     # 长期记忆
├── short-term/    # 短期记忆
└── working/       # 工作记忆
```
