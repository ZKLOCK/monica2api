#!/bin/bash

echo "=== 替换异常Monica模型 ==="
echo "时间: $(date)"
echo ""

CONFIG_FILE="/Users/wlli/.openclaw/openclaw.json"
BACKUP_FILE="/Users/wlli/.openclaw/openclaw.json.backup.$(date +%Y%m%d_%H%M%S)"

# 备份
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "1. 备份配置到: $BACKUP_FILE"

# 创建临时文件
TEMP_FILE="/tmp/openclaw_replace_models.json"
cp "$CONFIG_FILE" "$TEMP_FILE"

echo "2. 定义模型替换映射..."
# 异常模型 -> 可用模型映射
declare -A MODEL_REPLACEMENTS=(
    ["grok-code-fast-1"]="grok-3-beta"      # Grok Code Fast 1 -> grok-3-beta
    ["gemini-3.1-pro"]="gemini-2.5-pro"     # Gemini 3.1 Pro -> gemini-2.5-pro
    ["grok-4"]="grok-3-beta"                # Grok 4 (有问题) -> grok-3-beta
    ["grok-3"]="grok-3-beta"                # Grok 3 -> grok-3-beta
)

echo "3. 检查并替换异常模型..."

# 首先检查fallback链中的异常模型
echo "  检查fallback链..."
FALLBACK_MODELS=$(jq -r '.agents.defaults.model.fallbacks[]' "$TEMP_FILE")

NEW_FALLBACKS="["
FIRST=true
for model in $FALLBACK_MODELS; do
    if [[ "$model" == monica/* ]]; then
        model_id=$(echo "$model" | sed 's/monica\///')
        
        # 检查是否需要替换
        if [[ -n "${MODEL_REPLACEMENTS[$model_id]}" ]]; then
            new_model="monica/${MODEL_REPLACEMENTS[$model_id]}"
            echo "    替换: $model -> $new_model"
            model="$new_model"
        fi
    fi
    
    if [ "$FIRST" = true ]; then
        NEW_FALLBACKS="$NEW_FALLBACKS\"$model\""
        FIRST=false
    else
        NEW_FALLBACKS="$NEW_FALLBACKS,\"$model\""
    fi
done
NEW_FALLBACKS="$NEW_FALLBACKS]"

# 更新fallback链
jq --argjson new_fallbacks "$NEW_FALLBACKS" '.agents.defaults.model.fallbacks = $new_fallbacks' "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"

echo "4. 清理不支持的模型配置..."
# 清理agents.defaults.models中的异常模型
for old_model in "${!MODEL_REPLACEMENTS[@]}"; do
    model_key="monica/$old_model"
    new_model="monica/${MODEL_REPLACEMENTS[$old_model]}"
    
    # 删除旧模型
    echo "    删除: $model_key"
    jq "del(.agents.defaults.models[\"$model_key\"])" "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"
    
    # 确保新模型已配置
    echo "    确保: $new_model 已配置"
    jq --arg model "$new_model" '.agents.defaults.models[$model] = {}' "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"
done

echo "5. 应用更新后的配置..."
cp "$TEMP_FILE" "$CONFIG_FILE"

echo ""
echo "=== 替换完成 ==="
echo "✅ 已替换所有异常模型"
echo ""
echo "📋 替换映射："
echo "  - grok-code-fast-1 → grok-3-beta"
echo "  - gemini-3.1-pro → gemini-2.5-pro"
echo "  - grok-4 → grok-3-beta (原模型有问题)"
echo "  - grok-3 → grok-3-beta"
echo ""
echo "🎯 更新后的fallback链："
jq -r '.agents.defaults.model.fallbacks[]' "$CONFIG_FILE" | while read fb; do
    echo "  - $fb"
done
echo ""
echo "🚀 重启OpenClaw使配置生效"