#!/usr/bin/env python3
"""
Memory Manager - 长期记忆管理
"""

import os
import json
import pickle
from datetime import datetime
from typing import Dict, List, Optional, Any
from pathlib import Path

class MemoryManager:
    """记忆管理器"""
    
    def __init__(self, base_dir: Optional[str] = None):
        """
        初始化记忆管理器
        
        Args:
            base_dir: 记忆存储基础目录
        """
        if base_dir is None:
            base_dir = os.path.expanduser('~/.openclaw/memory')
        
        self.base_dir = Path(base_dir)
        self.long_term_dir = self.base_dir / 'long-term'
        self.short_term_dir = self.base_dir / 'short-term'
        self.working_dir = self.base_dir / 'working'
        
        # 创建目录
        for dir_path in [self.base_dir, self.long_term_dir, self.short_term_dir, self.working_dir]:
            dir_path.mkdir(parents=True, exist_ok=True)
    
    def save(self, key: str, value: Any, memory_type: str = 'long-term', 
             tags: Optional[List[str]] = None, metadata: Optional[Dict] = None) -> Dict[str, Any]:
        """
        保存记忆
        
        Args:
            key: 记忆键
            value: 记忆值
            memory_type: 记忆类型（long-term, short-term, working）
            tags: 标签列表
            metadata: 元数据
            
        Returns:
            保存结果
        """
        # 确定存储目录
        if memory_type == 'long-term':
            storage_dir = self.long_term_dir
        elif memory_type == 'short-term':
            storage_dir = self.short_term_dir
        else:  # working
            storage_dir = self.working_dir
        
        # 创建记忆对象
        memory = {
            'key': key,
            'value': value,
            'type': memory_type,
            'tags': tags or [],
            'metadata': metadata or {},
            'created_at': datetime.now().isoformat(),
            'updated_at': datetime.now().isoformat(),
            'access_count': 0
        }
        
        # 保存到文件
        file_path = storage_dir / f'{key}.json'
        
        try:
            # 尝试JSON序列化
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(memory, f, ensure_ascii=False, indent=2)
        except (TypeError, ValueError):
            # 如果JSON失败，使用pickle
            file_path = storage_dir / f'{key}.pkl'
            with open(file_path, 'wb') as f:
                pickle.dump(memory, f)
        
        return {
            'success': True,
            'key': key,
            'file_path': str(file_path),
            'memory_type': memory_type,
            'size': os.path.getsize(file_path) if os.path.exists(file_path) else 0
        }
    
    def get(self, key: str, memory_type: Optional[str] = None) -> Optional[Dict[str, Any]]:
        """
        获取记忆
        
        Args:
            key: 记忆键
            memory_type: 记忆类型（可选，如果为None则搜索所有类型）
            
        Returns:
            记忆对象或None
        """
        # 确定搜索目录
        if memory_type:
            if memory_type == 'long-term':
                search_dirs = [self.long_term_dir]
            elif memory_type == 'short-term':
                search_dirs = [self.short_term_dir]
            else:  # working
                search_dirs = [self.working_dir]
        else:
            # 搜索所有目录
            search_dirs = [self.long_term_dir, self.short_term_dir, self.working_dir]
        
        for storage_dir in search_dirs:
            # 尝试JSON文件
            json_path = storage_dir / f'{key}.json'
            if json_path.exists():
                try:
                    with open(json_path, 'r', encoding='utf-8') as f:
                        memory = json.load(f)
                    
                    # 更新访问信息
                    memory['access_count'] = memory.get('access_count', 0) + 1
                    memory['last_accessed'] = datetime.now().isoformat()
                    
                    with open(json_path, 'w', encoding='utf-8') as f:
                        json.dump(memory, f, ensure_ascii=False, indent=2)
                    
                    return memory
                except (json.JSONDecodeError, IOError):
                    pass
            
            # 尝试pickle文件
            pkl_path = storage_dir / f'{key}.pkl'
            if pkl_path.exists():
                try:
                    with open(pkl_path, 'rb') as f:
                        memory = pickle.load(f)
                    
                    # 更新访问信息
                    memory['access_count'] = memory.get('access_count', 0) + 1
                    memory['last_accessed'] = datetime.now().isoformat()
                    
                    with open(pkl_path, 'wb') as f:
                        pickle.dump(memory, f)
                    
                    return memory
                except (pickle.PickleError, IOError):
                    pass
        
        return None
    
    def search(self, query: str, memory_type: Optional[str] = None, 
               tags: Optional[List[str]] = None) -> List[Dict[str, Any]]:
        """
        搜索记忆
        
        Args:
            query: 搜索查询
            memory_type: 记忆类型过滤
            tags: 标签过滤
            
        Returns:
            匹配的记忆列表
        """
        results = []
        
        # 确定搜索目录
        if memory_type:
            if memory_type == 'long-term':
                search_dirs = [self.long_term_dir]
            elif memory_type == 'short-term':
                search_dirs = [self.short_term_dir]
            else:  # working
                search_dirs = [self.working_dir]
        else:
            search_dirs = [self.long_term_dir, self.short_term_dir, self.working_dir]
        
        for storage_dir in search_dirs:
            for file_path in storage_dir.glob('*.*'):
                try:
                    if file_path.suffix == '.json':
                        with open(file_path, 'r', encoding='utf-8') as f:
                            memory = json.load(f)
                    elif file_path.suffix == '.pkl':
                        with open(file_path, 'rb') as f:
                            memory = pickle.load(f)
                    else:
                        continue
                    
                    # 检查是否匹配查询
                    matches = False
                    
                    # 检查键
                    if query.lower() in memory.get('key', '').lower():
                        matches = True
                    
                    # 检查值（如果是字符串）
                    value = memory.get('value', '')
                    if isinstance(value, str) and query.lower() in value.lower():
                        matches = True
                    
                    # 检查标签
                    if tags:
                        memory_tags = memory.get('tags', [])
                        if not any(tag in memory_tags for tag in tags):
                            matches = False
                    
                    if matches:
                        results.append(memory)
                        
                except (json.JSONDecodeError, pickle.PickleError, IOError):
                    continue
        
        # 按访问次数排序（最近访问的在前）
        results.sort(key=lambda x: x.get('access_count', 0), reverse=True)
        
        return results
    
    def list_all(self, memory_type: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        列出所有记忆
        
        Args:
            memory_type: 记忆类型过滤
            
        Returns:
            记忆列表
        """
        memories = []
        
        # 确定搜索目录
        if memory_type:
            if memory_type == 'long-term':
                search_dirs = [self.long_term_dir]
            elif memory_type == 'short-term':
                search_dirs = [self.short_term_dir]
            else:  # working
                search_dirs = [self.working_dir]
        else:
            search_dirs = [self.long_term_dir, self.short_term_dir, self.working_dir]
        
        for storage_dir in search_dirs:
            for file_path in storage_dir.glob('*.*'):
                try:
                    if file_path.suffix == '.json':
                        with open(file_path, 'r', encoding='utf-8') as f:
                            memory = json.load(f)
                    elif file_path.suffix == '.pkl':
                        with open(file_path, 'rb') as f:
                            memory = pickle.load(f)
                    else:
                        continue
                    
                    # 添加文件信息
                    memory['file_path'] = str(file_path)
                    memory['file_size'] = os.path.getsize(file_path)
                    memory['file_modified'] = datetime.fromtimestamp(
                        os.path.getmtime(file_path)
                    ).isoformat()
                    
                    memories.append(memory)
                        
                except (json.JSONDecodeError, pickle.PickleError, IOError):
                    continue
        
        return memories
    
    def delete(self, key: str, memory_type: Optional[str] = None) -> bool:
        """
        删除记忆
        
        Args:
            key: 记忆键
            memory_type: 记忆类型
            
        Returns:
            是否成功删除
        """
        # 确定搜索目录
        if memory_type:
            if memory_type == 'long-term':
                search_dirs = [self.long_term_dir]
            elif memory_type == 'short-term':
                search_dirs = [self.short_term_dir]
            else:  # working
                search_dirs = [self.working_dir]
        else:
            search_dirs = [self.long_term_dir, self.short_term_dir, self.working_dir]
        
        for storage_dir in search_dirs:
            # 尝试删除JSON文件
            json_path = storage_dir / f'{key}.json'
            if json_path.exists():
                try:
                    os.remove(json_path)
                    return True
                except OSError:
                    pass
            
            # 尝试删除pickle文件
            pkl_path = storage_dir / f'{key}.pkl'
            if pkl_path.exists():
                try:
                    os.remove(pkl_path)
                    return True
                except OSError:
                    pass
        
        return False
    
    def cleanup(self, days_old: int = 30, memory_type: Optional[str] = None) -> Dict[str, Any]:
        """
        清理旧记忆
        
        Args:
            days_old: 保留天数
            memory_type: 记忆类型
            
        Returns:
            清理结果
        """
        cutoff_date = datetime.now().timestamp() - (days_old * 24 * 60 * 60)
        deleted_count = 0
        total_size_freed = 0
        
        # 确定搜索目录
        if memory_type:
            if memory_type == 'long-term':
                search_dirs = [self.long_term_dir]
            elif memory_type == 'short-term':
                search_dirs = [self.short_term_dir]
            else:  # working
                search_dirs = [self.working_dir]
        else:
            search_dirs = [self.long_term_dir, self.short_term_dir, self.working_dir]
        
        for storage_dir in search_dirs:
            for file_path in storage_dir.glob('*.*'):
                try:
                    file_mtime = os.path.getmtime(file_path)
                    
                    if file_mtime < cutoff_date:
                        file_size = os.path.getsize(file_path)
                        os.remove(file_path)
                        deleted_count += 1
                        total_size_freed += file_size
                        
                except OSError:
                    continue
        
        return {
            'deleted_count': deleted_count,
            'total_size_freed': total_size_freed,
            'cutoff_date': datetime.fromtimestamp(cutoff_date).isoformat(),
            'memory_type': memory_type or 'all'
        }
    
    def stats(self) -> Dict[str, Any]:
        """
        获取记忆统计信息
        
        Returns:
            统计信息
        """
        stats = {
            'total_memories': 0,
            'long_term_count': 0,
            'short_term_count': 0,
            'working_count': 0,
            'total_size': 0,
            'by_type': {}
        }
        
        for memory_type, storage_dir in [
            ('long-term', self.long_term_dir),
            ('short-term', self.short_term_dir),
            ('working', self.working_dir)
        ]:
            type_stats = {
                'count': 0,
                'size': 0,
                'oldest': None,
                'newest': None
            }
            
            oldest_time = float('inf')
            newest_time = 0
            
            for file_path in storage_dir.glob('*.*'):
                try:
                    file_size = os.path.getsize(file_path)
                    file_mtime = os.path.getmtime(file_path)
                    
                    type_stats['count'] += 1
                    type_stats['size'] += file_size
                    
                    if file_mtime < oldest_time:
                        oldest_time = file_mtime
                        type_stats['oldest'] = datetime.fromtimestamp(file_mtime).isoformat()
                    
                    if file_mtime > newest_time:
                        newest_time = file_mtime
                        type_stats['newest'] = datetime.fromtimestamp(file_mtime).isoformat()
                        
                except OSError:
                    continue
            
            stats['total_memories'] += type_stats['count']
            stats['total_size'] += type_stats['size']
            stats['by_type'][memory_type] = type_stats
            
            # 设置类型特定计数
            if memory_type == 'long-term':
                stats['long_term_count'] = type_stats['count']
            elif memory_type == 'short-term':
                stats['short_term_count'] = type_stats['count']
            else:  # working
                stats['working_count'] = type_stats['count']
        
        return stats

def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Memory Manager - 长期记忆管理')
    subparsers = parser.add_subparsers(dest='command', help='命令')
    
    # save命令
    save_parser = subparsers.add_parser('save', help='保存记忆')
    save_parser.add_argument('--key', required=True, help='记忆键')
    save_parser.add_argument('--value', required=True, help='记忆值')
    save_parser.add_argument('--type', default='long-term', help='记忆类型')
    save_parser.add_argument('--tags', help='标签（逗号分隔）')
    
    # get命令
    get_parser = subparsers.add_parser('get', help='获取记忆')
    get_parser.add_argument('--key', required=True, help='记忆键')
    get_parser.add_argument('--type', help='记忆类型')
    
    # search命令
    search_parser = subparsers.add_parser('search', help='搜索记忆')
    search_parser.add_argument('--query', required=True, help='搜索查询')
    search_parser.add_argument('--type', help='记忆类型')
    search_parser.add_argument('--tags', help='标签（逗号分隔）')
    
    # list命令
    list_parser = subparsers.add_parser('list', help='列出所有记忆')
    list_parser.add_argument('--type', help='记忆类型')
    
    # delete命令
    delete_parser = subparsers.add_parser('delete', help='删除记忆')
    delete_parser.add_argument('--key', required=True, help='记忆键')
    delete_parser.add_argument('--type', help='记忆类型')
    
    # cleanup命令
    cleanup_parser = subparsers.add_parser('cleanup', help='清理旧记忆')
    cleanup_parser.add_argument('--days', type=int, default=30, help='保留天数')
    cleanup_parser.add_argument('--type', help='记忆类型')
    
    # stats命令
    stats_parser = subparsers.add_parser('stats', help='获取统计信息')
    
    args = parser.parse_args()
    
    manager = MemoryManager()
    
    if args.command == 'save':
        tags = args.tags.split(',') if args.tags else None
        result = manager.save(args.key, args.value, args.type, tags)
        print(json.dumps(result, ensure_ascii=False, indent=2))
    
    elif args.command == 'get':
        memory = manager.get(args.key, args.type)
        if memory:
            print(json.dumps(memory, ensure_ascii=False, indent=2))
        else:
            print('未找到记忆')
    
    elif args.command == 'search':
        tags = args.tags.split(',') if args.tags else None
        results = manager.search(args.query, args.type, tags)
        print(json.dumps(results, ensure_ascii=False, indent=2))
    
    elif args.command == 'list':
        memories = manager.list_all(args.type)
        print(json.dumps(memories, ensure_ascii=False, indent=2))
    
    elif args.command == 'delete':
        success = manager.delete(args.key, args.type)
        print(json.dumps({'success': success, 'key': args.key}, ensure_ascii=False, indent=2))
    
    elif args.command == 'cleanup':
        result = manager.cleanup(args.days, args.type)
        print(json.dumps(result, ensure_ascii=False, indent=2))
    
    elif args.command == 'stats':
        stats = manager.stats()
        print(json.dumps(stats, ensure_ascii=False, indent=2))
    
    else:
        parser.print_help()

if __name__ == '__main__':
    main()