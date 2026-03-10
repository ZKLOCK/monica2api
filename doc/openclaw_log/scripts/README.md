# Monica 代理集成项目脚本说明

## 项目概述
本项目成功将Monica作为大模型平台通过Proxy接入OpenClaw，并实现了飞书插件的正常显示功能。

## 脚本目录结构

```
doc/scripts/
├── README.md                    # 本文件
├── build_and_test_fix.sh        # 构建和测试修复脚本
├── debug_monica_detailed.sh     # Monica代理详细调试脚本
├── debug_monica_error_500.sh    # 500错误调试脚本
├── diagnose_monica_api.sh       # API诊断脚本
├── setup_monica_for_openclaw.sh # OpenClaw集成设置脚本
├── test_aggregated_response.sh  # 聚合响应测试脚本
├── test_feishu_response_format.sh # 飞书响应格式测试
├── test_openclaw_monica_integration.sh # 集成测试脚本
└── test_response_structure.sh   # 响应结构测试脚本
```

## 脚本功能说明

### 1. 构建和测试脚本
**build_and_test_fix.sh**
- 构建Monica代理项目
- 运行测试验证修复效果
- 检查API响应格式

### 2. 调试脚本
**debug_monica_detailed.sh**
- 详细的Monica代理调试
- 检查SSE流式响应
- 验证JSON聚合功能

**debug_monica_error_500.sh**
- 专门调试500错误
- 检查panic问题修复
- 验证防御性编程

### 3. 诊断脚本
**diagnose_monica_api.sh**
- 诊断Monica API连接问题
- 检查Cookie和认证状态
- 验证模型可用性

### 4. 设置脚本
**setup_monica_for_openclaw.sh**
- 自动配置OpenClaw使用Monica代理
- 设置模型fallback链
- 验证集成配置

### 5. 测试脚本
**test_aggregated_response.sh**
- 测试SSE流式响应聚合
- 验证完整JSON输出
- 检查响应格式规范

**test_feishu_response_format.sh**
- 测试飞书插件响应格式
- 验证消息显示功能
- 检查端到端流程

**test_openclaw_monica_integration.sh**
- 完整的集成测试
- 验证OpenClaw ↔ Monica代理连接
- 测试模型切换功能

**test_response_structure.sh**
- 测试响应数据结构
- 验证错误处理机制
- 检查API接口规范

## 使用说明

### 基本使用
```bash
# 运行任意脚本
chmod +x script_name.sh
./script_name.sh
```

### 环境要求
- macOS/Linux系统
- bash shell
- curl命令
- jq命令（用于JSON处理）
- OpenClaw已安装并运行
- Monica代理已启动

### 配置说明
脚本使用以下环境变量（如需要）：
- `MONICA_API_KEY`: Monica代理API密钥
- `OPENCLAW_HOST`: OpenClaw服务地址（默认: 127.0.0.1:18789）
- `FEISHU_BOT_ID`: 飞书机器人ID

## 项目状态
- ✅ Monica代理集成成功
- ✅ 飞书插件正常工作
- ✅ 代码已提交到远程仓库
- ✅ 文档已整理归档

## 故障排除

### 常见问题
1. **500错误**: 运行`debug_monica_error_500.sh`
2. **响应格式问题**: 运行`test_response_structure.sh`
3. **集成问题**: 运行`test_openclaw_monica_integration.sh`
4. **飞书显示问题**: 运行`test_feishu_response_format.sh`

### 日志位置
- Monica代理日志: `~/.monica-proxy/logs/monica-proxy.log`
- OpenClaw日志: `/tmp/openclaw/openclaw-YYYY-MM-DD.log`

## 更新记录
- 2026-03-10: 项目完成，脚本整理归档
- 2026-03-10: 修复panic问题，实现SSE→JSON聚合
- 2026-03-09: 初始集成测试

## 联系方式
如有问题，请参考项目文档或联系项目负责人。

---
**项目完成时间:** 2026-03-10  
**状态:** 生产就绪 ✅