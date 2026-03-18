#!/bin/bash

echo "=== 测试OpenClaw默认模型配置 ==="
echo "时间: $(date)"
echo ""

echo "1. 检查OpenClaw配置..."
PRIMARY_MODEL=$(jq -r '.agents.defaults.model.primary' /Users/wlli/.openclaw/openclaw.json)
echo "   默认模型: $PRIMARY_MODEL"

if [ "$PRIMARY_MODEL" = "monica/gpt-5" ]; then
    echo "   ✅ 默认模型已正确设置为monica/gpt-5"
else
    echo "   ❌ 默认模型设置错误"
    exit 1
fi

echo ""
echo "2. 检查Monica代理状态..."
if curl -s -H "Authorization: Bearer d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f176949c2" \
  http://localhost:8080/v1/models >/dev/null 2>&1; then
    echo "   ✅ Monica代理运行正常"
else
    echo "   ❌ Monica代理不可访问"
    exit 1
fi

echo ""
echo "3. 测试GPT-5模型调用..."
RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f176949c2" \
  -d '{"model": "gpt-5", "messages": [{"role": "user", "content": "测试默认模型"}], "stream": false}' \
  http://localhost:8080/v1/chat/completions)

if echo "$RESPONSE" | jq -e '.choices[0].message.content' >/dev/null 2>&1; then
    CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')
    echo "   ✅ GPT-5模型调用成功"
    echo "   响应: $CONTENT"
else
    echo "   ❌ GPT-5模型调用失败"
    exit 1
fi

echo ""
echo "4. 验证fallback链..."
FALLBACK_COUNT=$(jq -r '.agents.defaults.model.fallbacks | length' /Users/wlli/.openclaw/openclaw.json)
echo "   Fallback链包含 $FALLBACK_COUNT 个模型"

# 检查fallback链中是否包含关键模型
KEY_MODELS="claude-4-sonnet gpt-4o gemini-2.5-pro"
ALL_VALID=true
for model in $KEY_MODELS; do
    if jq -r '.agents.defaults.model.fallbacks[]' /Users/wlli/.openclaw/openclaw.json | grep -q "monica/$model"; then
        echo "   ✅ monica/$model 在fallback链中"
    else
        echo "   ❌ monica/$model 不在fallback链中"
        ALL_VALID=false
    fi
done

echo ""
echo "=== 测试完成 ==="
if [ "$ALL_VALID" = true ]; then
    echo "🎉 默认模型配置完全正确！"
    echo ""
    echo "📋 配置摘要："
    echo "  - 默认模型: monica/gpt-5"
    echo "  - Fallback链: $FALLBACK_COUNT 个模型"
    echo "  - Monica代理: 运行正常"
    echo "  - GPT-5模型: 调用成功"
    echo ""
    echo "🚀 现在发送普通消息将默认使用GPT-5模型"
else
    echo "⚠️  配置需要调整"
fi