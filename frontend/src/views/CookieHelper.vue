<template>
  <div class="cookie-helper-page">
    <!-- Cookie 状态卡片 -->
    <div class="status-section">
      <el-card class="status-card" :class="cookieStatusClass">
        <template #header>
          <div class="card-header">
            <el-icon :size="20"><Key /></el-icon>
            <span>Cookie 状态</span>
          </div>
        </template>
        
        <div class="status-content">
          <div class="status-indicator">
            <div class="indicator-dot" :class="cookieStatus"></div>
            <span class="status-text">{{ statusText }}</span>
          </div>
          
          <div v-if="cookieInfo.email" class="user-info">
            <el-icon><User /></el-icon>
            <span>{{ cookieInfo.email }}</span>
          </div>
          
          <div v-if="cookieInfo.expires" class="expires-info">
            <el-icon><Clock /></el-icon>
            <span>过期时间：{{ cookieInfo.expires }}</span>
          </div>
          
          <div v-if="lastValidateTime" class="validate-time">
            <el-icon><Timer /></el-icon>
            <span>最后验证：{{ lastValidateTime }}</span>
          </div>
        </div>
      </el-card>
    </div>

    <!-- 快捷操作 -->
    <div class="quick-actions">
      <el-card>
        <template #header>
          <div class="card-header">
            <el-icon :size="20"><Lightning /></el-icon>
            <span>快捷操作</span>
          </div>
        </template>
        
        <div class="action-buttons">
          <el-button type="primary" @click="openLogin" :loading="opening">
            <el-icon><Link /></el-icon>
            打开登录页
          </el-button>
          
          <el-button type="success" @click="testCookie" :loading="testing">
            <el-icon><Check /></el-icon>
            测试 Cookie
          </el-button>
          
          <el-button @click="copyScript">
            <el-icon><DocumentCopy /></el-icon>
            复制脚本
          </el-button>
          
          <el-button @click="showGuide = true">
            <el-icon><QuestionFilled /></el-icon>
            获取指南
          </el-button>
        </div>
      </el-card>
    </div>

    <!-- 控制台脚本 -->
    <div class="script-section">
      <el-card>
        <template #header>
          <div class="card-header">
            <el-icon :size="20"><Document /></el-icon>
            <span>浏览器控制台脚本</span>
          </div>
        </template>
        
        <div class="script-content">
          <el-alert
            title="使用方法"
            type="info"
            :closable="false"
            show-icon
            class="mb-sm"
          >
            1. 点击"打开登录页"登录 Monica<br>
            2. 按 F12 打开开发者工具，切换到 Console 标签<br>
            3. 点击下方"复制脚本"按钮<br>
            4. 在控制台粘贴并运行脚本<br>
            5. Cookie 会自动复制到剪贴板
          </el-alert>
          
          <el-input
            v-model="scriptContent"
            type="textarea"
            :rows="12"
            readonly
            class="script-input"
          />
          
          <div class="script-actions">
            <el-button @click="copyScript" size="default">
              <el-icon><DocumentCopy /></el-icon>
              复制脚本
            </el-button>
            
            <el-button @click="runScriptInNewTab" size="default">
              <el-icon><VideoPlay /></el-icon>
              在新标签页运行
            </el-button>
          </div>
        </div>
      </el-card>
    </div>

    <!-- 常见问题 -->
    <div class="faq-section">
      <el-card>
        <template #header>
          <div class="card-header">
            <el-icon :size="20"><ChatDotRound /></el-icon>
            <span>常见问题</span>
          </div>
        </template>
        
        <el-collapse accordion>
          <el-collapse-item title="Cookie 多久会过期？" name="1">
            <div>Cookie 通常有效期为 7-30 天，具体取决于 Monica 的安全策略。建议定期检查 Cookie 状态。</div>
          </el-collapse-item>
          
          <el-collapse-item title="如何知道 Cookie 已过期？" name="2">
            <div>当 API 请求返回 401 或 403 错误时，通常表示 Cookie 已过期。本应用也会在检测到过期时自动提醒您。</div>
          </el-collapse-item>
          
          <el-collapse-item title="Cookie 安全吗？" name="3">
            <div>Cookie 仅存储在您本地设备的配置文件中，不会上传到任何服务器。请妥善保管，不要分享给他人。</div>
          </el-collapse-item>
          
          <el-collapse-item title="可以在多个设备上使用吗？" name="4">
            <div>可以。您需要在每个设备上分别获取 Cookie。同一个账号的 Cookie 可以在多个设备同时使用。</div>
          </el-collapse-item>
        </el-collapse>
      </el-card>
    </div>

    <!-- 获取指南对话框 -->
    <el-dialog
      v-model="showGuide"
      title="如何获取 Monica Cookie"
      width="700px"
      top="5vh"
    >
      <div class="guide-content">
        <el-steps direction="vertical" :active="currentStep" finish-status="success">
          <el-step title="打开 Monica 官网" :description="guideSteps[0]">
            <template #icon>
              <el-button type="primary" size="small" @click="openLogin">
                <el-icon><Link /></el-icon>
                立即打开
              </el-button>
            </template>
          </el-step>
          
          <el-step title="登录账号" :description="guideSteps[1]" />
          
          <el-step title="打开开发者工具" :description="guideSteps[2]" />
          
          <el-step title="运行复制脚本" :description="guideSteps[3]">
            <template #icon>
              <el-button type="primary" size="small" @click="copyScript">
                <el-icon><DocumentCopy /></el-icon>
                复制脚本
              </el-button>
            </template>
          </el-step>
          
          <el-step title="粘贴 Cookie" :description="guideSteps[4]" />
          
          <el-step title="测试验证" :description="guideSteps[5]">
            <template #icon>
              <el-button type="success" size="small" @click="testCookie">
                <el-icon><Check /></el-icon>
                测试 Cookie
              </el-button>
            </template>
          </el-step>
        </el-steps>
        
        <el-alert
          title="安全提示"
          type="warning"
          :closable="false"
          show-icon
          class="mt-md"
        >
          <ul class="security-tips">
            <li>Cookie 包含您的账号认证信息，请勿分享给他人</li>
            <li>不要在公共电脑上使用此功能</li>
            <li>本应用仅将 Cookie 用于 API 请求，不会存储或上传</li>
          </ul>
        </el-alert>
      </div>
      
      <template #footer>
        <el-button @click="showGuide = false">关闭</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import {
  Key, User, Clock, Timer, Lightning, Link, Check, DocumentCopy,
  QuestionFilled, ChatDotRound, VideoPlay, Document
} from '@element-plus/icons-vue'
import {
  ValidateCookie, OpenMonicaLogin, GetCookieScript,
  GetCookieGuide, CheckCookieExpiry, FormatCookieForDisplay
} from '../../wailsjs/wailsjs/go/main/WailsApp.js'

