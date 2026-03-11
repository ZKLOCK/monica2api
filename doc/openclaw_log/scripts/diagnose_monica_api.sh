#!/bin/bash
echo "=== Monica API 诊断脚本 ==="
echo "Cookie 状态: ✅ 有效 (剩余额度: 10,404,100)"
echo ""

BEARER_TOKEN="d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f17xxxxxx"
API_URL="http://localhost:8080/v1/chat/completions"

echo "测试1: 简化请求 (非流式)"
echo "----------------------------------------"
TEST1='{"model":"claude-4-sonnet","messages":[{"role":"user","content":"Hello"}]}'
echo "请求: $TEST1"
curl -s -X POST "$API_URL" \
  -H "Authorization: Bearer $BEARER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$TEST1"
echo ""
echo ""

echo "测试2: 之前成功的 exact 请求 (流式)"
echo "----------------------------------------"
TEST2='{"model":"claude-4-sonnet","messages":[{"role":"system","content":"你是一个有帮助的助手"},{"role":"user","content":"github start最多排名第一的项目是什么"}],"stream":true}'
echo "请求: $TEST2"
curl -N --max-time 10 -X POST "$API_URL" \
  -H "Authorization: Bearer $BEARER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$TEST2" 2>/dev/null | head -5 || echo "请求失败"
echo ""
echo ""

echo "测试3: 测试 gpt-4o 模型"
echo "----------------------------------------"
TEST3='{"model":"gpt-4o","messages":[{"role":"user","content":"Hello"}]}'
echo "请求: $TEST3"
curl -s -X POST "$API_URL" \
  -H "Authorization: Bearer $BEARER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$TEST3"
echo ""
echo ""

echo "测试4: 测试 gemini-pro 模型"
echo "----------------------------------------"
TEST4='{"model":"gemini-pro","messages":[{"role":"user","content":"Hello"}]}'
echo "请求: $TEST4"
curl -s -X POST "$API_URL" \
  -H "Authorization: Bearer $BEARER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$TEST4"
echo ""
echo ""

echo "测试5: 获取模型列表"
echo "----------------------------------------"
curl -s -X GET "http://localhost:8080/v1/models" \
  -H "Authorization: Bearer $BEARER_TOKEN" | head -100
echo ""
echo ""

echo "=== 分析建议 ==="
echo ""
echo "如果所有测试都失败 (错误 2009):"
echo "1. Monica 代理可能有 bug"
echo "2. 尝试重启 Monica 代理服务"
echo "3. 检查 Monica 代理日志"
echo ""
echo "如果某些测试成功:"
echo "1. 使用成功的模型配置 OpenClaw"
echo "2. 更新 OpenClaw 配置中的模型"
echo "3. 测试飞书集成"
echo ""
echo "=== 重启 Monica 代理 ==="
echo "pkill -f monica-proxy-wails"
echo "cd /Users/wlli/Documents/project/openclaw/monica2api"
echo "./build/bin/monica-proxy-wails.app/Contents/MacOS/monica-proxy-wails &"
echo "sleep 5"
echo "然后在 GUI 中重新点击'启动服务'"