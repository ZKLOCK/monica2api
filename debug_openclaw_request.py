#!/usr/bin/env python3
"""
调试OpenClaw发送给Monica的请求参数
"""

import json
import os

def analyze_openclaw_config():
    """分析OpenClaw配置"""
    
    config_path = os.path.expanduser("~/.openclaw/openclaw.json")
    
    print("=== OpenClaw配置分析 ===")
    
    with open(config_path, 'r') as f:
        config = json.load(f)
    
    # 分析模型配置
    models = config.get("models", {}).get("providers", {})
    print(f"\n1. 模型提供商: {list(models.keys())}")
    
    # Monica配置
    monica = models.get("monica", {})
    print(f"\n2. Monica配置:")
    print(f"   baseUrl: {monica.get('baseUrl')}")
    print(f"   apiKey: {monica.get('apiKey', '')[:20]}...")
    print(f"   api类型: {monica.get('api')}")
    
    # Monica模型列表
    monica_models = monica.get("models", [])
    print(f"\n3. Monica模型列表 (前10个):")
    for i, model in enumerate(monica_models[:10]):
        print(f"   {i+1}. {model.get('id')} - {model.get('name')}")
    
    # 默认模型配置
    agents = config.get("agents", {}).get("defaults", {})
    print(f"\n4. 默认模型配置:")
    print(f"   主模型: {agents.get('model', {}).get('primary')}")
    print(f"   备选模型: {agents.get('model', {}).get('fallbacks', [])[:5]}")
    
    # 检查是否有流式响应相关配置
    print(f"\n5. 流式响应配置检查:")
    
    # 检查所有模型配置
    all_models_config = agents.get("models", {})
    monica_models_config = {k: v for k, v in all_models_config.items() if k.startswith("monica/")}
    
    print(f"   Monica模型配置数量: {len(monica_models_config)}")
    
    # 检查是否有stream相关配置
    for model_name, model_config in list(monica_models_config.items())[:5]:
        print(f"   {model_name}: {model_config}")
    
    return config

def simulate_openclaw_request():
    """模拟OpenClaw发送给Monica的请求"""
    
    print("\n=== 模拟OpenClaw请求 ===")
    
    # 典型的OpenClaw请求参数
    typical_request = {
        "model": "monica/gpt-5",
        "messages": [
            {"role": "user", "content": "测试消息"}
        ],
        "temperature": 0.7,
        "max_tokens": 2000,
        "stream": True,  # OpenClaw可能默认使用流式响应
        "tools": [],  # 如果有function calling
        "tool_choice": "auto"
    }
    
    print("典型的OpenClaw请求参数:")
    print(json.dumps(typical_request, ensure_ascii=False, indent=2))
    
    # 分析可能的问题
    print("\n可能的问题分析:")
    print("1. stream: true - Monica代理可能不支持流式响应，或响应格式不兼容")
    print("2. 模型名称格式 - 'monica/gpt-5' 需要转换为Monica API认识的格式")
    print("3. 请求头 - 可能需要特定的Content-Type或Accept头")
    print("4. 超时设置 - 流式响应可能需要更长的超时时间")
    
    return typical_request

def check_monica_proxy():
    """检查Monica代理状态"""
    
    print("\n=== Monica代理检查 ===")
    
    # 检查本地代理是否运行
    import subprocess
    
    try:
        # 检查端口8080
        result = subprocess.run(
            ["lsof", "-i", ":8080"],
            capture_output=True,
            text=True
        )
        
        if result.stdout:
            print("✅ 端口8080有服务在运行:")
            print(result.stdout)
        else:
            print("❌ 端口8080没有服务在运行")
            print("   需要启动Monica代理: monica-proxy --port 8080")
            
    except Exception as e:
        print(f"检查端口失败: {e}")
    
    # 检查配置文件
    monica_config_path = os.path.expanduser("~/.monica/config.json")
    if os.path.exists(monica_config_path):
        print(f"\n✅ 找到Monica配置文件: {monica_config_path}")
        try:
            with open(monica_config_path, 'r') as f:
                monica_config = json.load(f)
                print(f"   配置keys: {list(monica_config.keys())}")
        except:
            print("   无法读取配置文件")
    else:
        print(f"\n❌ 未找到Monica配置文件: {monica_config_path}")

def recommendations():
    """提供建议"""
    
    print("\n=== 调试建议 ===")
    
    print("1. 临时禁用流式响应:")
    print("   在OpenClaw配置中，为Monica模型添加 'stream': false")
    print("   或修改请求参数，设置 stream: false")
    
    print("\n2. 检查Monica代理日志:")
    print("   tail -f ~/.monica/monica-proxy.log")
    print("   或检查OpenClaw日志: tail -f ~/.openclaw/logs/gateway.log")
    
    print("\n3. 测试直接调用Monica API:")
    print("   使用curl或Python直接测试，排除OpenClaw中间层问题")
    
    print("\n4. 验证模型名称映射:")
    print("   'monica/gpt-5' → Monica API实际接受的模型名称")
    print("   可能需要转换为 'gpt-5' 或 'openai/gpt-5'")
    
    print("\n5. 检查网络连接和代理:")
    print("   确保Monica代理可以访问外部API")
    print("   检查防火墙和网络设置")

if __name__ == "__main__":
    analyze_openclaw_config()
    simulate_openclaw_request()
    check_monica_proxy()
    recommendations()