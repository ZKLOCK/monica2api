#!/bin/bash

# 测试飞书插件期望的响应格式
echo "=== 测试飞书插件响应格式 ==="
echo "时间: $(date)"

# 创建模拟响应
echo -e "\n步骤1: 创建模拟的 Monica Proxy 响应"
cat > mock_response.json << 'EOF'
{
  "id": "chatcmpl-abc123def456",
  "object": "chat.completion",
  "created": 1741584000,
  "model": "claude-4-sonnet",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "你好！我是Claude，一个由Anthropic开发的AI助手。很高兴为你提供帮助！"
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 20,
    "total_tokens": 30
  }
}
EOF

echo "✅ 模拟响应创建完成"
echo "响应内容预览:"
cat mock_response.json | python3 -c "
import json, sys
data = json.load(sys.stdin)
content = data['choices'][0]['message']['content']
print(f'  内容: {content}')
print(f'  长度: {len(content)} 字符')
"

# 测试响应格式验证
echo -e "\n步骤2: 验证响应格式兼容性"
echo "检查是否包含飞书可能需要的字段..."

cat > validate_feishu_format.py << 'EOF'
import json
import sys

def validate_response(response_data):
    """验证响应格式是否适合飞书插件"""
    
    # 基本检查
    if not isinstance(response_data, dict):
        return False, "响应不是字典格式"
    
    # 必需字段
    required_fields = ['id', 'object', 'model', 'choices']
    for field in required_fields:
        if field not in response_data:
            return False, f"缺少必需字段: {field}"
    
    # 检查 choices 结构
    choices = response_data.get('choices', [])
    if not isinstance(choices, list) or len(choices) == 0:
        return False, "choices 字段无效"
    
    choice = choices[0]
    if not isinstance(choice, dict):
        return False, "choice 不是字典格式"
    
    # 检查 message 结构
    message = choice.get('message', {})
    if not isinstance(message, dict):
        return False, "message 不是字典格式"
    
    # 检查 content 字段
    content = message.get('content', '')
    if not isinstance(content, str):
        return False, "content 不是字符串格式"
    
    # 检查 content 是否为空
    if not content.strip():
        return False, "content 内容为空"
    
    # 检查特殊字符（飞书可能有限制）
    problematic_chars = ['\x00', '\x01', '\x02', '\x03', '\x04', '\x05', '\x06', '\x07',
                        '\x08', '\x0b', '\x0c', '\x0e', '\x0f', '\x10', '\x11', '\x12',
                        '\x13', '\x14', '\x15', '\x16', '\x17', '\x18', '\x19', '\x1a',
                        '\x1b', '\x1c', '\x1d', '\x1e', '\x1f']
    
    for char in problematic_chars:
        if char in content:
            return False, f"内容包含控制字符: {repr(char)}"
    
    # 检查长度（飞书可能有长度限制）
    if len(content) > 5000:
        return False, f"内容过长: {len(content)} 字符（建议 < 5000）"
    
    return True, "格式验证通过"

if __name__ == "__main__":
    try:
        with open('mock_response.json', 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        is_valid, message = validate_response(data)
        
        if is_valid:
            print(f"✅ {message}")
            print(f"   响应ID: {data['id']}")
            print(f"   模型: {data['model']}")
            print(f"   内容长度: {len(data['choices'][0]['message']['content'])} 字符")
            print(f"   内容预览: {data['choices'][0]['message']['content'][:100]}...")
        else:
            print(f"❌ {message}")
            sys.exit(1)
            
    except json.JSONDecodeError as e:
        print(f"❌ JSON 解析错误: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ 验证错误: {e}")
        sys.exit(1)
EOF

python3 validate_feishu_format.py

# 测试 HTTP 响应格式
echo -e "\n步骤3: 测试 HTTP 响应格式"
cat > test_http_response.py << 'EOF'
import http.server
import socketserver
import json
import threading
import time
import requests

# 模拟的响应数据
MOCK_RESPONSE = {
    "id": "chatcmpl-test123",
    "object": "chat.completion",
    "created": 1741584000,
    "model": "claude-4-sonnet",
    "choices": [
        {
            "index": 0,
            "message": {
                "role": "assistant",
                "content": "这是一个测试响应，用于验证飞书插件接收的格式。"
            },
            "finish_reason": "stop"
        }
    ],
    "usage": {
        "prompt_tokens": 5,
        "completion_tokens": 15,
        "total_tokens": 20
    }
}

class MockProxyServer(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/v1/chat/completions':
            # 设置响应头
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('X-Request-ID', 'test-request-123')
            self.send_header('X-Response-Time', '150ms')
            self.end_headers()
            
            # 发送响应体
            response_json = json.dumps(MOCK_RESPONSE, ensure_ascii=False)
            self.wfile.write(response_json.encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

def start_mock_server():
    with socketserver.TCPServer(("", 9999), MockProxyServer) as httpd:
        print("✅ 模拟服务器启动在端口 9999")
        httpd.serve_forever()

# 启动服务器线程
server_thread = threading.Thread(target=start_mock_server, daemon=True)
server_thread.start()
time.sleep(2)  # 等待服务器启动

# 测试客户端请求
try:
    response = requests.post(
        "http://localhost:9999/v1/chat/completions",
        headers={
            "Authorization": "Bearer test-token",
            "Content-Type": "application/json"
        },
        json={
            "model": "claude-4-sonnet",
            "messages": [{"role": "user", "content": "测试"}],
            "stream": False
        }
    )
    
    print(f"\n✅ 模拟服务器响应:")
    print(f"   状态码: {response.status_code}")
    print(f"   Content-Type: {response.headers.get('Content-Type')}")
    print(f"   X-Request-ID: {response.headers.get('X-Request-ID')}")
    
    data = response.json()
    print(f"   响应ID: {data['id']}")
    print(f"   内容: {data['choices'][0]['message']['content']}")
    
except Exception as e:
    print(f"❌ 测试失败: {e}")

print("\n✅ HTTP 响应格式测试完成")
EOF

python3 test_http_response.py

# 清理
echo -e "\n步骤4: 清理"
rm -f mock_response.json validate_feishu_format.py test_http_response.py
echo "✅ 清理完成"

echo -e "\n=== 测试完成 ==="