#!/bin/bash
# 手动安装常用技能

set -e

SKILLS_DIR="$HOME/.openclaw/workspace/skills"
mkdir -p "$SKILLS_DIR"

echo "📦 开始安装技能..."

# 1. 创建cron技能（定时任务）
echo "⏰ 安装cron技能..."
CRON_DIR="$SKILLS_DIR/cron"
mkdir -p "$CRON_DIR"

cat > "$CRON_DIR/SKILL.md" << 'EOF'
# Cron Skill - 定时任务管理

管理OpenClaw的定时任务（cron jobs）。

## 功能
- 创建、列出、删除定时任务
- 监控任务执行状态
- 查看任务日志

## 使用方法
```bash
# 列出所有定时任务
openclaw cron list

# 创建定时任务
openclaw cron create --name "daily-backup" --schedule "0 2 * * *" --command "backup.sh"

# 删除定时任务
openclaw cron delete --name "daily-backup"
```

## 配置
在OpenClaw配置文件中启用cron插件：
```json
{
  "cron": {
    "enabled": true,
    "jobs": []
  }
}
```
EOF

echo "✅ cron技能已创建"

# 2. 创建memory技能（长期记忆）
echo "🧠 安装memory技能..."
MEMORY_DIR="$SKILLS_DIR/memory"
mkdir -p "$MEMORY_DIR"

cat > "$MEMORY_DIR/SKILL.md" << 'EOF'
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
EOF

echo "✅ memory技能已创建"

# 3. 创建code-agent技能（编程助手）
echo "💻 安装code-agent技能..."
CODE_AGENT_DIR="$SKILLS_DIR/code-agent"
mkdir -p "$CODE_AGENT_DIR"

cat > "$CODE_AGENT_DIR/SKILL.md" << 'EOF'
# Code Agent Skill - 编程助手

AI编程助手，帮助编写、调试和优化代码。

## 功能
- 代码生成和补全
- 代码审查和优化
- 错误调试和修复
- 代码解释和文档生成

## 使用方法
```bash
# 生成代码
openclaw code generate --language python --task "快速排序算法"

# 审查代码
openclaw code review --file main.py

# 调试代码
openclaw code debug --error "TypeError: ..."

# 优化代码
openclaw code optimize --file app.js --goal "性能优化"
```

## 支持的语言
- Python, JavaScript, TypeScript
- Java, C++, C#
- Go, Rust, Swift
- HTML, CSS, SQL
EOF

echo "✅ code-agent技能已创建"

# 4. 创建image-gen技能（图像生成）
echo "🎨 安装image-gen技能..."
IMAGE_GEN_DIR="$SKILLS_DIR/image-gen"
mkdir -p "$IMAGE_GEN_DIR"

cat > "$IMAGE_GEN_DIR/SKILL.md" << 'EOF'
# Image Generation Skill - 图像生成

使用AI生成图像。

## 功能
- 文本到图像生成
- 图像编辑和修改
- 图像风格转换
- 图像放大和优化

## 使用方法
```bash
# 生成图像
openclaw image generate --prompt "一只可爱的猫在月球上" --size "1024x1024"

# 编辑图像
openclaw image edit --input cat.jpg --prompt "添加太空服"

# 转换风格
openclaw image style --input photo.jpg --style "油画风格"

# 放大图像
openclaw image upscale --input small.jpg --scale 2
```

## 支持的模型
- DALL-E 3
- Stable Diffusion
- Midjourney (通过API)
- 本地模型
EOF

echo "✅ image-gen技能已创建"

# 5. 创建github-ai-trends技能（AI趋势追踪）
echo "📊 安装github-ai-trends技能..."
GITHUB_TRENDS_DIR="$SKILLS_DIR/github-ai-trends"
mkdir -p "$GITHUB_TRENDS_DIR"

cat > "$GITHUB_TRENDS_DIR/SKILL.md" << 'EOF'
# GitHub AI Trends Skill - AI趋势追踪

追踪GitHub上的AI项目趋势。

## 功能
- 发现热门AI项目
- 追踪star增长趋势
- 分析技术栈使用
- 生成趋势报告

