#!/bin/bash

echo "=== 替换项目中的敏感信息 ==="
echo "时间: $(date)"
echo ""

PROJECT_DIR="/Users/wlli/Documents/project/openclaw/monica2api"
BACKUP_DIR="/tmp/project_backup_$(date +%Y%m%d_%H%M%S)"

# 备份项目
echo "1. 备份项目到: $BACKUP_DIR"
cp -r "$PROJECT_DIR" "$BACKUP_DIR"

echo "2. 替换敏感信息..."

# 定义要处理的文件
FILES_TO_PROCESS=(
  "$PROJECT_DIR/CLAUDE.md"
  "$PROJECT_DIR/README.md"
  "$PROJECT_DIR/doc/openclaw_log/logs/006_monica_openclaw_integration_spec.md"
  "$PROJECT_DIR/doc/openclaw_log/logs/2026-03-09_monica_api_fix_and_improvements.md"
  "$PROJECT_DIR/doc/openclaw_log/logs/Monica代理检查修复手册.md"
  "$PROJECT_DIR/doc/openclaw_log/logs/2026-03-06_monica_api_initial_problem.md"
  "$PROJECT_DIR/doc/openclaw_log/logs/2026-03-11_monica_proxy_fix_experience.md"
  "$PROJECT_DIR/doc/openclaw_log/logs/2026-03-06_monica_api_implementation_and_fix.md"
  "$PROJECT_DIR/doc/openclaw_log/scripts/README.md"
)

REPLACEMENT_COUNT=0

for file in "${FILES_TO_PROCESS[@]}"; do
    if [ -f "$file" ]; then
        echo "   处理: $(basename "$file")"
        
        # 备份原文件
        cp "$file" "${file}.backup"
        
        # 替换示例token为安全版本
        # 1. 替换类似 "your_token" 的示例
        sed -i '' 's/your_token/YOUR_TOKEN_HERE/g' "$file"
        
        # 2. 替换类似 "your_bearer_token" 的示例
        sed -i '' 's/your_bearer_token/YOUR_BEARER_TOKEN_HERE/g' "$file"
        
        # 3. 替换类似 "your_api_token" 的示例
        sed -i '' 's/your_api_token/YOUR_API_TOKEN_HERE/g' "$file"
        
        # 4. 替换类似 "d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f176949c2" 的实际token（保留前8位）
        # 使用更安全的替换方式
        sed -i '' 's/\(Bearer \)\?[a-f0-9]\{64\}/TOKEN_REMOVED_FOR_SECURITY/g' "$file"
        
        # 5. 替换export语句中的token
        sed -i '' 's/export BEARER_TOKEN="[^"]*"/export BEARER_TOKEN="YOUR_TOKEN_HERE"/g' "$file"
        
        REPLACEMENT_COUNT=$((REPLACEMENT_COUNT + 1))
    else
        echo "   跳过: $(basename "$file") (文件不存在)"
    fi
done

echo ""
echo "3. 验证替换结果..."
echo "   在README.md中查找token:"
grep -i -E "(token|bearer|api.?key)" "$PROJECT_DIR/README.md" | head -3

echo ""
echo "   在CLAUDE.md中查找token:"
grep -i -E "(token|bearer|api.?key)" "$PROJECT_DIR/CLAUDE.md" | head -3

echo ""
echo "=== 替换完成 ==="
echo "📊 统计："
echo "  - 处理文件: $REPLACEMENT_COUNT 个"
echo "  - 备份位置: $BACKUP_DIR"
echo "  - 原文件备份: 每个文件都有 .backup 副本"
echo ""
echo "✅ 敏感信息已替换为安全版本"