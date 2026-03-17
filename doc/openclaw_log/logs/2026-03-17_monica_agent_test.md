# 2026-03-17 - Monica Agent测试和验收

## 测试要求

根据用户要求，需要进行以下测试：

### 1. 逻辑分支修改
- **Monica代理**（需要Function Calling的模型）→ Custom Bot分支
- **其他模型**（DeepSeek、Qwen、Kimi等原生大模型）→ 普通Chat分支（直接调用）

### 2. 测试场景
1. **默认模型DeepSeek**：正常且快速响应返回
2. **Monica代理**：`/monica gpt5`，使用Monica中的GPT5模型回答，不用切换默认模型

### 3. 验收标准
1. **非Monica模式**：
   - 在飞书中发消息 → 大模型 → 返回显示在飞书
   
2. **Monica Agent模式**：
   - 在飞书中发消息 → 包装Function Calling → 大模型 → 返回解析 → 返回飞书显示
   - 要求在Monica Agent模型下可以操作系统命令，比如打开浏览器
   
3. **稳定性要求**：
   - 极其重要：在飞书发消息不能卡死

## 逻辑分支修改

### 修改内容
已更新 `shouldUseCustomBot` 函数，现在根据模型类型智能选择分支：

#### 需要走Monica代理（Custom Bot分支）的模型：
- GPT系列（gpt-, gpt4, gpt5）
- Claude系列（claude-）
- Gemini系列（gemini-）
- OpenAI o系列（o1-, o3, o4-）
- Sonar、Grok系列

#### 直接调用（普通Chat分支）的模型：
- DeepSeek系列
- Qwen系列（需要添加）
- Kimi系列（需要添加）
- 其他原生大模型

### 代码位置
`/internal/apiserver/router.go` 中的 `shouldUseCustomBot` 函数

## 测试计划

### 测试1：DeepSeek默认模型
**目标**：验证DeepSeek能正常快速响应

**步骤**：
1. 配置OpenClaw默认模型为deepseek-chat
2. 在飞书发送消息
3. 验证响应速度和正确性

**预期结果**：
- 快速响应（<5秒）
- 消息正常显示在飞书
- 不走Monica代理分支

### 测试2：Monica代理模式
**目标**：验证Monica代理能正常处理Function Calling

**步骤**：
1. 使用 `/monica gpt5` 命令
2. 发送需要工具调用的消息（如"打开浏览器"）
3. 验证Function Calling流程

**预期结果**：
- 走Monica代理分支
- 正常包装和解析Function Calling
- 能执行系统命令
- 结果返回飞书

### 测试3：多模型切换
**目标**：验证模型切换不影响功能

**步骤**：
1. 测试DeepSeek → Monica GPT5 → DeepSeek
2. 验证每次切换都能正常响应

**预期结果**：
- 模型切换顺畅
- 无卡死现象
- 分支选择正确

## 开始测试

### 时间记录
- **开始时间**: 2026-03-17 11:15 GMT+8
- **当前状态**: 正在准备测试环境

### 测试环境准备

由于无法直接编译Go代码，我将通过以下方式测试：

1. **检查代码逻辑正确性**
2. **创建测试配置文件**
3. **模拟测试场景**
4. **验证日志输出**

### 第一步：创建测试配置文件

已创建测试配置文件：`test_config.yaml`

### 第二步：模拟测试场景

由于无法实际启动服务，我将通过代码分析来验证逻辑正确性。

#### 测试场景1：DeepSeek默认模型
**配置**：
- `default_model: "deepseek-chat"`
- `enable_custom_bot_mode: true`

**预期行为**：
1. 收到DeepSeek模型请求
2. `shouldUseCustomBot("deepseek-chat", cfg)` 返回 `false`
3. 走普通Chat分支（直接调用）
4. 日志输出："原生大模型使用直接调用模式"

#### 测试场景2：Monica GPT5模型
**配置**：
- 模型：`"gpt-5"`
- `enable_custom_bot_mode: true`

**预期行为**：
1. 收到GPT-5模型请求
2. `shouldUseCustomBot("gpt-5", cfg)` 返回 `true`
3. 走Custom Bot分支（Function Calling）
4. 日志输出："模型需要Monica代理（Function Calling）"

#### 测试场景3：其他原生大模型
**配置**：
- 模型：`"qwen-max"`（假设）
- `enable_custom_bot_mode: true`

**预期行为**：
1. 收到Qwen模型请求
2. `shouldUseCustomBot("qwen-max", cfg)` 返回 `false`
3. 走普通Chat分支（直接调用）
4. 日志输出："原生大模型使用直接调用模式"

### 第三步：验证代码逻辑

让我验证 `shouldUseCustomBot` 函数的逻辑：