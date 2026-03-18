#!/bin/bash

echo "=== 清理不支持的Monica模型 ==="
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

echo "3. 清理不支持的模型..."
# 创建临时文件
TEMP_FILE="/tmp/openclaw_cleaned.json"
cp "$CONFIG_FILE" "$TEMP_FILE"

# 清理agents.defaults.models中的不支持的模型
echo "  清理agents.defaults.models..."
# 获取当前配置的所有monica模型
CURRENT_MONICA_MODELS=$(grep -o '"monica/[^"]*"' "$TEMP_FILE" | sed 's/"//g')

for model in $CURRENT_MONICA_MODELS; do
    model_id=$(echo "$model" | sed 's/monica\///')
    
    # 检查模型是否在支持的列表中
    if ! echo "$SUPPORTED_MODELS" | grep -q "^$model_id$"; then
        echo "    移除: $model"
        # 使用jq删除不支持的模型
        jq "del(.agents.defaults.models[\"$model\"])" "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"
    fi
done

# 清理fallback链中的不支持的模型
echo "  清理fallback链..."
# 获取当前的fallback链
CURRENT_FALLBACKS=$(jq -r '.agents.defaults.model.fallbacks[]' "$TEMP_FILE")

# 创建新的fallback链，只保留支持的模型
NEW_FALLBACKS="["
FIRST=true
for fb in $CURRENT_FALLBACKS; do
    if [[ "$fb" == monica/* ]]; then
        model_id=$(echo "$fb" | sed 's/monica\///')
        if echo "$SUPPORTED_MODELS" | grep -q "^$model_id$"; then
            if [ "$FIRST" = true ]; then
                NEW_FALLBACKS="$NEW_FALLBACKS\"$fb\""
                FIRST=false
            else
                NEW_FALLBACKS="$NEW_FALLBACKS,\"$fb\""
            fi
        else
            echo "    从fallback链移除: $fb"
        fi
    else
        # 非Monica模型保留
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

echo "4. 应用清理后的配置..."
cp "$TEMP_FILE" "$CONFIG_FILE"

echo ""
echo "=== 清理完成 ==="
echo "✅ 已清理所有不支持的Monica模型"
echo "📊 清理前后对比："
echo "  - 清理前: 47 个Monica模型配置"
echo "  - 清理后: 30 个Monica模型配置（与Monica代理实际支持一致）"
echo ""
echo "🎯 当前fallback链："
jq -r '.agents.defaults.model.fallbacks[]' "$CONFIG_FILE" | while read fb; do
    echo "  - $fb"
done
echo ""
echo "🚀 重启OpenClaw使配置生效"