const props = defineProps({
  currentCookie: {
    type: String,
    default: ''
  }
})

const emit = defineEmits(['update:cookie', 'validated'])

// 状态
const cookieStatus = ref('unknown') // unknown, valid, invalid, expired
const cookieInfo = reactive({
  email: '',
  expires: '',
  message: ''
})
const lastValidateTime = ref('')
const opening = ref(false)
const testing = ref(false)
const showGuide = ref(false)
const currentStep = ref(0)
const scriptContent = ref('')
const guideSteps = ref([])

// 计算属性
const cookieStatusClass = computed(() => {
  return `status-${cookieStatus.value}`
})

const statusText = computed(() => {
  const texts = {
    unknown: '未验证',
    valid: 'Cookie 有效',
    invalid: 'Cookie 无效',
    expired: 'Cookie 已过期'
  }
  return texts[cookieStatus.value] || '未知状态'
})

// 初始化
onMounted(async () => {
  // 加载脚本
  scriptContent.value = await GetCookieScript()
  
  // 加载指南
  const guide = await GetCookieGuide()
  if (guide.steps) {
    guideSteps.value = guide.steps.map(s => s.detail)
  }
  
  // 如果有 Cookie，自动检查是否过期
  if (props.currentCookie) {
    await checkExpiry()
  }
})

// 检查 Cookie 是否过期
async function checkExpiry() {
  if (!props.currentCookie) {
    cookieStatus.value = 'unknown'
    return
  }
  
  const result = await CheckCookieExpiry(props.currentCookie)
  if (result.maybe_expired) {
    cookieStatus.value = 'expired'
    cookieInfo.message = result.reason
  }
}

// 打开登录页
async function openLogin() {
  opening.value = true
  try {
    const result = await OpenMonicaLogin()
    if (result.success) {
      ElMessage.success(result.message)
      currentStep.value = 1
    } else {
      ElMessage.error(result.message)
    }
  } catch (error) {
    ElMessage.error('打开浏览器失败：' + (error?.message || error))
  } finally {
    opening.value = false
  }
}

// 测试 Cookie
async function testCookie() {
  if (!props.currentCookie) {
    ElMessage.warning('请先在配置中填写 Cookie')
    return
  }
  
  testing.value = true
  try {
    const result = await ValidateCookie(props.currentCookie)
    
    lastValidateTime.value = new Date().toLocaleString('zh-CN')
    
    if (result.success) {
      if (result.is_valid) {
        cookieStatus.value = 'valid'
        cookieInfo.email = result.user_email || ''
        cookieInfo.expires = result.expires_at || ''
        cookieInfo.message = result.message
        ElMessage.success(result.message)
        emit('validated', { valid: true, message: result.message })
      } else {
        cookieStatus.value = 'invalid'
        cookieInfo.message = result.message
        ElMessage.error(result.message)
        emit('validated', { valid: false, message: result.message })
      }
    } else {
      cookieStatus.value = 'unknown'
      ElMessage.error(result.message)
    }
  } catch (error) {
    cookieStatus.value = 'unknown'
    ElMessage.error('测试失败：' + (error?.message || error))
  } finally {
    testing.value = false
  }
}

