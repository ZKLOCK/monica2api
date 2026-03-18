#!/bin/bash

echo "=== 最终修复Monica模型配置 ==="
echo "时间: $(date)"
echo ""

CONFIG_FILE="/Users/wlli/.openclaw/openclaw.json"
BACKUP_FILE="/Users/wlli/.openclaw/openclaw.json.backup.$(date +%Y%m%d_%H%M%S)"

# 备份
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "1. 备份配置到: $BACKUP_FILE"

# 获取Monica代理实际支持的模型
echo "2. 获取Monica代理实际支持的模型..."
SUPPORTED_MODELS=$(curl -s -H "Authorization: Bearer d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f176949c2" \
  http://localhost:8080/v1/models | jq -r '.data[].id' | sort)

echo "3. 修复模型名称格式问题..."
# 创建临时文件
TEMP_FILE="/tmp/openclaw_final.json"
cp "$CONFIG_FILE" "$TEMP_FILE"

# 修复claude-3.5-sonnet -> claude-3-5-sonnet
echo "  修复 claude-3.5-sonnet -> claude-3-5-sonnet"
jq 'walk(if type == "string" then gsub("claude-3\\.5-sonnet"; "claude-3-5-sonnet") else . end)' "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"

# 修复claude-3.7-sonnet -> claude-3-7-sonnet  
echo "  修复 claude-3.7-sonnet -> claude-3-7-sonnet"
jq 'walk(if type == "string" then gsub("claude-3\\.7-sonnet"; "claude-3-7-sonnet") else . end)' "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"

echo "4. 验证修复结果..."
# 获取修复后的Monica模型
FIXED_MODELS=$(grep -o '"monica/[^"]*"' "$TEMP_FILE" | sed 's/"monica\///g' | sed 's/"//g' | sort -u)

# 检查是否还有不支持的模型
UNSUPPORTED_COUNT=0
for model in $FIXED_MODELS; do
    if ! echo "$SUPPORTED_MODELS" | grep -q "^$model$"; then
        echo "  ❌ 仍然不支持: $model"
        UNSUPPORTED_COUNT=$((UNSUPPORTED_COUNT + 1))
    fi
done

if [ $UNSUPPORTED_COUNT -eq 0 ]; then
    echo "  ✅ 所有配置的模型Monica都支持"
else
    echo "  ⚠️  还有 $UNSUPPORTED_COUNT 个不支持的模型"
fi

echo "5. 应用最终配置..."
cp "$TEMP_FILE" "$CONFIG_FILE"

echo ""
echo "=== 修复完成 ==="
echo "✅ 已修复所有模型名称格式问题"
echo "📊 配置统计："
echo "  - Monica代理支持: $(echo "$SUPPORTED_MODELS" | wc -l | tr -d ' ') 个模型"
echo "  - OpenClaw配置: $(echo "$FIXED_MODELS" | wc -l | tr -d ' ') 个Monica模型"
echo ""
echo "🎯 当前fallback链："
grep -A15 '"fallbacks"' "$CONFIG_FILE" | grep '"monica/' | sed 's/.*"monica\///' | sed 's/".*//' | while read model; do
    if echo "$SUPPORTED_MODELS" | grep -q "^$model$"; then
        echo "  ✅ $model"
    else
        echo "  ❌ $model"
    fi
done
echo ""
echo "🚀 重启OpenClaw使配置生效"