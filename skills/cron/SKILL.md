# Cron Skill - 定时任务管理

管理OpenClaw的定时任务（cron jobs）。

## 功能
- 创建、列出、删除定时任务
- 监控任务执行状态
- 查看任务日志

## 使用方法
```bash
# 列出所有定时任务
openclaw cron list

# 创建定时任务
openclaw cron create --name "daily-backup" --schedule "0 2 * * *" --command "backup.sh"

# 删除定时任务
openclaw cron delete --name "daily-backup"
```

## 配置
在OpenClaw配置文件中启用cron插件：
```json
{
  "cron": {
    "enabled": true,
    "jobs": []
  }
}
```
