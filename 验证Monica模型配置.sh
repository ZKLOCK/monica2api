#!/bin/bash

echo "=== 验证Monica模型配置 ==="
echo "时间: $(date)"
echo ""

# 1. 获取Monica代理实际支持的模型
echo "1. 获取Monica代理实际支持的模型..."
ACTUAL_MODELS=$(curl -s -H "Authorization: Bearer d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f176949c2" \
  http://localhost:8080/v1/models | jq -r '.data[].id' | sort)

ACTUAL_COUNT=$(echo "$ACTUAL_MODELS" | wc -l | tr -d ' ')
echo "   Monica代理支持 $ACTUAL_COUNT 个模型"

# 2. 获取OpenClaw配置的Monica模型
echo "2. 获取OpenClaw配置的Monica模型..."
CONFIG_MODELS=$(grep -o '"monica/[^"]*"' /Users/wlli/.openclaw/openclaw.json | \
  sed 's/"monica\///g' | sed 's/"//g' | sort -u)

CONFIG_COUNT=$(echo "$CONFIG_MODELS" | wc -l | tr -d ' ')
echo "   OpenClaw配置了 $CONFIG_COUNT 个Monica模型"

# 3. 对比模型列表
echo ""
echo "3. 模型配置对比..."

# 找出Monica支持但OpenClaw未配置的模型
echo "   Monica支持但OpenClaw未配置的模型："
MISSING_MODELS=$(comm -13 <(echo "$CONFIG_MODELS") <(echo "$ACTUAL_MODELS"))
if [ -z "$MISSING_MODELS" ]; then
    echo "   ✅ 所有Monica支持的模型都已配置"
else
    echo "   ❌ 缺少以下模型："
    echo "$MISSING_MODELS" | while read model; do
        echo "     - $model"
    done
fi

# 找出OpenClaw配置但Monica不支持的模型
echo ""
echo "   OpenClaw配置但Monica不支持的模型："
EXTRA_MODELS=$(comm -23 <(echo "$CONFIG_MODELS") <(echo "$ACTUAL_MODELS"))
if [ -z "$EXTRA_MODELS" ]; then
    echo "   ✅ 所有配置的模型Monica都支持"
else
    echo "   ⚠️  以下配置的模型Monica不支持："
    echo "$EXTRA_MODELS" | while read model; do
        echo "     - $model"
    done
fi

# 4. 检查fallback链
echo ""
echo "4. 检查fallback链配置..."
FALLBACKS=$(grep -A15 '"fallbacks"' /Users/wlli/.openclaw/openclaw.json | \
  grep '"monica/' | sed 's/.*"monica\///' | sed 's/".*//')

echo "   Fallback链中的Monica模型："
if [ -z "$FALLBACKS" ]; then
    echo "   ⚠️  Fallback链中没有Monica模型"
else
    echo "$FALLBACKS" | while read model; do
        # 检查模型是否实际存在
        if echo "$ACTUAL_MODELS" | grep -q "^$model$"; then
            echo "     ✅ $model (支持)"
        else
            echo "     ❌ $model (不支持)"
        fi
    done
fi

# 5. 测试几个关键模型
echo ""
echo "5. 测试关键模型调用..."
TEST_MODELS="claude-4-sonnet gpt-5 gpt-4o gemini-2.5-pro grok-4"

for model in $TEST_MODELS; do
    if echo "$ACTUAL_MODELS" | grep -q "^$model$"; then
        echo -n "   测试 $model: "
        RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
          -H "Authorization: Bearer d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f176949c2" \
          -d "{\"model\": \"$model\", \"messages\": [{\"role\": \"user\", \"content\": \"test\"}], \"stream\": false}" \
          http://localhost:8080/v1/chat/completions 2>/dev/null)
        
        if echo "$RESPONSE" | grep -q "chat.completion"; then
            echo "✅ 成功"
        else
            echo "❌ 失败"
        fi
    else
        echo "   跳过 $model: ❌ 不支持"
    fi
done

echo ""
echo "=== 验证完成 ==="
echo "📊 统计："
echo "  - Monica代理支持: $ACTUAL_COUNT 个模型"
echo "  - OpenClaw配置: $CONFIG_COUNT 个模型"
echo "  - Fallback链: $(echo "$FALLBACKS" | wc -l | tr -d ' ') 个Monica模型"
echo ""
if [ -z "$MISSING_MODELS" ] && [ -z "$EXTRA_MODELS" ]; then
    echo "🎉 所有Monica模型配置正确！"
else
    echo "⚠️  需要调整模型配置"
fi