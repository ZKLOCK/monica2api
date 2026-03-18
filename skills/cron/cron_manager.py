#!/usr/bin/env python3
"""
Cron Manager - 定时任务管理
"""

import os
import json
import yaml
import schedule
import time
import threading
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Callable
from pathlib import Path
import subprocess
import sys

class CronManager:
    """定时任务管理器"""
    
    def __init__(self, config_dir: Optional[str] = None):
        """
        初始化定时任务管理器
        
        Args:
            config_dir: 配置目录
        """
        if config_dir is None:
            config_dir = os.path.expanduser('~/.openclaw/cron')
        
        self.config_dir = Path(config_dir)
        self.jobs_file = self.config_dir / 'jobs.json'
        self.logs_dir = self.config_dir / 'logs'
        
        # 创建目录
        self.config_dir.mkdir(parents=True, exist_ok=True)
        self.logs_dir.mkdir(parents=True, exist_ok=True)
        
        # 加载任务
        self.jobs = self._load_jobs()
        self.running_jobs = {}
        self.scheduler_thread = None
        self.stop_scheduler = False
    
    def _load_jobs(self) -> Dict[str, Dict[str, Any]]:
        """加载任务配置"""
        if self.jobs_file.exists():
            try:
                with open(self.jobs_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                return {}
        return {}
    
    def _save_jobs(self):
        """保存任务配置"""
        with open(self.jobs_file, 'w', encoding='utf-8') as f:
            json.dump(self.jobs, f, ensure_ascii=False, indent=2)
    
    def _log_execution(self, job_id: str, success: bool, output: str = '', error: str = ''):
        """记录任务执行日志"""
        log_file = self.logs_dir / f'{job_id}_{datetime.now().strftime("%Y%m%d")}.log'
        
        log_entry = {
            'timestamp': datetime.now().isoformat(),
            'job_id': job_id,
            'success': success,
            'output': output,
            'error': error
        }
        
        with open(log_file, 'a', encoding='utf-8') as f:
            f.write(json.dumps(log_entry, ensure_ascii=False) + '\n')
    
    def create_job(self, name: str, schedule_str: str, command: str, 
                   enabled: bool = True, description: str = '', 
                   tags: Optional[List[str]] = None) -> Dict[str, Any]:
        """
        创建定时任务
        
        Args:
            name: 任务名称
            schedule_str: 调度表达式（cron格式或简单格式）
            command: 执行的命令
            enabled: 是否启用
            description: 任务描述
            tags: 标签列表
            
        Returns:
            创建的任务信息
        """
        job_id = f"job_{len(self.jobs) + 1:04d}"
        
        job = {
            'id': job_id,
            'name': name,
            'schedule': schedule_str,
            'command': command,
            'enabled': enabled,
            'description': description,
            'tags': tags or [],
            'created_at': datetime.now().isoformat(),
            'updated_at': datetime.now().isoformat(),
            'last_run': None,
            'next_run': None,
            'run_count': 0,
            'success_count': 0,
            'error_count': 0
        }
        
        self.jobs[job_id] = job
        self._save_jobs()
        
        # 如果启用，添加到调度器
        if enabled:
            self._schedule_job(job_id)
        
        return job
    
    def _schedule_job(self, job_id: str):
        """调度任务"""
        if job_id not in self.jobs:
            return
        
        job = self.jobs[job_id]
        
        # 解析调度表达式
        schedule_str = job['schedule']
        
        # 移除已有的调度
        if job_id in self.running_jobs:
            schedule.cancel_job(self.running_jobs[job_id])
        
        # 创建任务函数
        def job_function():
            self._execute_job(job_id)
        
        # 根据调度表达式添加任务
        try:
            # 尝试解析为cron表达式
            if ' ' in schedule_str and len(schedule_str.split()) >= 5:
                # 格式: "*/5 * * * *" (cron格式)
                scheduled_job = schedule.every()
                # 这里需要更复杂的cron解析，暂时简化
                if schedule_str.startswith('*/'):
                    minutes = int(schedule_str.split('*/')[1].split()[0])
                    scheduled_job = scheduled_job.minutes(minutes)
                else:
                    # 默认每小时
                    scheduled_job = scheduled_job.hour()
            else:
                # 简单格式
                if schedule_str.endswith('s'):
                    seconds = int(schedule_str[:-1])
                    scheduled_job = schedule.every(seconds).seconds
                elif schedule_str.endswith('m'):
                    minutes = int(schedule_str[:-1])
                    scheduled_job = schedule.every(minutes).minutes
                elif schedule_str.endswith('h'):
                    hours = int(schedule_str[:-1])
                    scheduled_job = schedule.every(hours).hours
                elif schedule_str.endswith('d'):
                    days = int(schedule_str[:-1])
                    scheduled_job = schedule.every(days).days
                else:
                    # 默认分钟
                    minutes = int(schedule_str) if schedule_str.isdigit() else 1
                    scheduled_job = schedule.every(minutes).minutes
            
            # 保存调度任务
            self.running_jobs[job_id] = scheduled_job.do(job_function)
            
            # 更新下次运行时间
            job['next_run'] = (datetime.now() + timedelta(minutes=1)).isoformat()
            self._save_jobs()
            
        except Exception as e:
            print(f"调度任务失败 {job_id}: {e}")
    
    def _execute_job(self, job_id: str):
        """执行任务"""
        if job_id not in self.jobs:
            return
        
        job = self.jobs[job_id]
        
        # 更新最后运行时间
        job['last_run'] = datetime.now().isoformat()
        job['run_count'] = job.get('run_count', 0) + 1
        
        try:
            # 执行命令
            print(f"执行任务 {job_id}: {job['command']}")
            
            # 根据命令类型执行
            if job['command'].startswith('python '):
                # Python脚本
                script = job['command'][7:]  # 移除"python "
                result = subprocess.run(
                    ['python3', script],
                    capture_output=True,
                    text=True,
                    timeout=300  # 5分钟超时
                )
                output = result.stdout
                error = result.stderr
                success = result.returncode == 0
            
            elif job['command'].startswith('bash ') or job['command'].startswith('sh '):
                # Shell脚本
                script = job['command'][5:] if job['command'].startswith('bash ') else job['command'][3:]
                result = subprocess.run(
                    ['bash', '-c', script],
                    capture_output=True,
                    text=True,
                    timeout=300
                )
                output = result.stdout
                error = result.stderr
                success = result.returncode == 0
            
            elif job['command'].startswith('curl '):
                # HTTP请求
                result = subprocess.run(
                    job['command'].split(),
                    capture_output=True,
                    text=True,
                    timeout=60
                )
                output = result.stdout
                error = result.stderr
                success = result.returncode == 0
            
            else:
                # 其他命令
                result = subprocess.run(
                    job['command'],
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=300
                )
                output = result.stdout
                error = result.stderr
                success = result.returncode == 0
            
            # 更新统计
            if success:
                job['success_count'] = job.get('success_count', 0) + 1
            else:
                job['error_count'] = job.get('error_count', 0) + 1
            
            # 记录日志
            self._log_execution(job_id, success, output[:1000], error[:1000])
            
            print(f"任务 {job_id} 执行{'成功' if success else '失败'}")
            
        except subprocess.TimeoutExpired:
            error = "任务执行超时"
            job['error_count'] = job.get('error_count', 0) + 1
            self._log_execution(job_id, False, '', error)
            print(f"任务 {job_id} 执行超时")
            
        except Exception as e:
            error = str(e)
            job['error_count'] = job.get('error_count', 0) + 1
            self._log_execution(job_id, False, '', error)
            print(f"任务 {job_id} 执行异常: {e}")
        
        finally:
            # 更新下次运行时间
            job['next_run'] = (datetime.now() + timedelta(minutes=1)).isoformat()
            self._save_jobs()
    
    def list_jobs(self, enabled_only: bool = False) -> List[Dict[str, Any]]:
        """
        列出所有任务
        
        Args:
            enabled_only: 是否只列出启用的任务
            
        Returns:
            任务列表
        """
        jobs_list = list(self.jobs.values())
        
        if enabled_only:
            jobs_list = [job for job in jobs_list if job.get('enabled', False)]
        
        # 按创建时间排序
        jobs_list.sort(key=lambda x: x.get('created_at', ''), reverse=True)
        
        return jobs_list
    
    def get_job(self, job_id: str) -> Optional[Dict[str, Any]]:
        """
        获取任务详情
        
        Args:
            job_id: 任务ID
            
        Returns:
            任务信息或None
        """
        return self.jobs.get(job_id)
    
    def update_job(self, job_id: str, **kwargs) -> Optional[Dict[str, Any]]:
        """
        更新任务
        
        Args:
            job_id: 任务ID
            **kwargs: 要更新的字段
            
        Returns:
            更新后的任务信息或None
        """
        if job_id not in self.jobs:
            return None
        
        job = self.jobs[job_id]
        
        # 更新字段
        for key, value in kwargs.items():
            if key in job:
                job[key] = value
        
        job['updated_at'] = datetime.now().isoformat()
        
        # 如果启用状态改变，更新调度
        if 'enabled' in kwargs:
            if kwargs['enabled']:
                self._schedule_job(job_id)
            elif job_id in self.running_jobs:
                schedule.cancel_job(self.running_jobs[job_id])
                del self.running_jobs[job_id]
        
        # 如果调度表达式改变，重新调度
        if 'schedule' in kwargs and job.get('enabled', False):
            self._schedule_job(job_id)
        
        self._save_jobs()
        return job
    
    def delete_job(self, job_id: str) -> bool:
        """
        删除任务
        
        Args:
            job_id: 任务ID
            
        Returns:
            是否成功删除
        """
        if job_id not in self.jobs:
            return False
        
        # 取消调度
        if job_id in self.running_jobs:
            schedule.cancel_job(self.running_jobs[job_id])
            del self.running_jobs[job_id]
        
        # 删除任务
        del self.jobs[job_id]
        self._save_jobs()
        
        return True
    
    def run_job_now(self, job_id: str) -> Dict[str, Any]:
        """
        立即运行任务
        
        Args:
            job_id: 任务ID
            
        Returns:
            执行结果
        """
        if job_id not in self.jobs:
            return {'success': False, 'error': '任务不存在'}
        
        # 在后台线程中执行
        thread = threading.Thread(target=self._execute_job, args=(job_id,))
        thread.daemon = True
        thread.start()
        
        return {
            'success': True,
            'job_id': job_id,
            'message': '任务已开始执行'
        }
    
    def get_job_logs(self, job_id: str, days: int = 7) -> List[Dict[str, Any]]:
        """
        获取任务日志
        
        Args:
            job_id: 任务ID
            days: 获取最近几天的日志
            
        Returns:
            日志列表
        """
        logs = []
        end_date = datetime.now()
        start_date = end_date - timedelta(days=days)
        
        current_date = start_date
        while current_date <= end_date:
            log_file = self.logs_dir / f'{job_id}_{current_date.strftime("%Y%m%d")}.log'
            
            if log_file.exists():
                try:
                    with open(log_file, 'r', encoding='utf-8') as f:
                        for line in f:
                            if line.strip():
                                log_entry = json.loads(line.strip())
                                logs.append(log_entry)
                except (json.JSONDecodeError, IOError):
                    pass
            
            current_date += timedelta(days=1)
        
        # 按时间排序
        logs.sort(key=lambda x: x.get('timestamp', ''), reverse=True)
        
        return logs
    
    def start_scheduler(self):
        """启动调度器"""
        if self.scheduler_thread and self.scheduler_thread.is_alive():
            return
        
        self.stop_scheduler = False
        
        def scheduler_loop():
            while not self.stop_scheduler:
                schedule.run_pending()
                time.sleep(1)
        
        self.scheduler_thread = threading.Thread(target=scheduler_loop)
        self.scheduler_thread.daemon = True
        self.scheduler_thread.start()
        
        print("调度器已启动")
    
    def stop_scheduler(self):
        """停止调度器"""
        self.stop_scheduler = True
        if self.scheduler_thread:
            self.scheduler_thread.join(timeout=5)
        
        print("调度器已停止")
    
    def stats(self) -> Dict[str, Any]:
        """
        获取统计信息
        
        Returns:
            统计信息
        """
        total_jobs = len(self.jobs)
        enabled_jobs = sum(1 for job in self.jobs.values() if job.get('enabled', False))
        
        total_runs = sum(job.get('run_count', 0) for job in self.jobs.values())
        total_success = sum(job.get('success_count', 0) for job in self.jobs.values())
        total_errors = sum(job.get('error_count', 0) for job in self.jobs.values())
        
        success_rate = (total_success / total_runs * 100) if total_runs > 0 else 0
        
        return {
            'total_jobs': total_jobs,
            'enabled_jobs': enabled_jobs,
            'disabled_jobs': total_jobs - enabled_jobs,
            'total_runs': total_runs,
            'total_success': total_success,
            'total_errors': total_errors,
            'success_rate': round(success_rate, 2),
            'running_jobs': len(self.running_jobs),
            'scheduler_running': self.scheduler_thread is not None and self.scheduler_thread.is_alive()
        }

def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Cron Manager - 定时任务管理')
    subparsers = parser.add_subparsers(dest='command', help='命令')
    
    # create命令
    create_parser = subparsers.add_parser('create', help='创建定时任务')
    create_parser.add_argument('--name', required=True, help='任务名称')
    create_parser.add_argument('--schedule', required=True, help='调度表达式')
    create_parser.add_argument('--command', required=True, help='执行的命令')
    create_parser.add_argument('--enabled', action='store_true', help='是否启用')
    create_parser.add_argument('--description', help='任务描述')
    create_parser.add_argument('--tags', help='标签（逗号分隔）')
    
    # list命令
    list_parser = subparsers.add_parser('list', help='列出所有任务')
    list_parser.add_argument('--enabled-only', action='store_true', help='只列出启用的任务')
    
    # get命令
    get_parser = subparsers.add_parser('get', help='获取任务详情')
    get_parser.add_argument('--id', required=True, help='任务ID')
    
    # update命令
    update_parser = subparsers.add_parser('update', help='更新任务')
    update_parser.add_argument('--id', required=True, help='任务ID')
    update_parser.add_argument('--name', help='任务名称')
    update_parser.add_argument('--schedule', help='调度表达式')
    update_parser.add_argument('--command', help='执行的命令')
    update_parser.add_argument('--enabled', type=bool, help='是否启用')
    update_parser.add_argument('--description', help='任务描述')
    update_parser.add_argument('--tags', help='标签（逗号分隔）')
    
    # delete命令
    delete_parser = subparsers.add_parser('delete', help='删除任务')
    delete_parser.add_argument('--id', required=True, help='任务ID')
    
    # run命令
    run_parser = subparsers.add_parser('run', help='立即运行任务')
    run_parser.add_argument('--id', required=True, help='任务ID')
    
    # logs命令
    logs_parser = subparsers.add_parser('logs', help='获取任务日志')
    logs_parser.add_argument('--id', required=True, help='任务ID')
    logs_parser.add_argument('--days', type=int, default=7, help='获取最近几天的日志')
    
    # stats命令
    stats_parser = subparsers.add_parser('stats', help='获取统计信息')
    
    # start命令
    start_parser = subparsers.add_parser('start', help='启动调度器')
    
    # stop命令
    stop_parser = subparsers.add_parser('stop', help='停止调度器')
    
    args = parser.parse_args()
    
    manager = CronManager()
    
    if args.command == 'create':
        tags = args.tags.split(',') if args.tags else None
        job = manager.create_job(
            args.name, args.schedule, args.command,
            args.enabled, args.description, tags
        )
        print(json.dumps(job, ensure_ascii=False, indent=2))
    
    elif args.command == 'list':
        jobs = manager.list_jobs(args.enabled_only)
        print(json.dumps(jobs, ensure_ascii=False, indent=2))
    
    elif args.command == 'get':
        job = manager.get_job(args.id)
        if job:
            print(json.dumps(job, ensure_ascii=False, indent=2))
        else:
            print('未找到任务')
    
    elif args.command == 'update':
        kwargs = {}
        if args.name: kwargs['name'] = args.name
        if args.schedule: kwargs['schedule'] = args.schedule
        if args.command: kwargs['command'] = args.command
        if args.enabled is not None: kwargs['enabled'] = args.enabled
        if args.description: kwargs['description'] = args.description
        if args.tags: kwargs['tags'] = args.tags.split(',')
        
        job = manager.update_job(args.id, **kwargs)
        if job:
            print(json.dumps(job, ensure_ascii=False, indent=2))
        else:
            print('未找到任务')
    
    elif args.command == 'delete':
        success = manager.delete_job(args.id)
        print(json.dumps({'success': success, 'id': args.id}, ensure_ascii=False, indent=2))
    
    elif args.command == 'run':
        result = manager.run_job_now(args.id)
        print(json.dumps(result, ensure_ascii=False, indent=2))
    
    elif args.command == 'logs':
        logs = manager.get_job_logs(args.id, args.days)
        print(json.dumps(logs, ensure_ascii=False, indent=2))
    
    elif args.command == 'stats':
        stats = manager.stats()
        print(json.dumps(stats, ensure_ascii=False, indent=2))
    
    elif args.command == 'start':
        manager.start_scheduler()
        print(json.dumps({'success': True, 'message': '调度器已启动'}, ensure_ascii=False, indent=2))
    
    elif args.command == 'stop':
        manager.stop_scheduler()
        print(json.dumps({'success': True, 'message': '调度器已停止'}, ensure_ascii=False, indent=2))
    
    else:
        parser.print_help()

if __name__ == '__main__':
    main()