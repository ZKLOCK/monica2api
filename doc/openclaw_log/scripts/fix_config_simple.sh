#!/bin/bash

echo "=== 简单修复Monica配置 ==="
echo "时间: $(date)"
echo ""

CONFIG_FILE="/Users/wlli/.openclaw/openclaw.json"
BACKUP_FILE="/Users/wlli/.openclaw/openclaw.json.backup.$(date +%Y%m%d_%H%M%S)"

# 备份
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "1. 备份到: $BACKUP_FILE"

# 创建临时文件
TEMP_FILE="/tmp/openclaw_fixed_simple.json"
cp "$CONFIG_FILE" "$TEMP_FILE"

echo "2. 更新fallback链..."
# 使用jq更新fallback链，只使用实际支持的模型
jq '.agents.defaults.model.fallbacks = [
  "monica/claude-4-sonnet",
  "monica/gpt-4o", 
  "monica/gpt-5",
  "monica/gemini-2.5-pro",
  "deepseek/deepseek-chat",
  "qwen-portal/coder-model",
  "qwen-portal/vision-model"
]' "$TEMP_FILE" > "${TEMP_FILE}.tmp" && mv "${TEMP_FILE}.tmp" "$TEMP_FILE"

echo "3. 应用配置..."
cp "$TEMP_FILE" "$CONFIG_FILE"

echo ""
echo "=== 修复完成 ==="
echo "已更新fallback链，只使用Monica代理实际支持的模型:"
echo "1. monica/claude-4-sonnet"
echo "2. monica/gpt-4o"
echo "3. monica/gpt-5"
echo "4. monica/gemini-2.5-pro"
echo "5. deepseek/deepseek-chat (非Monica，作为后备)"
echo "6. qwen-portal/coder-model (非Monica，作为后备)"
echo "7. qwen-portal/vision-model (非Monica，作为后备)"
echo ""
echo "重启OpenClaw: openclaw gateway restart"