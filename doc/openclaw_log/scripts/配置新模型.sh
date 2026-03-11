#!/bin/bash

echo "=== 配置新的Monica模型 ==="
echo "时间: $(date)"
echo ""

CONFIG_FILE="/Users/wlli/.openclaw/openclaw.json"
BACKUP_FILE="/Users/wlli/.openclaw/openclaw.json.backup.$(date +%Y%m%d_%H%M%S)"

# 备份
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "1. 备份配置到: $BACKUP_FILE"

# 创建临时文件
TEMP_FILE="/tmp/openclaw_new_models.json"
cp "$CONFIG_FILE" "$TEMP_FILE"

echo "2. 获取Monica代理实际支持的模型..."
# 获取实际支持的模型
SUPPORTED_MODELS=$(curl -s -H "Authorization: Bearer d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f17xxxxxx" \
  http://localhost:8080/v1/models | jq -r '.data[].id' | sort)

echo "3. 配置用户指定的模型（映射到实际支持的模型）..."
# 用户指定的模型映射到实际支持的模型
USER_MODELS_MAP=(
  "gemini-3.1-pro:gemini-2.5-pro"
  "claude-4.6-sonnet:claude-4-sonnet"
  "gpt-5.4:gpt-5"
  "gpt-5.3-codex:gpt-5"
  "gemini-3-flash:gemini-2.0-flash"
  "grok-4:grok-4"
)

echo "4. 更新fallback链..."
# 使用jq更新fallback链，按照用户指定的顺序
jq '.agents.defaults.model.fallbacks = [
  "monica/gemini-2.5-pro",
  "monica/claude-4-sonnet",
  "monica/gpt-5",
  "monica/gemini-2.0-flash",
  "monica/grok-4",
  "deepseek/deepseek-chat",
  "qwen-portal/coder-model",
  "qwen-portal/vision-model"
]' "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"

echo "5. 添加模型到agents.defaults.models..."
# 添加用户指定的模型（使用实际支持的模型ID）
for mapping in "${USER_MODELS_MAP[@]}"; do
  user_model=$(echo "$mapping" | cut -d: -f1)
  actual_model=$(echo "$mapping" | cut -d: -f2)
  
  # 添加到models配置
  jq --arg model "monica/$user_model" '.agents.defaults.models[$model] = {}' "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"
done

echo "6. 应用配置..."
cp "$TEMP_FILE" "$CONFIG_FILE"

echo ""
echo "=== 配置完成 ==="
echo "已按照用户指定的顺序配置fallback链："
echo "1. monica/gemini-2.5-pro (映射自 Gemini 3.1 Pro)"
echo "2. monica/claude-4-sonnet (映射自 Claude 4.6 Sonnet)"
echo "3. monica/gpt-5 (映射自 GPT-5.4 和 GPT-5.3 Codex)"
echo "4. monica/gemini-2.0-flash (映射自 Gemini 3 Flash)"
echo "5. monica/grok-4"
echo "6. deepseek/deepseek-chat"
echo "7. qwen-portal/coder-model"
echo "8. qwen-portal/vision-model"
echo ""
echo "注意：部分模型名称已映射到Monica代理实际支持的模型。"
echo "重启OpenClaw使配置生效。"