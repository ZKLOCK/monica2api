#!/usr/bin/env python3
"""
测试已安装的技能
"""

import os
import sys
import json
from pathlib import Path

def test_skill_structure():
    """测试技能目录结构"""
    
    skills_dir = Path.home() / '.openclaw' / 'workspace' / 'skills'
    
    print("📁 技能目录结构测试")
    print("=" * 50)
    
    expected_skills = [
        'agent-browser',
        'brave-search-exa', 
        'twitter-bird',
        'code-agent',
        'image-gen',
        'github-ai-trends',
        'cron',
        'memory',
        'monica-daily-window'
    ]
    
    all_ok = True
    
    for skill in expected_skills:
        skill_path = skills_dir / skill
        skill_md = skill_path / 'SKILL.md'
        
        if skill_path.exists():
            print(f"✅ {skill}: 目录存在")
            
            if skill_md.exists():
                print(f"   📄 SKILL.md 存在")
                
                # 检查文件大小
                size = skill_md.stat().st_size
                print(f"   文件大小: {size} 字节")
                
                # 检查是否有实现文件
                py_files = list(skill_path.glob('*.py'))
                if py_files:
                    print(f"   🐍 Python文件: {len(py_files)} 个")
                    for py_file in py_files[:3]:  # 显示前3个
                        print(f"     - {py_file.name}")
                else:
                    print(f"   ⚠️  无Python实现文件")
                    
            else:
                print(f"   ❌ SKILL.md 不存在")
                all_ok = False
                
        else:
            print(f"❌ {skill}: 目录不存在")
            all_ok = False
        
        print()
    
    return all_ok