// 复制脚本
async function copyScript() {
  try {
    await navigator.clipboard.writeText(scriptContent.value)
    ElMessage.success('脚本已复制到剪贴板')
    currentStep.value = 3
  } catch (error) {
    // 如果剪贴板失败，尝试使用旧方法
    const textarea = document.createElement('textarea')
    textarea.value = scriptContent.value
    textarea.style.position = 'fixed'
    textarea.style.opacity = '0'
    document.body.appendChild(textarea)
    textarea.select()
    try {
      document.execCommand('copy')
      ElMessage.success('脚本已复制到剪贴板')
    } catch (err) {
      ElMessage.error('复制失败，请手动复制')
    }
    document.body.removeChild(textarea)
  }
}

// 在新标签页运行脚本
function runScriptInNewTab() {
  const html = `
<!DOCTYPE html>
<html>
<head>
  <title>运行 Cookie 脚本</title>
  <style>
    body { font-family: Arial, sans-serif; padding: 20px; }
    .btn { padding: 10px 20px; font-size: 16px; cursor: pointer; }
  </style>
</head>
<body>
  <h2>运行 Cookie 复制脚本</h2>
  <p>请在下方输入框粘贴脚本，然后按 F12 打开控制台运行</p>
  <textarea id="script" style="width:100%;height:300px;font-family:monospace;">${scriptContent.value.replace(/</g, '&lt;')}</textarea>
  <br><br>
  <button class="btn" onclick="copyScript()">复制脚本</button>
  <button class="btn" onclick="window.close()">关闭</button>
  <script>
    function copyScript() {
      const script = document.getElementById('script').value;
      navigator.clipboard.writeText(script).then(() => {
        alert('脚本已复制！请粘贴到浏览器控制台运行。');
      });
    }
  <\/script>
</body>
</html>
  `
  
  const blob = new Blob([html], { type: 'text/html' })
  const url = URL.createObjectURL(blob)
  window.open(url, '_blank')
}
</script>

<style scoped>
.cookie-helper-page {
  padding: var(--spacing-sm);
  display: flex;
  flex-direction: column;
  gap: var(--spacing-md);
}

.status-section {
  margin-bottom: var(--spacing-sm);
}

.status-card {
  transition: all var(--transition-fast);
}

.status-card.status-valid {
  border-left: 4px solid var(--success-color);
}

.status-card.status-invalid {
  border-left: 4px solid var(--error-color);
}

.status-card.status-expired {
  border-left: 4px solid var(--warning-color);
}

.status-card.status-unknown {
  border-left: 4px solid var(--info-color);
}

.card-header {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  font-weight: var(--font-weight-medium);
}

.status-content {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-sm);
}

.status-indicator {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
}

.indicator-dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: var(--info-color);
}

.indicator-dot.valid {
  background: var(--success-color);
  box-shadow: 0 0 8px var(--success-color);
}

.indicator-dot.invalid {
  background: var(--error-color);
}

.indicator-dot.expired {
  background: var(--warning-color);
}

.indicator-dot.unknown {
  background: var(--info-color);
}

.status-text {
  font-weight: var(--font-weight-medium);
  font-size: var(--font-size-lg);
}

.user-info, .expires-info, .validate-time {
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
  color: var(--text-regular);
  font-size: var(--font-size-sm);
}

.quick-actions {
  margin-bottom: var(--spacing-sm);
}

.action-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: var(--spacing-sm);
}

.script-section {
  margin-bottom: var(--spacing-sm);
}

.script-content {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-sm);
}

.script-input {
  font-family: 'Monaco', 'Menlo', 'Courier New', monospace;
  font-size: var(--font-size-sm);
}

.script-actions {
  display: flex;
  gap: var(--spacing-sm);
}

.faq-section {
  margin-bottom: var(--spacing-sm);
}

.guide-content {
  padding: var(--spacing-sm) 0;
}

.security-tips {
  margin: 0;
  padding-left: var(--spacing-md);
}

.security-tips li {
  margin-bottom: var(--spacing-xs);
  color: var(--text-regular);
  font-size: var(--font-size-sm);
}

.mb-sm {
  margin-bottom: var(--spacing-sm);
}

.mt-md {
  margin-top: var(--spacing-md);
}
</style>
