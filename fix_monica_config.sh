#!/bin/bash

echo "=== 修复Monica代理配置 ==="
echo "时间: $(date)"
echo ""

# 备份原始配置
CONFIG_FILE="/Users/wlli/.openclaw/openclaw.json"
BACKUP_FILE="/Users/wlli/.openclaw/openclaw.json.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "1. 已备份原始配置到: $BACKUP_FILE"

# 获取Monica代理实际支持的模型
echo "2. 获取Monica代理实际支持的模型..."
MONICA_MODELS=$(curl -s -H "Authorization: Bearer d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f176949c2" http://localhost:8080/v1/models | jq -r '.data[].id' | sort)

# 创建临时配置文件
TEMP_FILE="/tmp/openclaw_fixed.json"
cp "$CONFIG_FILE" "$TEMP_FILE"

echo "3. 更新Monica模型配置..."

# 首先，我们需要更新models.providers.monica.models数组
# 这是一个复杂的JSON操作，我们使用jq来处理

# 创建新的Monica模型数组
NEW_MONICA_MODELS="["
FIRST=true
for model in $MONICA_MODELS; do
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        NEW_MONICA_MODELS="$NEW_MONICA_MODELS,"
    fi
    
    # 根据模型类型设置不同的属性
    if [[ "$model" == *"claude"* ]] || [[ "$model" == *"gpt"* ]] || [[ "$model" == *"gemini"* ]] || [[ "$model" == *"deepseek"* ]]; then
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
    else
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
    fi
done
NEW_MONICA_MODELS="$NEW_MONICA_MODELS]"

# 使用jq更新配置文件
echo "4. 使用jq更新配置文件..."
jq --argjson new_models "$NEW_MONICA_MODELS" '.models.providers.monica.models = $new_models' "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"

# 更新agents.defaults.models对象
echo "5. 更新agents.defaults.models..."
# 首先清空现有的monica模型
jq 'del(.agents.defaults.models | to_entries[] | select(.key | startswith("monica/")))' "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"

# 添加新的monica模型
for model in $MONICA_MODELS; do
    jq --arg model "monica/$model" '.agents.defaults.models[$model] = {}' "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"
done

# 更新fallback链，只使用实际支持的模型
echo "6. 更新fallback链..."
# 创建新的fallback数组，只包含实际支持的模型
SUPPORTED_FALLBACKS="[]"
# 我们可以选择一些常用的模型作为fallback
PRIORITY_MODELS="claude-4-sonnet gpt-4o gpt-5 gemini-2.5-pro deepseek-chat"
for model in $PRIORITY_MODELS; do
    if echo "$MONICA_MODELS" | grep -q "^$model$"; then
        if [ "$SUPPORTED_FALLBACKS" = "[]" ]; then
            SUPPORTED_FALLBACKS="[\"monica/$model\"]"
        else
            SUPPORTED_FALLBACKS=$(echo "$SUPPORTED_FALLBACKS" | sed "s/\]/,\"monica\/$model\"]/")
        fi
    fi
done

# 添加非Monica模型作为最后的fallback
SUPPORTED_FALLBACKS=$(echo "$SUPPORTED_FALLBACKS" | sed "s/\]/,\"deepseek\/deepseek-chat\",\"qwen-portal\/coder-model\",\"qwen-portal\/vision-model\"]/")

jq --argjson new_fallbacks "$SUPPORTED_FALLBACKS" '.agents.defaults.model.fallbacks = $new_fallbacks' "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"

# 应用修复后的配置
echo "7. 应用修复后的配置..."
cp "$TEMP_FILE" "$CONFIG_FILE"

echo ""
echo "=== 修复完成 ==="
echo "已更新配置: $CONFIG_FILE"
echo "备份文件: $BACKUP_FILE"
echo ""
echo "更新内容:"
echo "1. Monica模型列表已更新为实际支持的 $(echo "$MONICA_MODELS" | wc -l | tr -d ' ') 个模型"
echo "2. 移除了不支持的模型"
echo "3. 更新了fallback链"
echo ""
echo "下一步:"
echo "1. 重启OpenClaw使配置生效: openclaw gateway restart"
echo "2. 测试飞书消息: 发送消息到OpenClaw"
echo "3. 验证Monica模型调用"