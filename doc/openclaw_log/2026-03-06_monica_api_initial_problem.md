# 2026-03-06 Monica API 初始问题发现与方案设计

## 📅 日期
2026年3月6日

## 👥 参与者
- 用户 (ou_a7f92726e604fb863f76581ac5eda3c4)
- 小龙虾 (OpenClaw AI 助手)

## 📋 讨论内容

### 1. 问题发现
**时间**: 2026-03-06 22:39 GMT+8
**问题**: 使用curl请求Monica API时总是返回403 Forbidden错误

**用户反馈**: 
- 飞书发消息怎么没回？
- 还记得上次任务么？
- 提供了飞书文档链接：https://applink.feishu.cn/client/message/link/open?token=Aml%2FOml2AAzWaarlwYbAC8Y%3D

### 2. 问题分析
**项目位置**: `/Users/wlli/Documents/project/openclaw/monica2api`

**核心问题**:
1. **Cookie管理问题**: 项目GUI只提供Cookie输入框，没有自动获取机制
2. **Header格式问题**: HTTP请求中的Cookie header格式不规范
3. **反爬虫策略**: Monica加强了安全策略，需要完整的浏览器特征

**技术难点**:
- 需要解决Cookie获取和验证问题
- 需要处理HTTP请求头的格式要求
- 需要应对Monica的反爬虫机制

### 3. 解决方案讨论
讨论了三个方案：

#### 方案A: 快速修复（1-2小时）
- **思路**: 更新硬编码的Headers
- **优点**: 快速见效
- **缺点**: 治标不治本，下次Monica更新策略又失效
- **状态**: ❌ 未采用

#### 方案B: 中期方案（1天）
- **思路**: 动态Header配置
- **优点**: 可通过配置文件更新Headers
- **缺点**: 仍需手动抓包
- **状态**: ❌ 未采用

#### 方案C: 长期方案（3-5天）⭐ **采用**
- **思路**: 利用Wails WebView内核自动同步Cookie
- **优点**: 一劳永逸，用户体验好
- **缺点**: 开发工作量较大
- **状态**: ✅ **决定采用**

### 4. 方案C设计思路
**核心思想**: Wails WebView Cookie同步方案

**技术架构**:
1. **Go后端**: 提供Cookie验证、浏览器打开、脚本生成等工具函数
2. **前端组件**: 创建完整的Cookie管理界面
3. **Wails集成**: 通过Wails框架连接前后端

**预期功能**:
- 点击"获取助手"按钮查看详细的Cookie获取指南
- 点击"打开登录页"按钮在浏览器中打开Monica登录页面
- 复制提供的JavaScript脚本到浏览器控制台自动复制Cookie
- 点击"测试验证"按钮验证Cookie有效性
- 自动检查Cookie是否可能过期

### 5. 实施计划
#### 第一阶段：Go后端实现（100%完成）
1. ✅ 创建 `internal/utils/cookie_helper.go` - Cookie验证、浏览器打开、脚本生成等工具函数
2. ✅ 修改 `main_wails.go` - 添加7个WailsApp方法

#### 第二阶段：前端组件实现（100%完成）
1. ✅ 创建 `frontend/src/views/CookieHelper.vue` - 完整的Cookie管理界面
2. ✅ 修改 `frontend/src/views/MainConfig.vue` - 集成Cookie助手

#### 第三阶段：构建与测试
1. ✅ 修复图标导入错误
2. ✅ 重新生成Wails JS绑定
3. ✅ 成功构建Wails应用

### 6. 设计思想
#### 用户友好原则
- **引导式操作**: 分步骤的Cookie获取指南
- **自动化脚本**: 浏览器控制台一键复制
- **实时验证**: 即时反馈Cookie有效性
- **安全提示**: 明确的警告和注意事项

#### 健壮性设计
- **错误处理**: 完善的错误提示和恢复建议
- **格式清理**: 自动修复用户输入的Cookie格式
- **兼容性**: 支持不同浏览器和操作系统
- **可维护性**: 模块化设计，易于扩展

### 7. 技术选型考量
- **Wails框架**: 利用WebView内核，避免安全限制
- **Go语言**: 高性能HTTP客户端，适合API代理
- **Vue3 + Element Plus**: 现代前端，开发效率高
- **Resty库**: 功能丰富的HTTP客户端库

### 8. 经验教训
#### 技术收获
1. **Go HTTP客户端细节**: 需要深入了解HTTP协议规范
2. **Cookie管理复杂性**: 意识到Cookie格式清理的重要性
3. **Wails框架限制**: 了解WebView安全策略的应对方法
4. **前端后端协作**: 学习清晰的API设计和错误传递

#### 开发流程经验
1. **渐进式方案设计**: 从简单到复杂，确保每一步都可行
2. **用户中心设计**: 始终考虑最终用户的操作体验
3. **模块化开发**: 功能分离，便于测试和维护

### 9. 相关文件
1. **设计文档**: `doc/monica/2.项目架构设计分析.md`
2. **代码文件**: 
   - `internal/utils/cookie_helper.go`
   - `main_wails.go`
   - `frontend/src/views/CookieHelper.vue`
   - `frontend/src/views/MainConfig.vue`

### 10. 总结
今天是Monica2API项目的起点，我们：
1. **明确了问题**: 403 Forbidden错误和Cookie管理难题
2. **设计了方案**: 选择了长期解决方案C（Wails WebView Cookie同步）
3. **制定了计划**: 清晰的三阶段实施计划
4. **确立了原则**: 用户友好和健壮性设计思想

这个方案虽然开发工作量较大，但能够从根本上解决问题，提供最佳的用户体验。🦞