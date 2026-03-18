#!/bin/bash

echo "=== 整理openclaw_log文件夹 ==="
echo "时间: $(date)"
echo ""

LOG_DIR="/Users/wlli/Documents/project/openclaw/monica2api/doc/openclaw_log"
LOGS_SUBDIR="$LOG_DIR/logs"

# 确保logs文件夹存在
mkdir -p "$LOGS_SUBDIR"

echo "1. 检查当前文件结构..."
echo "   总文件数: $(ls -1 "$LOG_DIR" | wc -l)"
echo "   logs文件夹: $(ls -1 "$LOGS_SUBDIR" 2>/dev/null | wc -l) 个文件"
echo "   memory文件夹: $(ls -1 "$LOG_DIR/memory" 2>/dev/null | wc -l) 个文件"
echo "   scripts文件夹: $(ls -1 "$LOG_DIR/scripts" 2>/dev/null | wc -l) 个文件"

echo ""
echo "2. 移动文件到logs文件夹（排除memory、scripts、logs本身）..."

# 需要移动的文件类型
FILES_TO_MOVE=$(ls -1 "$LOG_DIR" | grep -v -E '^(memory|scripts|logs|\.DS_Store)$' | grep -v '^\.')

MOVED_COUNT=0
SKIPPED_COUNT=0

for file in $FILES_TO_MOVE; do
    if [ -f "$LOG_DIR/$file" ]; then
        echo "   移动: $file"
        mv "$LOG_DIR/$file" "$LOGS_SUBDIR/"
        MOVED_COUNT=$((MOVED_COUNT + 1))
    else
        echo "   跳过: $file (不是文件)"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
done

echo ""
echo "3. 整理后的文件结构..."
echo "   openclaw_log/ 目录内容："
ls -la "$LOG_DIR" | grep -E '^d' | awk '{print "     " $9}'

echo ""
echo "   logs/ 目录内容："
if [ -d "$LOGS_SUBDIR" ]; then
    ls -la "$LOGS_SUBDIR" | tail -n +2 | while read line; do
        echo "     $(echo $line | awk '{print $9}')"
    done
else
    echo "     logs文件夹不存在"
fi

echo ""
echo "4. 创建README文件..."
cat > "$LOG_DIR/README.md" << 'EOF'
# openclaw_log 目录结构说明

## 目录结构
```
openclaw_log/
├── README.md          # 本说明文件
├── logs/              # 日志文件目录
│   ├── *.md           # 各种日志和文档文件
│   └── *.pdf          # PDF文档
├── memory/            # 工作记忆目录
│   └── YYYY-MM-DD.md  # 每日工作记录
└── scripts/           # 脚本目录
    ├── *.sh           # 各种Shell脚本
    └── README.md      # 脚本说明
```

## 文件说明

### logs/ 目录
存放所有的日志文件、问题记录、解决方案文档等。按日期和主题组织。

### memory/ 目录
存放每日工作记忆，记录重要的工作内容、决策和思考过程。

### scripts/ 目录
存放各种测试、修复、验证脚本，便于复用和维护。

## 使用规范

1. **日志文件命名**：`YYYY-MM-DD_主题描述.md`
2. **记忆文件命名**：`YYYY-MM-DD.md`
3. **脚本文件命名**：`功能描述.sh`
4. **定期整理**：每月初整理上个月的日志文件

## 最近更新
- 2026-03-11: 整理目录结构，将所有日志文件移动到logs/目录
- 2026-03-11: 添加Monica代理修复相关文档和脚本
EOF

echo "✅ 已创建README.md"

echo ""
echo "=== 整理完成 ==="
echo "📊 统计："
echo "  - 移动文件: $MOVED_COUNT 个"
echo "  - 跳过文件: $SKIPPED_COUNT 个"
echo "  - 保留文件夹: memory/, scripts/, logs/"
echo ""
echo "🎯 新的目录结构："
echo "  openclaw_log/"
echo "  ├── README.md"
echo "  ├── logs/          (所有日志文件)"
echo "  ├── memory/        (工作记忆)"
echo "  └── scripts/       (脚本文件)"
echo ""
echo "✅ 整理完成！"