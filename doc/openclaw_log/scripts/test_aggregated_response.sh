#!/bin/bash

# 测试聚合响应格式
echo "=== 测试 Monica 代理聚合响应格式 ==="
echo "时间: $(date)"

# 停止可能存在的 Monica 代理
echo -e "\n步骤1: 停止当前 Monica 代理服务"
pkill -f "monica-proxy-wails" 2>/dev/null && echo "✅ 已停止 Monica 代理" || echo "ℹ️  没有运行中的 Monica 代理"

# 启动 Monica 代理
echo -e "\n步骤2: 启动 Monica 代理"
cd /Users/wlli/Documents/project/openclaw/monica2api
./build/bin/monica-proxy-wails.app/Contents/MacOS/monica-proxy-wails &
MONICA_PID=$!
echo "✅ Monica 代理已启动 (PID: $MONICA_PID)"
sleep 3

# 测试非流式请求
echo -e "\n步骤3: 测试非流式请求 (stream: false)"
BEARER_TOKEN="d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f176949c2"

echo "请求:"
echo 'curl -X POST "http://localhost:8080/v1/chat/completions" \'
echo '  -H "Authorization: Bearer $BEARER_TOKEN" \'
echo '  -d '\''{"model":"claude-4-sonnet","messages":[{"role":"user","content":"你好，请回复一个简短的回答"}],"stream":false}'\'''

echo -e "\n响应:"
curl -X POST "http://localhost:8080/v1/chat/completions" \
  -H "Authorization: Bearer $BEARER_TOKEN" \
  -d '{"model":"claude-4-sonnet","messages":[{"role":"user","content":"你好，请回复一个简短的回答"}],"stream":false}' \
  -w "\n状态码: %{http_code}\n响应时间: %{time_total}s\n"

# 测试响应格式验证
echo -e "\n步骤4: 验证响应格式"
echo "检查响应是否为有效 JSON 格式..."
curl -s -X POST "http://localhost:8080/v1/chat/completions" \
  -H "Authorization: Bearer $BEARER_TOKEN" \
  -d '{"model":"claude-4-sonnet","messages":[{"role":"user","content":"你好"}],"stream":false}' \
  | python3 -c "
import sys, json
try:
    data = sys.stdin.read()
    if not data:
        print('❌ 响应为空')
        sys.exit(1)
    
    parsed = json.loads(data)
    
    # 检查必需字段
    required_fields = ['id', 'object', 'model', 'choices']
    missing = [f for f in required_fields if f not in parsed]
    if missing:
        print(f'❌ 缺少必需字段: {missing}')
        sys.exit(1)
    
    # 检查 choices 结构
    if not isinstance(parsed['choices'], list) or len(parsed['choices']) == 0:
        print('❌ choices 字段无效')
        sys.exit(1)
    
    choice = parsed['choices'][0]
    if 'message' not in choice or 'content' not in choice['message']:
        print('❌ message.content 字段无效')
        sys.exit(1)
    
    content = choice['message']['content']
    print(f'✅ 响应格式正确')
    print(f'   ID: {parsed[\"id\"]}')
    print(f'   模型: {parsed[\"model\"]}')
    print(f'   内容长度: {len(content)} 字符')
    print(f'   内容预览: {content[:100] if len(content) > 100 else content}')
    
except json.JSONDecodeError as e:
    print(f'❌ JSON 解析错误: {e}')
    print(f'   原始响应: {data[:200]}...')
    sys.exit(1)
except Exception as e:
    print(f'❌ 验证错误: {e}')
    sys.exit(1)
"

# 清理
echo -e "\n步骤5: 清理"
kill $MONICA_PID 2>/dev/null && echo "✅ 已停止 Monica 代理" || echo "ℹ️  Monica 代理已停止"

echo -e "\n=== 测试完成 ==="