## 使用方法
```bash
# 获取热门AI项目
openclaw github trends --category "ai" --period "weekly"

# 追踪特定项目
openclaw github track --repo "openai/openai-python"

# 分析技术趋势
openclaw github analyze --topic "machine-learning"

# 生成趋势报告
openclaw github report --output trends.md
```

## 数据源
- GitHub Trending
- GitHub API
- 开源数据集
EOF

echo "✅ github-ai-trends技能已创建"

# 6. 创建twitter/bird技能（社媒自动化）
echo "🐦 安装twitter/bird技能..."
TWITTER_DIR="$SKILLS_DIR/twitter-bird"
mkdir -p "$TWITTER_DIR"

cat > "$TWITTER_DIR/SKILL.md" << 'EOF'
# Twitter Bird Skill - 社交媒体自动化

Twitter/X平台自动化工具。

## 功能
- 自动发帖和转推
- 内容监控和分析
- 粉丝互动管理
- 趋势话题追踪

## 使用方法
```bash
# 发送推文
openclaw twitter post --text "Hello Twitter!"

# 监控话题
openclaw twitter monitor --hashtag "AI"

# 分析账号
openclaw twitter analyze --username "openai"

# 自动互动
openclaw twitter engage --keyword "机器学习"
```

## 注意事项
- 需要Twitter API密钥
- 遵守平台使用条款
- 注意API调用限制
EOF

echo "✅ twitter/bird技能已创建"

# 7. 创建brave-search/exa技能（智能搜索）
echo "🔍 安装brave-search/exa技能..."
SEARCH_DIR="$SKILLS_DIR/brave-search-exa"
mkdir -p "$SEARCH_DIR"

cat > "$SEARCH_DIR/SKILL.md" << 'EOF'
# Brave Search/Exa Skill - 智能搜索

多搜索引擎集成，提供智能搜索功能。

## 功能
- 多搜索引擎聚合（Brave, Exa, Google等）
- 搜索结果去重和排序
- 智能摘要生成
- 搜索历史管理

## 使用方法
```bash
# 搜索网页
openclaw search web --query "最新AI进展"

# 搜索学术论文
openclaw search academic --query "transformer architecture"

# 搜索新闻
openclaw search news --query "科技新闻"

# 生成搜索摘要
openclaw search summarize --query "机器学习教程"
```

## 支持的搜索引擎
- Brave Search
- Exa AI
- Google Search
- DuckDuckGo
- 百度搜索
EOF

echo "✅ brave-search/exa技能已创建"

# 8. 创建agent-browser技能（浏览器自动化）
echo "🤖 安装agent-browser技能..."
BROWSER_DIR="$SKILLS_DIR/agent-browser"
mkdir -p "$BROWSER_DIR"

cat > "$BROWSER_DIR/SKILL.md" << 'EOF'
# Agent Browser Skill - 浏览器自动化

自动化浏览器操作，实现网页自动化。

## 功能
- 网页导航和操作
- 表单自动填写
- 数据抓取和提取
- 屏幕截图和录制

## 使用方法
```bash
# 打开网页
openclaw browser open --url "https://example.com"

# 点击元素
openclaw browser click --selector "button.submit"

# 填写表单
openclaw browser fill --form "login" --data '{"username": "test", "password": "pass"}'

# 截图
openclaw browser screenshot --output page.png

# 抓取数据
openclaw browser scrape --selector ".article" --output articles.json
```

## 支持的操作
- 点击、输入、滚动
- 等待元素加载
- JavaScript执行
- 文件上传下载
EOF

echo "✅ agent-browser技能已创建"

echo ""
echo "🎉 所有技能已安装完成！"
echo ""
echo "安装的技能列表："
echo "1. 🤖 agent-browser - 浏览器自动化"
echo "2. 🔍 brave-search/exa - 智能搜索"
echo "3. 🐦 twitter/bird - 社媒自动化"
echo "4. 💻 code-agent - 编程助手"
echo "5. 🎨 image-gen - 图像生成"
echo "6. 📊 github-ai-trends - AI趋势追踪"
echo "7. ⏰ cron - 定时任务"
echo "8. 🧠 memory - 长期记忆"
echo ""
echo "技能目录：$SKILLS_DIR"
echo ""
echo "下一步："
echo "1. 在OpenClaw配置中启用这些技能"
echo "2. 根据需要配置API密钥和其他设置"
echo "3. 运行测试确保功能正常"