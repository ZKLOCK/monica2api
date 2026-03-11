#!/bin/bash

echo "=== 详细调试 Monica 代理问题 ==="
echo "时间: $(date)"
echo "Cookie状态: 有效，剩余额度: 10,397,600"

echo -e "\n1. 检查 Monica 代理进程状态"
MONICA_PID=$(ps aux | grep "monica-proxy-wails" | grep -v grep | awk '{print $2}')
if [ -n "$MONICA_PID" ]; then
    echo "✅ Monica 代理运行中 (PID: $MONICA_PID)"
    echo "进程信息:"
    ps -p $MONICA_PID -o pid,ppid,user,%cpu,%mem,command
else
    echo "❌ Monica 代理未运行"
    exit 1
fi

echo -e "\n2. 测试 Monica API 详细请求"
BEARER_TOKEN="d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f17xxxxxx"

echo "请求详情:"
cat << EOF
URL: http://localhost:8080/v1/chat/completions
Method: POST
Headers:
  Authorization: Bearer $BEARER_TOKEN
  Content-Type: application/json
Body:
{
  "model": "claude-4-sonnet",
  "messages": [
    {
      "role": "user",
      "content": "Hello, this is a test message"
    }
  ],
  "stream": false
}
EOF

echo -e "\n发送请求..."
RESPONSE=$(curl -v -X POST "http://localhost:8080/v1/chat/completions" \
  -H "Authorization: Bearer $BEARER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-4-sonnet",
    "messages": [
      {
        "role": "user",
        "content": "Hello, this is a test message"
      }
    ],
    "stream": false
  }' 2>&1)

echo -e "\n响应详情:"
echo "$RESPONSE"

echo -e "\n3. 分析错误模式"
if echo "$RESPONSE" | grep -q '"code":2009'; then
    echo "❌ 错误码 2009: '消息内容不能为空'"
    echo "可能原因:"
    echo "  - Monica API 参数解析问题"
    echo "  - 请求格式不符合Monica期望"
    echo "  - Monica代理内部bug"
fi

echo -e "\n4. 测试不同格式的请求"
echo "测试1: 最简单的请求"
curl -s -X POST "http://localhost:8080/v1/chat/completions" \
  -H "Authorization: Bearer $BEARER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-4-sonnet","messages":[{"role":"user","content":"Test"}]}' \
  -w "状态码: %{http_code}\n" | head -5

echo -e "\n测试2: 带stream参数的请求"
curl -s -X POST "http://localhost:8080/v1/chat/completions" \
  -H "Authorization: Bearer $BEARER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-4-sonnet","messages":[{"role":"user","content":"Test"}],"stream":true}' \
  -w "状态码: %{http_code}\n" | head -5

echo -e "\n测试3: 测试其他模型"
curl -s -X POST "http://localhost:8080/v1/chat/completions" \
  -H "Authorization: Bearer $BEARER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"Test"}]}' \
  -w "状态码: %{http_code}\n" | head -5

echo -e "\n5. 检查 Monica 代理日志"
echo "查找最近的错误日志..."
# 尝试获取Monica代理的日志输出
if lsof -p $MONICA_PID 2>/dev/null | grep -q "\.log"; then
    echo "找到日志文件"
else
    echo "未找到日志文件，尝试通过strace查看系统调用"
    echo "（需要sudo权限）"
fi

echo -e "\n6. 验证 OpenClaw 配置"
echo "当前默认模型:"
openclaw models list | grep "default"

echo -e "\n7. 建议的排查步骤"
cat << EOF
1. 检查 Monica 代理代码中的错误处理
   - 查看 internal/service/chat_service.go 中的错误返回
   - 检查是否有参数验证问题

2. 验证 Monica API 的请求格式
   - 对比成功和失败的请求格式
   - 检查消息内容编码

3. 测试直接调用 Monica 原始API
   - 绕过代理，直接测试Monica服务

4. 查看 Monica 代理的调试日志
   - 启用详细日志级别
   - 检查请求处理流程

5. 检查网络和权限
   - 确保能访问 api.monica.im
   - 检查防火墙设置
EOF

echo -e "\n=== 调试完成 ==="