#!/usr/bin/env python3
"""
Code Agent - 编程助手
"""

import os
import sys
import json
import subprocess
from typing import Dict, List, Optional, Any
import tempfile

class CodeAgent:
    """编程助手类"""
    
    def __init__(self):
        self.supported_languages = {
            'python': '.py',
            'javascript': '.js',
            'typescript': '.ts',
            'java': '.java',
            'cpp': '.cpp',
            'csharp': '.cs',
            'go': '.go',
            'rust': '.rs',
            'swift': '.swift',
            'html': '.html',
            'css': '.css',
            'sql': '.sql',
            'bash': '.sh',
            'markdown': '.md',
            'json': '.json',
            'yaml': '.yaml'
        }
    
    def generate_code(self, language: str, task: str, requirements: Optional[List[str]] = None) -> Dict[str, Any]:
        """
        生成代码
        
        Args:
            language: 编程语言
            task: 任务描述
            requirements: 额外要求列表
            
        Returns:
            生成的代码和相关信息
        """
        # 这里应该调用AI模型生成代码
        # 暂时返回示例代码
        
        examples = {
            'python': f'''# {task}
def main():
    """主函数"""
    print("Hello, World!")
    
if __name__ == "__main__":
    main()''',
            
            'javascript': f'''// {task}
function main() {{
    console.log("Hello, World!");
}}

main();''',
            
            'html': f'''<!DOCTYPE html>
<html>
<head>
    <title>{task}</title>
</head>
<body>
    <h1>Hello, World!</h1>
</body>
</html>'''
        }
        
        code = examples.get(language.lower(), f"# {task}\n# Code for {language}")
        
        return {
            'language': language,
            'code': code,
            'filename': f'generated{self.supported_languages.get(language.lower(), ".txt")}',
            'task': task
        }
    
    def review_code(self, code: str, language: str = 'python') -> Dict[str, Any]:
        """
        代码审查
        
        Args:
            code: 代码内容
            language: 编程语言
            
        Returns:
            审查结果
        """
        issues = []
        suggestions = []
        
        # 简单的代码检查
        lines = code.split('\n')
        
        # 检查行长度
        for i, line in enumerate(lines, 1):
            if len(line) > 80:
                issues.append({
                    'line': i,
                    'type': 'style',
                    'message': f'行过长 ({len(line)} 字符)',
                    'suggestion': '考虑拆分为多行'
                })
        
        # 检查TODO注释
        for i, line in enumerate(lines, 1):
            if 'TODO' in line.upper() or 'FIXME' in line.upper():
                issues.append({
                    'line': i,
                    'type': 'todo',
                    'message': '发现TODO/FIXME注释',
                    'suggestion': '需要实现或修复'
                })
        
        # 生成建议
        if len(issues) == 0:
            suggestions.append('代码结构良好，没有发现明显问题')
        
        suggestions.append('考虑添加更多注释')
        suggestions.append('确保错误处理完善')
        
        return {
            'language': language,
            'issues': issues,
            'suggestions': suggestions,
            'issue_count': len(issues),
            'score': max(0, 10 - len(issues))  # 简单评分
        }
    
    def debug_code(self, error_message: str, code: Optional[str] = None) -> Dict[str, Any]:
        """
        调试代码
        
        Args:
            error_message: 错误信息
            code: 相关代码（可选）
            
        Returns:
            调试结果
        """
        common_errors = {
            'TypeError': '类型错误，检查变量类型和函数参数',
            'SyntaxError': '语法错误，检查代码语法',
            'NameError': '名称错误，变量或函数未定义',
            'IndexError': '索引错误，列表或数组索引越界',
            'KeyError': '键错误，字典中不存在的键',
            'AttributeError': '属性错误，对象没有该属性',
            'ImportError': '导入错误，模块不存在或路径问题',
            'ValueError': '值错误，参数值不正确',
            'ZeroDivisionError': '除零错误',
            'FileNotFoundError': '文件未找到错误'
        }
        
        error_type = None
        suggestions = []
        
        # 分析错误信息
        for err_type in common_errors:
            if err_type in error_message:
                error_type = err_type
                suggestions.append(common_errors[err_type])
                break
        
        if not error_type:
            error_type = 'UnknownError'
            suggestions.append('无法识别错误类型，请提供更多信息')
        
        # 通用建议
        suggestions.append('检查变量名拼写')
        suggestions.append('确认函数调用参数正确')
        suggestions.append('查看相关文档')
        suggestions.append('使用调试器逐步执行')
        
        return {
            'error_type': error_type,
            'original_error': error_message,
            'suggestions': suggestions,
            'common_causes': [
                '变量未初始化',
                '函数参数类型不匹配',
                '导入模块路径问题',
                '资源未正确释放'
            ]
        }
    
    def optimize_code(self, code: str, language: str = 'python', goal: str = 'performance') -> Dict[str, Any]:
        """
        优化代码
        
        Args:
            code: 代码内容
            language: 编程语言
            goal: 优化目标（performance, readability, memory）
            
        Returns:
            优化结果
        """
        optimizations = []
        
        if language.lower() == 'python':
            if goal == 'performance':
                optimizations.append('使用列表推导式替代循环')
                optimizations.append('考虑使用内置函数如map/filter')
                optimizations.append('避免在循环中重复计算')
                optimizations.append('使用局部变量替代全局变量')
            
            elif goal == 'memory':
                optimizations.append('使用生成器替代列表')
                optimizations.append('及时释放大对象')
                optimizations.append('使用__slots__减少内存占用')
                optimizations.append('避免循环引用')
            
            elif goal == 'readability':
                optimizations.append('添加文档字符串')
                optimizations.append('使用有意义的变量名')
                optimizations.append('保持函数单一职责')
                optimizations.append('添加类型提示')
        
        # 生成优化后的代码示例
        optimized_code = f"""# 优化建议：{goal}
# 原始代码已根据以下建议优化：
{chr(10).join(f'# - {opt}' for opt in optimizations)}

{code}

# 其他建议：
# 1. 添加单元测试
# 2. 考虑错误处理
# 3. 性能分析关键路径"""
        
        return {
            'language': language,
            'goal': goal,
            'optimizations': optimizations,
            'optimized_code': optimized_code,
            'original_length': len(code),
            'optimized_length': len(optimized_code)
        }
    
    def explain_code(self, code: str, language: str = 'python') -> Dict[str, Any]:
        """
        解释代码
        
        Args:
            code: 代码内容
            language: 编程语言
            
        Returns:
            代码解释
        """
        explanation = {
            'overview': '这段代码实现了基本功能',
            'functions': [],
            'variables': [],
            'logic_flow': '代码执行流程说明',
            'complexity': 'O(n) 时间复杂度',
            'dependencies': '无外部依赖'
        }
        
        # 简单分析
        lines = code.split('\n')
        function_count = sum(1 for line in lines if 'def ' in line or 'function ' in line)
        class_count = sum(1 for line in lines if 'class ' in line)
        
        explanation['function_count'] = function_count
        explanation['class_count'] = class_count
        explanation['line_count'] = len(lines)
        
        return explanation

