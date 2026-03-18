# Agent Browser Skill - 浏览器自动化

自动化浏览器操作，实现网页自动化。

## 功能
- 网页导航和操作
- 表单自动填写
- 数据抓取和提取
- 屏幕截图和录制

## 使用方法
```bash
# 打开网页
openclaw browser open --url "https://example.com"

# 点击元素
openclaw browser click --selector "button.submit"

# 填写表单
openclaw browser fill --form "login" --data '{"username": "test", "password": "pass"}'

# 截图
openclaw browser screenshot --output page.png

# 抓取数据
openclaw browser scrape --selector ".article" --output articles.json
```

## 支持的操作
- 点击、输入、滚动
- 等待元素加载
- JavaScript执行
- 文件上传下载
