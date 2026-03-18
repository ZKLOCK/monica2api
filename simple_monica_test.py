#!/usr/bin/env python3
"""
简单的Monica API测试
"""

import requests
import json
import os

def test_monica_api():
    """测试Monica API基本功能"""
    
    # 从OpenClaw配置读取
    config_path = os.path.expanduser("~/.openclaw/openclaw.json")
    
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
        
        monica_config = config.get("models", {}).get("providers", {}).get("monica", {})
        api_key = monica_config.get("apiKey")
        base_url = monica_config.get("baseUrl", "http://localhost:8080/v1")
        
        print(f"API密钥: {api_key[:20]}...")
        print(f"基础URL: {base_url}")
        
        # 测试列出模型
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
        
        print("\n1. 测试列出模型:")
        try:
            response = requests.get(f"{base_url}/models", headers=headers, timeout=10)
            print(f"   状态码: {response.status_code}")
            
            if response.status_code == 200:
                models = response.json()
                print(f"   模型数量: {len(models.get('data', []))}")
                for model in models.get('data', [])[:5]:
                    print(f"   - {model.get('id')}")
            else:
                print(f"   响应: {response.text[:200]}")
                
        except requests.exceptions.RequestException as e:
            print(f"   请求失败: {e}")
        
        # 测试简单对话
        print("\n2. 测试简单对话:")
        payload = {
            "model": "claude-3-5-sonnet",
            "messages": [{"role": "user", "content": "你好，请简单回复'测试成功'。"}],
            "stream": False
        }
        
        try:
            response = requests.post(
                f"{base_url}/chat/completions",
                headers=headers,
                json=payload,
                timeout=30
            )
            print(f"   状态码: {response.status_code}")
            
            if response.status_code == 200:
                result = response.json()
                print(f"   响应keys: {list(result.keys())}")
                
                if "choices" in result:
                    reply = result["choices"][0]["message"]["content"]
                    print(f"   回复: {reply}")
                
                # 检查是否有conversation_id
                conv_id = result.get("conversation_id")
                if conv_id:
                    print(f"   对话ID: {conv_id}")
            else:
                print(f"   错误响应: {response.text[:500]}")
                
        except requests.exceptions.RequestException as e:
            print(f"   请求失败: {e}")
        
    except Exception as e:
        print(f"配置读取失败: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_monica_api()