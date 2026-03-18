# Image Generation Skill - 图像生成

使用AI生成图像。

## 功能
- 文本到图像生成
- 图像编辑和修改
- 图像风格转换
- 图像放大和优化

## 使用方法
```bash
# 生成图像
openclaw image generate --prompt "一只可爱的猫在月球上" --size "1024x1024"

# 编辑图像
openclaw image edit --input cat.jpg --prompt "添加太空服"

# 转换风格
openclaw image style --input photo.jpg --style "油画风格"

# 放大图像
openclaw image upscale --input small.jpg --scale 2
```

## 支持的模型
- DALL-E 3
- Stable Diffusion
- Midjourney (通过API)
- 本地模型
