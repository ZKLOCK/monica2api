#!/bin/bash

# 测试 OpenClaw 与 Monica 集成
echo "=== 测试 OpenClaw 与 Monica 集成 ==="
echo "时间: $(date)"

echo -e "\n步骤1: 检查 OpenClaw Gateway 状态"
if curl -s http://127.0.0.1:18789/ > /dev/null; then
    echo "✅ OpenClaw Gateway 正在运行"
else
    echo "❌ OpenClaw Gateway 未运行"
    echo "尝试启动: openclaw gateway start"
    openclaw gateway start
    sleep 2
fi

echo -e "\n步骤2: 检查 Monica 代理状态"
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "✅ Monica 代理正在运行"
else
    echo "❌ Monica 代理未运行"
    exit 1
fi

echo -e "\n步骤3: 测试 OpenClaw 调用 Monica API"
echo "模拟 OpenClaw 请求 Monica 代理..."

# 创建模拟的 OpenClaw 请求
cat > test_openclaw_request.py << 'EOF'
import requests
import json

# Monica 代理的配置
MONICA_URL = "http://localhost:8080/v1/chat/completions"
BEARER_TOKEN = "d1b9422d7b6f18b863dd212a5ea699fdf7cf9e2dcbcf5a8c4630565f176949c2"

# 模拟 OpenClaw 会发送的请求
request_data = {
    "model": "claude-4-sonnet",
    "messages": [
        {
            "role": "user",
            "content": "请告诉我你是什么模型"
        }
    ],
    "stream": False
}

headers = {
    "Authorization": f"Bearer {BEARER_TOKEN}",
    "Content-Type": "application/json"
}

print("发送请求到 Monica 代理...")
try:
    response = requests.post(MONICA_URL, headers=headers, json=request_data, timeout=30)
    
    print(f"状态码: {response.status_code}")
    print(f"响应头: {dict(response.headers)}")
    
    if response.status_code == 200:
        data = response.json()
        print("\n✅ 请求成功!")
        print(f"模型: {data.get('model')}")
        print(f"响应ID: {data.get('id')}")
        
        # 提取内容
        if data.get('choices') and len(data['choices']) > 0:
            content = data['choices'][0]['message']['content']
            print(f"内容长度: {len(content)} 字符")
            print(f"内容预览: {content[:200]}...")
            
            # 检查内容是否适合飞书
            if len(content) > 5000:
                print("⚠️  警告: 内容可能超过飞书限制")
            if '\n' in content:
                print("⚠️  注意: 内容包含换行符")
        else:
            print("❌ 响应中没有 choices 字段")
    else:
        print(f"❌ 请求失败: {response.text}")
        
except requests.exceptions.RequestException as e:
    print(f"❌ 请求异常: {e}")
except json.JSONDecodeError as e:
    print(f"❌ JSON 解析错误: {e}")
    print(f"原始响应: {response.text[:500]}")

print("\n步骤4: 验证响应格式是否适合飞书")
if response.status_code == 200:
    data = response.json()
    
    # 飞书兼容性检查
    issues = []
    
    if data.get('choices') and len(data['choices']) > 0:
        content = data['choices'][0]['message']['content']
        
        # 检查长度
        if len(content) > 5000:
            issues.append(f"内容过长 ({len(content)} > 5000)")
        
        # 检查特殊字符
        problematic_chars = ['\x00', '\x01', '\x02', '\x03', '\x04']
        for char in problematic_chars:
            if char in content:
                issues.append(f"包含控制字符: {repr(char)}")
        
        # 检查编码
        try:
            content.encode('utf-8')
        except UnicodeEncodeError as e:
            issues.append(f"编码问题: {e}")
    
    if issues:
        print("⚠️  飞书兼容性问题:")
        for issue in issues:
            print(f"  - {issue}")
    else:
        print("✅ 响应格式适合飞书")
EOF

python3 test_openclaw_request.py

# 清理
rm -f test_openclaw_request.py

echo -e "\n=== 测试完成 ==="

echo -e "\n如果以上测试成功，但飞书仍未显示消息，可能的问题:"
echo "1. 飞书插件配置问题"
echo "2. 消息路由问题"
echo "3. 飞书API限制"
echo "4. 网络或权限问题"

echo -e "\n建议下一步:"
echo "1. 检查飞书插件日志"
echo "2. 重启 OpenClaw Gateway: openclaw gateway restart"
echo "3. 在飞书中发送简单测试消息"