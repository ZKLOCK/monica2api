#!/bin/bash

echo "=== 修改OpenClaw默认模型为monica/gpt-5 ==="
echo "时间: $(date)"
echo ""

CONFIG_FILE="/Users/wlli/.openclaw/openclaw.json"
BACKUP_FILE="/Users/wlli/.openclaw/openclaw.json.backup.$(date +%Y%m%d_%H%M%S)"

# 备份
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "1. 备份配置到: $BACKUP_FILE"

# 创建临时文件
TEMP_FILE="/tmp/openclaw_default_model.json"
cp "$CONFIG_FILE" "$TEMP_FILE"

echo "2. 修改默认模型..."
# 修改primary模型为monica/gpt-5
jq '.agents.defaults.model.primary = "monica/gpt-5"' "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"

echo "3. 更新fallback链（将gpt-5移到第一位）..."
# 获取当前的fallback链
CURRENT_FALLBACKS=$(jq -r '.agents.defaults.model.fallbacks[]' "$TEMP_FILE")

# 创建新的fallback链，将monica/gpt-5移除（因为现在是primary）
NEW_FALLBACKS="["
FIRST=true
for fb in $CURRENT_FALLBACKS; do
    if [[ "$fb" != "monica/gpt-5" ]]; then
        if [ "$FIRST" = true ]; then
            NEW_FALLBACKS="$NEW_FALLBACKS\"$fb\""
            FIRST=false
        else
            NEW_FALLBACKS="$NEW_FALLBACKS,\"$fb\""
        fi
    fi
done
NEW_FALLBACKS="$NEW_FALLBACKS]"

# 更新fallback链
jq --argjson new_fallbacks "$NEW_FALLBACKS" '.agents.defaults.model.fallbacks = $new_fallbacks' "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"

echo "4. 应用配置..."
cp "$TEMP_FILE" "$CONFIG_FILE"

echo ""
echo "=== 修改完成 ==="
echo "✅ 默认模型已修改为: monica/gpt-5"
echo ""
echo "📋 配置变更："
echo "  - 原默认模型: deepseek/deepseek-chat"
echo "  - 新默认模型: monica/gpt-5"
echo ""
echo "🎯 更新后的fallback链："
jq -r '.agents.defaults.model.fallbacks[]' "$CONFIG_FILE" | while read fb; do
    echo "  - $fb"
done
echo ""
echo "🚀 重启OpenClaw使配置生效"
echo ""
echo "💡 注意：现在发送普通消息（不加/monica前缀）将默认使用GPT-5模型"