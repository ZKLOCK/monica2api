#!/usr/bin/env python3
"""
Monica API 按天复用 conversation_id 管理器
用于OpenClaw集成，实现每天一个对话窗口
"""

import requests
import json
import os
from datetime import datetime
from typing import Optional, Dict, Any

class DailyConversationManager:
    """按天管理Monica对话窗口的类"""
    
    def __init__(self, api_key: str, base_url: str = "https://openapi.monica.im/v1"):
        """
        初始化管理器
        
        Args:
            api_key: Monica API密钥
            base_url: Monica API基础URL
        """
        self.api_key = api_key
        self.base_url = base_url
        self.store_file = os.path.expanduser("~/.openclaw/monica_conversations.json")
        
        # 确保存储目录存在
        os.makedirs(os.path.dirname(self.store_file), exist_ok=True)
    
    def _load_store(self) -> Dict[str, str]:
        """读取本地存储的conversation_id映射"""
        if os.path.exists(self.store_file):
            try:
                with open(self.store_file, "r", encoding="utf-8") as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                return {}
        return {}
    
    def _save_store(self, store: Dict[str, str]):
        """保存conversation_id映射到本地"""
        with open(self.store_file, "w", encoding="utf-8") as f:
            json.dump(store, f, ensure_ascii=False, indent=2)
    
    def get_today_conv_id(self) -> Optional[str]:
        """获取今天已有的conversation_id，没有则返回None"""
        today = datetime.now().strftime("%Y-%m-%d")
        store = self._load_store()
        return store.get(today)
    
    def save_today_conv_id(self, conv_id: str):
        """保存今天的conversation_id"""
        today = datetime.now().strftime("%Y-%m-%d")
        store = self._load_store()
        store[today] = conv_id
        self._save_store(store)
        print(f"✅ 已保存今日对话ID [{today}]: {conv_id}")
    
    def chat(self, message: str, model: str = "claude-sonnet-4-6", stream: bool = False) -> Dict[str, Any]:
        """
        发送消息，自动管理conversation_id
        
        Args:
            message: 用户消息
            model: 模型名称
            stream: 是否使用流式响应
            
        Returns:
            Monica API响应
        """
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        conv_id = self.get_today_conv_id()
        
        payload = {
            "model": model,
            "messages": [{"role": "user", "content": message}],
            "stream": stream
        }
        
        # 今天已有对话，复用
        if conv_id:
            payload["conversation_id"] = conv_id
            print(f"♻️  复用今日对话: {conv_id}")
        else:
            print("🆕 今天还没有对话，新建中...")
        
        response = requests.post(
            f"{self.base_url}/chat/completions",
            headers=headers,
            json=payload,
            stream=stream
        )
        
        if stream:
            # 处理流式响应
            return self._handle_stream_response(response)
        else:
            # 处理普通响应
            result = response.json()
            
            # 如果是新建对话，保存返回的conversation_id
            if not conv_id:
                new_conv_id = (
                    result.get("conversation_id") or
                    result.get("id") or
                    result.get("data", {}).get("conversation_id")
                )
                if new_conv_id:
                    self.save_today_conv_id(new_conv_id)
            
            return result
    
    def _handle_stream_response(self, response) -> Dict[str, Any]:
        """处理流式响应"""
        # 这里简化处理，实际使用时需要根据流式响应格式解析
        collected_content = ""
        conversation_id = None
        
        for line in response.iter_lines():
            if line:
                line_str = line.decode('utf-8')
                if line_str.startswith("data: "):
                    data_str = line_str[6:]
                    if data_str == "[DONE]":
                        break
                    try:
                        data = json.loads(data_str)
                        if "choices" in data and data["choices"]:
                            delta = data["choices"][0].get("delta", {})
                            if "content" in delta:
                                collected_content += delta["content"]
                        
                        # 提取conversation_id
                        if not conversation_id:
                            conversation_id = data.get("conversation_id")
                    except json.JSONDecodeError:
                        continue
        
        # 保存conversation_id（如果是新建对话）
        if conversation_id and not self.get_today_conv_id():
            self.save_today_conv_id(conversation_id)
        
        return {
            "content": collected_content,
            "conversation_id": conversation_id
        }
    
    def get_conversation_history(self) -> Dict[str, str]:
        """获取所有保存的对话历史"""
        return self._load_store()
    
    def clear_old_conversations(self, days_to_keep: int = 30):
        """清理旧的对话记录"""
        store = self._load_store()
        today = datetime.now()
        
        new_store = {}
        for date_str, conv_id in store.items():
            try:
                date_obj = datetime.strptime(date_str, "%Y-%m-%d")
                days_diff = (today - date_obj).days
                if days_diff <= days_to_keep:
                    new_store[date_str] = conv_id
            except ValueError:
                # 跳过格式错误的日期
                continue
        
        self._save_store(new_store)
        print(f"✅ 已清理{len(store) - len(new_store)}条旧对话记录")


# 使用示例
if __name__ == "__main__":
    # 从环境变量获取API密钥
    api_key = os.getenv("MONICA_API_KEY", "your_monica_api_key")
    
    manager = DailyConversationManager(api_key=api_key)
    
    # 示例：当天多次调用，自动复用同一个对话窗口
    print("=== 测试多窗口管理 ===")
    
    # 第一次调用（新建对话）
    result1 = manager.chat("测试消息 1：今天天气怎么样？", model="claude-sonnet-4-6")
    if "choices" in result1:
        reply1 = result1["choices"][0]["message"]["content"]
        print(f"回复1: {reply1[:100]}...")
    
    print("---")
    
    # 第二次调用（复用对话）
    result2 = manager.chat("测试消息 2：帮我写一个冒泡排序", model="claude-sonnet-4-6")
    if "choices" in result2:
        reply2 = result2["choices"][0]["message"]["content"]
        print(f"回复2: {reply2[:100]}...")
    
    print("---")
    
    # 显示对话历史
    history = manager.get_conversation_history()
    print(f"对话历史: {json.dumps(history, ensure_ascii=False, indent=2)}")