#!/bin/bash

# 调试 Monica 代理 500 错误
echo "=== 调试 Monica 代理 500 错误 ==="
echo "时间: $(date)"

# 停止可能存在的 Monica 代理
echo -e "\n步骤1: 停止当前 Monica 代理服务"
pkill -f "monica-proxy-wails" 2>/dev/null && echo "✅ 已停止 Monica 代理" || echo "ℹ️  没有运行中的 Monica 代理"
sleep 1

# 启动 Monica 代理并捕获日志
echo -e "\n步骤2: 启动 Monica 代理并监控日志"
cd /Users/wlli/Documents/project/openclaw/monica2api

# 创建日志文件
LOG_FILE="/tmp/monica_debug_$(date +%s).log"
echo "日志文件: $LOG_FILE"

# 启动代理并重定向日志
./build/bin/monica-proxy-wails.app/Contents/MacOS/monica-proxy-wails > "$LOG_FILE" 2>&1 &
MONICA_PID=$!
echo "✅ Monica 代理已启动 (PID: $MONICA_PID)"
sleep 3

# 监控日志
echo -e "\n步骤3: 监控实时日志..."
tail -f "$LOG_FILE" &
TAIL_PID=$!

# 等待日志输出稳定
sleep 2

# 发送测试请求
echo -e "\n步骤4: 发送测试请求"
BEARER_TOKEN="d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f17xxxxxx"

echo "请求内容:"
cat << EOF
{
  "model": "claude-4-sonnet",
  "messages": [
    {
      "role": "user",
      "content": "你好"
    }
  ],
  "stream": false
}
EOF

echo -e "\n发送请求..."
RESPONSE=$(curl -s -X POST "http://localhost:8080/v1/chat/completions" \
  -H "Authorization: Bearer $BEARER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-4-sonnet","messages":[{"role":"user","content":"你好"}],"stream":false}' \
  -w "\n状态码: %{http_code}\n")

echo -e "\n响应:"
echo "$RESPONSE"

# 等待更多日志
sleep 2

# 停止监控
kill $TAIL_PID 2>/dev/null

# 分析日志
echo -e "\n步骤5: 分析错误日志"
echo "搜索错误相关日志..."
grep -A5 -B5 -i "error\|panic\|fatal\|stacktrace" "$LOG_FILE" | head -50

echo -e "\n步骤6: 检查关键日志点"
echo "1. 检查 CollectMonicaSSEToCompletion 相关日志:"
grep -i "CollectMonicaSSEToCompletion\|SSE流处理\|Monica完整响应" "$LOG_FILE" | tail -10

echo -e "\n2. 检查错误处理日志:"
grep -i "error_handler\|应用错误\|服务器内部错误" "$LOG_FILE" | tail -10

echo -e "\n3. 检查服务层日志:"
grep -i "HandleChatCompletion\|处理聊天请求\|非流式响应" "$LOG_FILE" | tail -10

# 清理
echo -e "\n步骤7: 清理"
kill $MONICA_PID 2>/dev/null && echo "✅ 已停止 Monica 代理" || echo "ℹ️  Monica 代理已停止"
rm -f "$LOG_FILE" 2>/dev/null && echo "✅ 已清理日志文件" || echo "ℹ️  日志文件已清理"

echo -e "\n=== 调试完成 ==="
echo -e "\n建议下一步:"
echo "1. 检查 Monica 代理代码中 CollectMonicaSSEToCompletion 函数的返回值处理"
echo "2. 查看是否有 JSON 序列化/反序列化问题"
echo "3. 检查响应结构是否符合 OpenAI 标准格式"