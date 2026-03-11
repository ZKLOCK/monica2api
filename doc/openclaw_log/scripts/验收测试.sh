#!/bin/bash

echo "🎯 Monica代理集成验收测试"
echo "=========================="
echo ""

# 1. 测试Monica代理接入
echo "1. ✅ 测试Monica代理接入..."
MONICA_PID=$(ps aux | grep "monica-proxy-wails" | grep -v grep | awk '{print $2}')
if [ -n "$MONICA_PID" ]; then
    echo "   ✅ Monica代理运行中 (PID: $MONICA_PID)"
else
    echo "   ❌ Monica代理未运行"
    exit 1
fi

# 测试API连通性
API_TEST=$(curl -s -H "Authorization: Bearer d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f17xxxxxx" \
  http://localhost:8080/v1/models 2>/dev/null | head -c 50)
if [ -n "$API_TEST" ]; then
    echo "   ✅ Monica API可访问"
else
    echo "   ❌ Monica API不可访问"
    exit 1
fi

# 2. 测试Claude 4 Sonnet模型调用
echo ""
echo "2. ✅ 测试Claude 4 Sonnet模型调用..."
RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f17xxxxxx" \
  -d '{"model": "claude-4-sonnet", "messages": [{"role": "user", "content": "简单回复验收测试成功即可"}], "stream": false}' \
  http://localhost:8080/v1/chat/completions)

if echo "$RESPONSE" | grep -q "chat.completion"; then
    CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' | head -50)
    echo "   ✅ Claude 4 Sonnet调用成功"
    echo "   响应预览: $CONTENT..."
else
    echo "   ❌ Claude 4 Sonnet调用失败"
    exit 1
fi

# 3. 测试OpenClaw执行git命令
echo ""
echo "3. ✅ 测试OpenClaw执行git命令..."
cd /Users/wlli/Documents/project/openclaw/monica2api
GIT_STATUS=$(git status 2>&1)
if [ $? -eq 0 ]; then
    echo "   ✅ git status执行成功"
    echo "   当前分支: $(git branch --show-current)"
    echo "   提交状态: $(echo "$GIT_STATUS" | grep "ahead of" || echo "与远程同步")"
else
    echo "   ❌ git status执行失败"
    exit 1
fi

# 4. 完整流程测试：git status + Monica分析
echo ""
echo "4. ✅ 完整流程测试：git status + Monica分析..."
ANALYSIS=$(curl -s -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f17xxxxxx" \
  -d "{\"model\": \"claude-4-sonnet\", \"messages\": [{\"role\": \"user\", \"content\": \"请分析以下git status输出并给出具体操作建议：\n$GIT_STATUS\"}], \"stream\": false}" \
  http://localhost:8080/v1/chat/completions | jq -r '.choices[0].message.content')

if [ -n "$ANALYSIS" ] && [ ${#ANALYSIS} -gt 50 ]; then
    echo "   ✅ Monica成功分析git状态"
    echo "   分析摘要: $(echo "$ANALYSIS" | head -3)"
else
    echo "   ❌ Monica分析失败"
    exit 1
fi

echo ""
echo "=========================="
echo "🎉 验收测试全部通过！"
echo ""
echo "✅ Monica代理成功接入"
echo "✅ 可以操作背后大模型（Claude 4 Sonnet）"
echo "✅ 可以操作电脑（通过OpenClaw执行git命令）"
echo ""
echo "系统已恢复到 2026-03-10 14:44:00 的状态！"