# Monica代理测试修复脚本

## 脚本说明

### 1. 测试脚本
- `test_monica_integration.sh` - Monica代理集成测试
- `test_full_flow.sh` - 完整流程测试（飞书→OpenClaw→Monica）
- `验收测试.sh` - 验收测试脚本
- `验收测试_v2.sh` - 改进版验收测试

### 2. 修复脚本
- `fix_config_simple.sh` - 简单配置修复
- `配置新模型.sh` - 配置新Monica模型

## 使用说明

### 快速测试
```bash
# 运行验收测试
./验收测试_v2.sh

# 运行完整流程测试
./test_full_flow.sh
```

### 快速修复
```bash
# 修复配置问题
./fix_config_simple.sh

# 配置新模型
./配置新模型.sh
```

## 依赖要求
- curl
- jq
- OpenClaw CLI
- Monica代理运行在8080端口

## 注意事项
1. 运行前确保Monica代理正在运行
2. 脚本中的token需要替换为实际的Monica代理token
3. 部分脚本需要OpenClaw网关运行

## 更新日志
- 2026-03-11：创建初始版本
- 包含Monica代理问题修复的所有测试和修复脚本
