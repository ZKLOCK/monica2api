#!/bin/bash

echo "=== 配置所有Monica代理实际支持的模型 ==="
echo "时间: $(date)"
echo ""

CONFIG_FILE="/Users/wlli/.openclaw/openclaw.json"
BACKUP_FILE="/Users/wlli/.openclaw/openclaw.json.backup.$(date +%Y%m%d_%H%M%S)"

# 备份
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "1. 备份配置到: $BACKUP_FILE"

# 获取Monica代理实际支持的所有模型
echo "2. 获取Monica代理实际支持的模型..."
MODELS=$(curl -s -H "Authorization: Bearer d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f176949c2" \
  http://localhost:8080/v1/models | jq -r '.data[].id' | sort)

MODEL_COUNT=$(echo "$MODELS" | wc -l | tr -d ' ')
echo "   发现 $MODEL_COUNT 个Monica代理支持的模型"

# 创建临时文件
TEMP_FILE="/tmp/openclaw_all_models.json"
cp "$CONFIG_FILE" "$TEMP_FILE"

echo "3. 更新models.providers.monica.models数组..."
# 创建新的Monica模型数组
NEW_MONICA_MODELS="["
FIRST=true
for model in $MODELS; do
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        NEW_MONICA_MODELS="$NEW_MONICA_MODELS,"
    fi
    
    # 根据模型类型设置属性
    NEW_MONICA_MODELS="$NEW_MONICA_MODELS{
        \"id\": \"$model\",
        \"name\": \"$(echo $model | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')\",
        \"reasoning\": false,
        \"input\": [\"text\"],
        \"cost\": {
          \"input\": 0,
          \"output\": 0,
          \"cacheRead\": 0,
          \"cacheWrite\": 0
        },
        \"contextWindow\": 128000,
        \"maxTokens\": 8192
    }"
done
NEW_MONICA_MODELS="$NEW_MONICA_MODELS]"

# 使用jq更新配置文件
jq --argjson new_models "$NEW_MONICA_MODELS" '.models.providers.monica.models = $new_models' "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"

echo "4. 更新agents.defaults.models对象..."
# 首先清空现有的monica模型
jq 'del(.agents.defaults.models | to_entries[] | select(.key | startswith("monica/")))' "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"

# 添加所有Monica模型
for model in $MODELS; do
    jq --arg model "monica/$model" '.agents.defaults.models[$model] = {}' "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"
done

echo "5. 更新fallback链（选择常用模型）..."
# 选择一些常用模型作为fallback，按优先级排序
PRIORITY_MODELS="claude-4-sonnet gpt-5 gpt-4o gemini-2.5-pro claude-3-7-sonnet grok-4 deepseek-chat"

FALLBACKS="["
FIRST=true
for model in $PRIORITY_MODELS; do
    if echo "$MODELS" | grep -q "^$model$"; then
        if [ "$FIRST" = true ]; then
            FALLBACKS="$FALLBACKS\"monica/$model\""
            FIRST=false
        else
            FALLBACKS="$FALLBACKS,\"monica/$model\""
        fi
    fi
done

# 添加非Monica模型作为最后的fallback
FALLBACKS="$FALLBACKS,\"deepseek/deepseek-chat\",\"qwen-portal/coder-model\",\"qwen-portal/vision-model\"]"

jq --argjson new_fallbacks "$FALLBACKS" '.agents.defaults.model.fallbacks = $new_fallbacks' "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"

echo "6. 应用配置..."
cp "$TEMP_FILE" "$CONFIG_FILE"

echo ""
echo "=== 配置完成 ==="
echo "✅ 已配置所有 $MODEL_COUNT 个Monica代理实际支持的模型"
echo ""
echo "📋 配置的模型列表："
echo "$MODELS" | while read model; do
    echo "  - monica/$model"
done
echo ""
echo "🎯 Fallback链（按优先级）："
echo "$PRIORITY_MODELS" | while read model; do
    if echo "$MODELS" | grep -q "^$model$"; then
        echo "  - monica/$model"
    fi
done
echo "  - deepseek/deepseek-chat"
echo "  - qwen-portal/coder-model"
echo "  - qwen-portal/vision-model"
echo ""
echo "🚀 重启OpenClaw使配置生效"