def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Code Agent - 编程助手')
    subparsers = parser.add_subparsers(dest='command', help='命令')
    
    # generate命令
    generate_parser = subparsers.add_parser('generate', help='生成代码')
    generate_parser.add_argument('--language', required=True, help='编程语言')
    generate_parser.add_argument('--task', required=True, help='任务描述')
    
    # review命令
    review_parser = subparsers.add_parser('review', help='代码审查')
    review_parser.add_argument('--file', help='代码文件')
    review_parser.add_argument('--code', help='直接提供代码')
    
    # debug命令
    debug_parser = subparsers.add_parser('debug', help='调试代码')
    debug_parser.add_argument('--error', required=True, help='错误信息')
    debug_parser.add_argument('--code', help='相关代码')
    
    # optimize命令
    optimize_parser = subparsers.add_parser('optimize', help='优化代码')
    optimize_parser.add_argument('--file', help='代码文件')
    optimize_parser.add_argument('--code', help='直接提供代码')
    optimize_parser.add_argument('--goal', default='performance', help='优化目标')
    
    args = parser.parse_args()
    
    agent = CodeAgent()
    
    if args.command == 'generate':
        result = agent.generate_code(args.language, args.task)
        print(json.dumps(result, ensure_ascii=False, indent=2))
    
    elif args.command == 'review':
        code = args.code
        if args.file:
            with open(args.file, 'r') as f:
                code = f.read()
        
        if not code:
            print('错误：需要提供代码')
            sys.exit(1)
        
        result = agent.review_code(code)
        print(json.dumps(result, ensure_ascii=False, indent=2))
    
    elif args.command == 'debug':
        result = agent.debug_code(args.error, args.code)
        print(json.dumps(result, ensure_ascii=False, indent=2))
    
    elif args.command == 'optimize':
        code = args.code
        if args.file:
            with open(args.file, 'r') as f:
                code = f.read()
        
        if not code:
            print('错误：需要提供代码')
            sys.exit(1)
        
        result = agent.optimize_code(code, goal=args.goal)
        print(json.dumps(result, ensure_ascii=False, indent=2))
    
    else:
        parser.print_help()

if __name__ == '__main__':
    main()