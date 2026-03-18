#!/bin/bash

# 构建并测试修复
echo "=== 构建并测试 Monica 代理修复 ==="
echo "时间: $(date)"

# 进入项目目录
cd /Users/wlli/Documents/project/openclaw/monica2api

echo -e "\n步骤1: 停止当前服务"
pkill -f "monica-proxy-wails" 2>/dev/null && echo "✅ 已停止 Monica 代理" || echo "ℹ️  没有运行中的 Monica 代理"
sleep 1

echo -e "\n步骤2: 重新构建项目"
echo "构建命令: go build -o ./build/bin/monica-proxy-wails.app/Contents/MacOS/monica-proxy-wails"

# 构建项目
if go build -o ./build/bin/monica-proxy-wails.app/Contents/MacOS/monica-proxy-wails; then
    echo "✅ 构建成功"
else
    echo "❌ 构建失败"
    exit 1
fi

echo -e "\n步骤3: 启动 Monica 代理"
./build/bin/monica-proxy-wails.app/Contents/MacOS/monica-proxy-wails &
MONICA_PID=$!
echo "✅ Monica 代理已启动 (PID: $MONICA_PID)"
sleep 3

echo -e "\n步骤4: 测试修复"
BEARER_TOKEN="d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f176949c2"

echo "发送测试请求..."
RESPONSE=$(curl -s -X POST "http://localhost:8080/v1/chat/completions" \
  -H "Authorization: Bearer $BEARER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-4-sonnet","messages":[{"role":"user","content":"你好"}],"stream":false}' \
  -w "\n状态码: %{http_code}")

echo -e "\n响应:"
echo "$RESPONSE"

# 验证响应格式
echo -e "\n步骤5: 验证响应格式"
if echo "$RESPONSE" | grep -q "状态码: 200"; then
    echo "✅ HTTP 状态码正确 (200)"
    
    # 提取JSON部分
    JSON_RESPONSE=$(echo "$RESPONSE" | grep -v "状态码:" | head -n -1)
    
    if echo "$JSON_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    
    # 基本验证
    required = ['id', 'object', 'model', 'choices']
    for field in required:
        if field not in data:
            print(f'❌ 缺少字段: {field}')
            sys.exit(1)
    
    # 检查choices
    if not isinstance(data['choices'], list) or len(data['choices']) == 0:
        print('❌ choices无效')
        sys.exit(1)
    
    choice = data['choices'][0]
    if 'message' not in choice or 'content' not in choice['message']:
        print('❌ message.content无效')
        sys.exit(1)
    
    content = choice['message']['content']
    print(f'✅ 响应格式正确')
    print(f'   响应ID: {data[\"id\"]}')
    print(f'   模型: {data[\"model\"]}')
    print(f'   内容长度: {len(content)}字符')
    print(f'   内容预览: {content[:100] if len(content) > 100 else content}')
    
except json.JSONDecodeError as e:
    print(f'❌ JSON解析错误: {e}')
    print(f'   原始响应: {sys.stdin.read()[:200]}')
    sys.exit(1)
except Exception as e:
    print(f'❌ 验证错误: {e}')
    sys.exit(1)
"; then
        echo "✅ 响应格式验证通过"
    else
        echo "❌ 响应格式验证失败"
    fi
else
    echo "❌ HTTP 状态码不正确"
    echo "响应详情:"
    echo "$RESPONSE"
fi

echo -e "\n步骤6: 清理"
kill $MONICA_PID 2>/dev/null && echo "✅ 已停止 Monica 代理" || echo "ℹ️  Monica 代理已停止"

echo -e "\n=== 测试完成 ==="

echo -e "\n下一步建议:"
echo "1. 如果测试成功，重启 OpenClaw Gateway"
echo "2. 在飞书中测试消息发送"
echo "3. 验证端到端集成"