#!/usr/bin/env python3
"""
修复Monica模型的流式响应配置
为所有Monica模型添加 stream: false
"""

import json
import os
import shutil
from datetime import datetime

def fix_monica_stream_config():
    """修复Monica模型配置，禁用流式响应"""
    
    config_path = os.path.expanduser("~/.openclaw/openclaw.json")
    backup_path = f"{config_path}.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    print(f"配置文件: {config_path}")
    print(f"备份文件: {backup_path}")
    
    # 创建备份
    shutil.copy2(config_path, backup_path)
    print("✅ 已创建备份")
    
    # 读取配置
    with open(config_path, 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    # 获取Monica模型配置
    agents = config.get("agents", {}).get("defaults", {})
    models_config = agents.get("models", {})
    
    # 统计Monica模型数量
    monica_models = [k for k in models_config.keys() if k.startswith("monica/")]
    print(f"找到 {len(monica_models)} 个Monica模型")
    
    # 为每个Monica模型添加 stream: false
    fixed_count = 0
    for model_name in monica_models:
        if models_config[model_name] == {}:
            # 空配置，添加 stream: false
            models_config[model_name] = {"stream": False}
            fixed_count += 1
        elif "stream" not in models_config[model_name]:
            # 已有配置但没有stream，添加 stream: false
            models_config[model_name]["stream"] = False
            fixed_count += 1
    
    print(f"✅ 已修复 {fixed_count} 个Monica模型的流式响应配置")
    
    # 保存配置
    with open(config_path, 'w', encoding='utf-8') as f:
        json.dump(config, f, ensure_ascii=False, indent=2)
    
    print("✅ 配置已保存")
    
    # 显示修复的模型示例
    print("\n修复后的模型配置示例:")
    for i, model_name in enumerate(list(monica_models)[:5]):
        print(f"  {model_name}: {models_config[model_name]}")
    
    return config

def test_config_change():
    """测试配置更改是否有效"""
    
    print("\n=== 配置更改测试 ===")
    
    config_path = os.path.expanduser("~/.openclaw/openclaw.json")
    
    with open(config_path, 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    # 检查几个Monica模型
    models_config = config.get("agents", {}).get("defaults", {}).get("models", {})
    
    test_models = ["monica/gpt-5", "monica/claude-4-sonnet", "monica/gpt-4o"]
    
    for model_name in test_models:
        if model_name in models_config:
            config_value = models_config[model_name]
            print(f"{model_name}: {config_value}")
            
            if isinstance(config_value, dict) and config_value.get("stream") is False:
                print(f"  ✅ 已正确配置 stream: false")
            else:
                print(f"  ❌ 配置不正确: {config_value}")
        else:
            print(f"{model_name}: 未找到配置")
    
    print("\n✅ 配置修复完成！")
    print("重启OpenClaw网关以使更改生效:")
    print("  openclaw gateway restart")

if __name__ == "__main__":
    fix_monica_stream_config()
    test_config_change()