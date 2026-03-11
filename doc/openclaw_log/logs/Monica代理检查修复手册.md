# Monica代理检查修复手册

## 概述
本文档提供Monica代理集成问题的系统化检查、诊断和修复流程。当出现"飞书发消息无返回"或"Monica代理调用失败"问题时，按照本手册逐步排查。

## 快速检查清单

### ✅ 基础状态检查
- [ ] Monica代理进程是否运行？
- [ ] 8080端口是否监听？
- [ ] Monica API是否可访问？
- [ ] OpenClaw网关是否运行？
- [ ] 飞书通道是否正常？

### ✅ 配置检查
- [ ] OpenClaw配置中的Monica模型是否实际存在？
- [ ] Fallback链中的模型是否都有效？
- [ ] 模型ID格式是否正确？

### ✅ 功能测试
- [ ] 直接调用Monica API是否成功？
- [ ] 通过OpenClaw调用Monica模型是否成功？
- [ ] 完整流程（飞书→OpenClaw→Monica）是否正常？

## 详细检查步骤

### 步骤1：基础状态检查

#### 1.1 检查Monica代理进程
```bash
# 检查Monica代理是否运行
ps aux | grep -i "monica-proxy"

# 预期结果：应该看到monica-proxy-wails进程
# 示例：wlli 79883 0.0 0.5 41577796 40140 ... ./monica-proxy-wails
```

#### 1.2 检查端口监听
```bash
# 检查8080端口是否监听
lsof -i :8080

# 预期结果：应该看到monica-proxy进程监听8080端口
```

#### 1.3 测试Monica API连通性
```bash
# 测试/v1/models接口
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8080/v1/models

# 预期结果：返回JSON格式的模型列表
```

#### 1.4 检查OpenClaw状态
```bash
# 检查OpenClaw网关
openclaw status

# 预期结果：显示所有通道状态正常
```

### 步骤2：配置检查

#### 2.1 获取Monica代理实际支持的模型
```bash
# 获取Monica代理支持的模型列表
curl -s -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:8080/v1/models | jq -r '.data[].id' | sort > /tmp/monica_actual.txt
```

#### 2.2 获取OpenClaw配置的Monica模型
```bash
# 获取OpenClaw配置中的Monica模型
grep -o '"monica/[^"]*"' ~/.openclaw/openclaw.json | \
  sed 's/"monica\///g' | sed 's/"//g' | sort -u > /tmp/openclaw_config.txt
```

#### 2.3 对比模型列表
```bash
# 找出不匹配的模型
echo "=== OpenClaw配置但Monica不支持的模型 ==="
comm -23 /tmp/openclaw_config.txt /tmp/monica_actual.txt

echo -e "\n=== Monica支持但OpenClaw未配置的模型 ==="
comm -13 /tmp/openclaw_config.txt /tmp/monica_actual.txt
```

#### 2.4 检查Fallback链
```bash
# 检查fallback链配置
grep -A10 '"fallbacks"' ~/.openclaw/openclaw.json

# 验证每个fallback模型是否实际存在
```

### 步骤3：功能测试

#### 3.1 直接API调用测试
```bash
# 测试单个模型调用
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"model": "claude-4-sonnet", "messages": [{"role": "user", "content": "测试"}], "stream": false}' \
  http://localhost:8080/v1/chat/completions
```

#### 3.2 系统命令测试
```bash
# 测试OpenClaw执行系统命令
cd /path/to/project && git status
```

#### 3.3 完整流程测试
```bash
# 模拟完整流程：git status + Monica分析
GIT_STATUS=$(cd /path/to/project && git status)
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d "{\"model\": \"claude-4-sonnet\", \"messages\": [{\"role\": \"user\", \"content\": \"分析git状态：$GIT_STATUS\"}], \"stream\": false}" \
  http://localhost:8080/v1/chat/completions
```

## 常见问题及解决方案

### 问题1：Monica代理未运行
**症状**：`ps aux | grep -i monica` 无输出

**解决方案**：
```bash
# 启动Monica代理
cd /path/to/monica2api
./build/bin/monica-proxy-wails &

# 或通过Wails GUI启动
open ./build/bin/monica-proxy-wails.app
```

### 问题2：模型ID不匹配
**症状**：OpenClaw配置的模型Monica代理不支持

**解决方案**：
```bash
# 使用修复脚本
/path/to/fix_config_simple.sh

# 或手动更新fallback链
# 只保留实际支持的模型
```

### 问题3：API调用失败
**症状**：curl测试返回错误

**解决方案**：
1. 检查认证token是否正确
2. 检查Monica代理日志
3. 验证网络连接

### 问题4：飞书无响应
**症状**：飞书发送消息后无回复

**解决方案**：
1. 检查OpenClaw日志：`openclaw logs --limit 100`
2. 验证飞书插件配置
3. 测试直接API调用是否成功

## 修复脚本

### 快速修复脚本
```bash
#!/bin/bash
# fix_monica_config.sh
# 快速修复Monica配置问题

echo "=== 修复Monica配置 ==="

# 备份配置
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.backup.$(date +%Y%m%d_%H%M%S)

# 更新fallback链（使用实际支持的模型）
jq '.agents.defaults.model.fallbacks = [
  "monica/claude-4-sonnet",
  "monica/gpt-4o",
  "monica/gpt-5",
  "monica/gemini-2.5-pro",
  "deepseek/deepseek-chat",
  "qwen-portal/coder-model",
  "qwen-portal/vision-model"
]' ~/.openclaw/openclaw.json > /tmp/fixed.json && mv /tmp/fixed.json ~/.openclaw/openclaw.json

echo "✅ 配置已修复，重启OpenClaw生效"
```

### 完整检查脚本
```bash
#!/bin/bash
# check_monica_health.sh
# 完整健康检查

echo "=== Monica代理健康检查 ==="
echo "1. 进程检查..."
ps aux | grep -i monica | grep -v grep && echo "✅" || echo "❌"

echo "2. 端口检查..."
lsof -i :8080 && echo "✅" || echo "❌"

echo "3. API检查..."
curl -s -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8080/v1/models >/dev/null && echo "✅" || echo "❌"

echo "4. 模型调用测试..."
curl -s -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"model": "claude-4-sonnet", "messages": [{"role": "user", "content": "test"}], "stream": false}' \
  http://localhost:8080/v1/chat/completions >/dev/null && echo "✅" || echo "❌"

echo "=== 检查完成 ==="
```

## 预防措施

### 定期维护
1. **每周检查**：运行健康检查脚本
2. **配置同步**：Monica模型更新后同步OpenClaw配置
3. **日志监控**：监控OpenClaw和Monica代理日志

### 自动化脚本
1. **健康检查**：定时运行检查脚本
2. **自动修复**：检测到问题自动修复
3. **告警通知**：发现问题发送通知

### 文档更新
1. **问题记录**：记录每次问题的原因和解决方案
2. **知识库更新**：更新检查修复手册
3. **团队分享**：分享经验和最佳实践

## 紧急联系人
- **技术支持**：OpenClaw AI助手
- **问题反馈**：记录到doc/openclaw_log/
- **紧急修复**：使用快速修复脚本

---
**版本**：1.0  
**更新日期**：2026-03-11  
**适用场景**：Monica代理集成问题排查和修复