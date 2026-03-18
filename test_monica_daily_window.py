#!/usr/bin/env python3
"""
测试Monica多窗口每天一个功能
"""

import sys
import os
import json

# 添加当前目录到Python路径
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from daily_conversation_manager import DailyConversationManager

def test_daily_conversation():
    """测试按天对话管理"""
    
    # 从OpenClaw配置中读取Monica API密钥
    config_path = os.path.expanduser("~/.openclaw/openclaw.json")
    
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
        
        # 获取Monica配置
        monica_config = config.get("models", {}).get("providers", {}).get("monica", {})
        api_key = monica_config.get("apiKey")
        base_url = monica_config.get("baseUrl", "https://openapi.monica.im/v1")
        
        if not api_key:
            print("❌ 未找到Monica API密钥")
            return
        
        print(f"✅ 找到Monica配置:")
        print(f"   API密钥: {api_key[:10]}...")
        print(f"   基础URL: {base_url}")
        
        # 创建管理器
        manager = DailyConversationManager(api_key=api_key, base_url=base_url)
        
        # 测试对话
        print("\n=== 测试对话 ===")
        
        # 第一次调用
        print("\n1. 第一次调用（应该新建对话）:")
        try:
            result = manager.chat(
                "今天是" + os.popen('date "+%Y年%m月%d日"').read().strip() + "，这是今天的测试对话。",
                model="claude-3-5-sonnet",
                stream=False
            )
            
            if "choices" in result:
                reply = result["choices"][0]["message"]["content"]
                print(f"   回复: {reply[:200]}...")
                
                # 获取conversation_id
                conv_id = result.get("conversation_id")
                if conv_id:
                    print(f"   对话ID: {conv_id}")
            else:
                print(f"   错误响应: {json.dumps(result, ensure_ascii=False, indent=2)}")
                
        except Exception as e:
            print(f"   调用失败: {e}")
        
        # 第二次调用（应该复用）
        print("\n2. 第二次调用（应该复用对话）:")
        try:
            result = manager.chat(
                "继续我们的对话，请帮我写一个Python函数来计算斐波那契数列。",
                model="claude-3-5-sonnet",
                stream=False
            )
            
            if "choices" in result:
                reply = result["choices"][0]["message"]["content"]
                print(f"   回复: {reply[:200]}...")
            else:
                print(f"   错误响应: {json.dumps(result, ensure_ascii=False, indent=2)}")
                
        except Exception as e:
            print(f"   调用失败: {e}")
        
        # 显示对话历史
        print("\n3. 对话历史:")
        history = manager.get_conversation_history()
        print(json.dumps(history, ensure_ascii=False, indent=2))
        
        # 测试流式响应
        print("\n4. 测试流式响应:")
        try:
            result = manager.chat(
                "用流式响应告诉我一个简短的笑话。",
                model="claude-3-5-sonnet",
                stream=True
            )
            
            if "content" in result:
                print(f"   流式回复: {result['content'][:200]}...")
            else:
                print(f"   流式响应结果: {json.dumps(result, ensure_ascii=False, indent=2)}")
                
        except Exception as e:
            print(f"   流式调用失败: {e}")
        
        print("\n✅ 测试完成！")
        
    except Exception as e:
        print(f"❌ 测试失败: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_daily_conversation()