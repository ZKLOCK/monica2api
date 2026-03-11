# 2026-03-11 - Monica代理集成问题修复经验

## 问题描述
**时间线**：
- 2026-03-10 14:44:00：Monica代理可以成功接入，并且可以提交代码
- 2026-03-10 15:00:00：飞书发消息无返回，无操作电脑能力

**症状**：
- 飞书发送消息给OpenClaw无响应
- Monica代理看似正常运行，但调用失败
- 完整的 `feishu → openclaw → monica-proxy → models` 流程中断

## 问题根本原因

### 1. 模型ID不匹配问题
**发现**：OpenClaw配置中的Monica模型ID与Monica代理实际支持的模型ID不匹配

**具体问题**：
- OpenClaw配置了17个Monica代理不支持的模型
- Fallback链前5个模型都不存在：
  1. `monica/gemini-3.1-pro` → ❌ 不支持
  2. `monica/claude-4.6-sonnet` → ❌ 不支持  
  3. `monica/gpt-5.4` → ❌ 不支持
  4. `monica/gpt-5.3-codex` → ❌ 不支持
  5. `monica/gemini-3-flash` → ❌ 不支持

### 2. 模型格式差异
- OpenClaw配置：`claude-3.5-sonnet`
- Monica代理实际：`claude-3-5-sonnet`（连字符vs点）

### 3. 错误处理机制问题
当OpenClaw尝试调用不支持的模型时：
1. Monica代理可能返回错误
2. OpenClaw的fallback机制可能没有正确处理
3. 导致整个调用链失败

## 修复步骤

### 步骤1：诊断问题
1. 检查Monica代理运行状态：`ps aux | grep -i monica`
2. 测试Monica API连通性：`curl http://localhost:8080/v1/models`
3. 对比OpenClaw配置与Monica实际支持的模型

### 步骤2：识别不匹配的模型
```bash
# 获取OpenClaw配置中的Monica模型
grep -o '"monica/[^"]*"' ~/.openclaw/openclaw.json

# 获取Monica代理实际支持的模型
curl -H "Authorization: Bearer ..." http://localhost:8080/v1/models

# 对比找出不匹配的模型
```

### 步骤3：修复OpenClaw配置
1. **更新fallback链**：只使用Monica代理实际支持的模型
2. **移除不支持的模型**：从配置中删除
3. **验证配置**：确保所有配置的模型都实际存在

### 步骤4：测试修复
1. **单元测试**：测试单个模型调用
2. **集成测试**：测试完整流程
3. **验收测试**：验证所有功能恢复正常

## 修复后的配置

### Fallback链（修复后）：
```json
"fallbacks": [
  "monica/claude-4-sonnet",
  "monica/gpt-4o",
  "monica/gpt-5",
  "monica/gemini-2.5-pro",
  "deepseek/deepseek-chat",
  "qwen-portal/coder-model",
  "qwen-portal/vision-model"
]
```

### 关键修复：
1. 只使用实际支持的模型
2. 确保模型ID完全匹配
3. 保留有效的fallback机制

## 经验教训

### 技术经验：
1. **配置同步重要**：OpenClaw配置必须与Monica代理实际支持的模型同步
2. **防御性编程**：在配置中添加模型前，应先验证模型是否存在
3. **错误处理**：增强对模型调用失败的处理机制

### 调试经验：
1. **分层测试**：从底层API开始测试，逐步向上
2. **对比验证**：对比配置与实际支持的资源
3. **日志分析**：通过日志定位问题根源

### 预防措施：
1. **定期同步**：建立模型配置同步机制
2. **配置验证**：添加配置验证脚本
3. **监控告警**：添加模型调用成功率的监控

## 验证结果

### 修复验证：
- ✅ Monica代理成功接入
- ✅ 可以操作背后大模型（Claude 4 Sonnet, GPT-5, GPT-4o等）
- ✅ 可以操作电脑（通过OpenClaw执行git命令）

### 完整流程验证：
1. 飞书发送消息 → OpenClaw
2. OpenClaw调用Monica模型
3. Monica代理处理请求，调用大模型
4. 响应返回给OpenClaw → 飞书

## 后续建议

### 短期优化：
1. 添加配置验证脚本
2. 增强错误日志
3. 优化fallback机制

### 长期规划：
1. 建立模型配置同步机制
2. 添加模型健康检查
3. 实现自动配置更新

## 相关脚本
- `test_monica_integration.sh` - 集成测试脚本
- `test_full_flow.sh` - 完整流程测试脚本
- `fix_config_simple.sh` - 配置修复脚本
- `验收测试.sh` - 验收测试脚本

---
**记录时间**：2026-03-11 13:40  
**修复人员**：OpenClaw AI助手  
**状态**：✅ 问题已修复，经验已记录