def test_skill_functionality():
    """测试技能功能"""
    
    print("🔧 技能功能测试")
    print("=" * 50)
    
    # 测试code-agent
    print("1. 测试code-agent技能:")
    code_agent_path = Path.home() / '.openclaw' / 'workspace' / 'skills' / 'code-agent' / 'code_agent.py'
    
    if code_agent_path.exists():
        try:
            import subprocess
            result = subprocess.run(
                [sys.executable, str(code_agent_path), '--help'],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                print("   ✅ code_agent.py 可执行")
                print(f"   输出: {result.stdout[:100]}...")
            else:
                print(f"   ❌ 执行失败: {result.stderr[:100]}")
                
        except Exception as e:
            print(f"   ❌ 测试异常: {e}")
    else:
        print("   ⚠️  code_agent.py 不存在")
    
    print()
    
    # 测试memory
    print("2. 测试memory技能:")
    memory_path = Path.home() / '.openclaw' / 'workspace' / 'skills' / 'memory' / 'memory_manager.py'
    
    if memory_path.exists():
        try:
            import subprocess
            result = subprocess.run(
                [sys.executable, str(memory_path), '--help'],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                print("   ✅ memory_manager.py 可执行")
                print(f"   输出: {result.stdout[:100]}...")
            else:
                print(f"   ❌ 执行失败: {result.stderr[:100]}")
                
        except Exception as e:
            print(f"   ❌ 测试异常: {e}")
    else:
        print("   ⚠️  memory_manager.py 不存在")
    
    print()
    
    # 测试cron
    print("3. 测试cron技能:")
    cron_path = Path.home() / '.openclaw' / 'workspace' / 'skills' / 'cron' / 'cron_manager.py'
    
    if cron_path.exists():
        try:
            import subprocess
            result = subprocess.run(
                [sys.executable, str(cron_path), '--help'],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                print("   ✅ cron_manager.py 可执行")
                print(f"   输出: {result.stdout[:100]}...")
            else:
                print(f"   ❌ 执行失败: {result.stderr[:100]}")
                
        except Exception as e:
            print(f"   ❌ 测试异常: {e}")
    else:
        print("   ⚠️  cron_manager.py 不存在")
    
    print()

def check_openclaw_integration():
    """检查OpenClaw集成"""
    
    print("🔄 OpenClaw集成检查")
    print("=" * 50)
    
    # 检查OpenClaw配置
    config_path = Path.home() / '.openclaw' / 'openclaw.json'
    
    if config_path.exists():
        print("✅ OpenClaw配置文件存在")
        
        try:
            with open(config_path, 'r') as f:
                config = json.load(f)
            
            # 检查技能配置
            skills_config = config.get('skills', {})
            if skills_config:
                print(f"✅ 技能配置找到: {len(skills_config)} 个配置")
            else:
                print("⚠️  未找到技能配置")
                
        except Exception as e:
            print(f"❌ 读取配置失败: {e}")
    else:
        print("❌ OpenClaw配置文件不存在")
    
    print()
    
    # 检查网关状态
    print("检查OpenClaw网关状态:")
    try:
        import subprocess
        result = subprocess.run(
            ['openclaw', 'gateway', 'status'],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            print("✅ OpenClaw网关命令可用")
            
            # 检查是否运行
            if 'Runtime: running' in result.stdout:
                print("✅ 网关正在运行")
            else:
                print("⚠️  网关未运行")
        else:
            print(f"❌ 网关状态检查失败: {result.stderr[:100]}")
            
    except FileNotFoundError:
        print("❌ openclaw命令未找到")
    except Exception as e:
        print(f"❌ 检查异常: {e}")
    
    print()

def generate_usage_instructions():
    """生成使用说明"""
    
    print("📋 使用说明")
    print("=" * 50)
    
    instructions = """
## 已安装的技能列表：

### 1. 🤖 agent-browser - 浏览器自动化
   功能：网页导航、表单填写、数据抓取
   使用：openclaw browser [command]

### 2. 🔍 brave-search/exa - 智能搜索  
   功能：多搜索引擎聚合、智能摘要
   使用：openclaw search [command]

### 3. 🐦 twitter/bird - 社媒自动化
   功能：自动发帖、内容监控、粉丝互动
   使用：openclaw twitter [command]

### 4. 💻 code-agent - 编程助手
   功能：代码生成、审查、调试、优化
   使用：python3 skills/code-agent/code_agent.py [command]

### 5. 🎨 image-gen - 图像生成
   功能：文本到图像生成、图像编辑
   使用：openclaw image [command]

### 6. 📊 github-ai-trends - AI趋势追踪
   功能：热门项目发现、趋势分析
   使用：openclaw github [command]

### 7. ⏰ cron - 定时任务
   功能：任务调度、执行监控、日志管理
   使用：python3 skills/cron/cron_manager.py [command]

### 8. 🧠 memory - 长期记忆
   功能：记忆存储、检索、搜索、清理
   使用：python3 skills/memory/memory_manager.py [command]

### 9. 📅 monica-daily-window - Monica多窗口管理
   功能：按天管理对话窗口、对话历史
   使用：集成到Monica代理中

## 下一步操作：

1. **配置技能**：根据需要配置API密钥和设置
2. **集成到OpenClaw**：在OpenClaw配置中启用技能
3. **测试功能**：运行各个技能的测试命令
4. **创建别名**：为常用命令创建shell别名
5. **自动化工作流**：结合多个技能创建自动化流程

## 快速测试命令：

# 测试code-agent
python3 skills/code-agent/code_agent.py generate --language python --task "Hello World"

# 测试memory
python3 skills/memory/memory_manager.py save --key "test" --value "测试记忆"

# 测试cron
python3 skills/cron/cron_manager.py create --name "测试任务" --schedule "1m" --command "echo 'Hello'"
"""
    
    print(instructions)

def main():
    """主函数"""
    
    print("🎯 技能安装测试报告")
    print("=" * 50)
    print()
    
    # 测试目录结构
    structure_ok = test_skill_structure()
    
    # 测试功能
    test_skill_functionality()
    
    # 检查集成
    check_openclaw_integration()
    
    # 生成说明
    generate_usage_instructions()
    
    # 总结
    print("=" * 50)
    print("📊 测试总结")
    print("=" * 50)
    
    if structure_ok:
        print("✅ 所有技能目录结构完整")
    else:
        print("⚠️  部分技能目录结构不完整")
    
    print()
    print("🚀 技能安装完成！")
    print("现在可以开始使用这些技能来增强OpenClaw的功能了。")

if __name__ == '__main__':
    main()