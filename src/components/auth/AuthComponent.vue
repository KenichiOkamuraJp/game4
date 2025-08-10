<template>
  <div class="auth-container">
    <div class="auth-tabs">
      <button 
        @click="activeTab = 'login'"
        :class="['tab-btn', { active: activeTab === 'login' }]"
      >
        ログイン
      </button>
      <button 
        @click="activeTab = 'register'"
        :class="['tab-btn', { active: activeTab === 'register' }]"
      >
        新規登録
      </button>
    </div>
    
    <!-- ログインフォーム -->
    <form v-if="activeTab === 'login'" @submit.prevent="handleLogin" class="auth-form">
      <h2>ログイン</h2>
      
      <div class="form-group">
        <label>メールアドレス:</label>
        <input 
          v-model="loginForm.email"
          type="email"
          required
          class="form-input"
          :disabled="loading"
        />
      </div>
      
      <div class="form-group">
        <label>パスワード:</label>
        <input 
          v-model="loginForm.password"
          type="password"
          required
          class="form-input"
          :disabled="loading"
        />
      </div>
      
      <button type="submit" :disabled="loading" class="auth-btn">
        <span v-if="loading">認証中...</span>
        <span v-else>ログイン</span>
      </button>
      
      <div v-if="error" class="error-message">{{ error }}</div>
    </form>
    
    <!-- 新規登録フォーム -->
    <form v-if="activeTab === 'register'" @submit.prevent="handleRegister" class="auth-form">
      <h2>新規登録</h2>
      
      <div class="form-group">
        <label>メールアドレス:</label>
        <input 
          v-model="registerForm.email"
          type="email"
          required
          class="form-input"
          :disabled="loading"
        />
      </div>
      
      <div class="form-group">
        <label>パスワード:</label>
        <input 
          v-model="registerForm.password"
          type="password"
          required
          minlength="8"
          class="form-input"
          :disabled="loading"
        />
        <div class="password-hint">8文字以上、大文字・小文字・数字を含む</div>
      </div>
      
      <div class="form-group">
        <label>パスワード確認:</label>
        <input 
          v-model="registerForm.confirmPassword"
          type="password"
          required
          class="form-input"
          :disabled="loading"
        />
      </div>
      
      <button type="submit" :disabled="loading || !isValidPassword" class="auth-btn">
        <span v-if="loading">登録中...</span>
        <span v-else>新規登録</span>
      </button>
      
      <div v-if="error" class="error-message">{{ error }}</div>
    </form>
    
    <!-- 確認コード入力フォーム -->
    <form v-if="showConfirmation" @submit.prevent="handleConfirmation" class="auth-form">
      <h2>メール認証</h2>
      <p>登録したメールアドレスに確認コードを送信しました。</p>
      
      <div class="form-group">
        <label>確認コード:</label>
        <input 
          v-model="confirmationCode"
          type="text"
          required
          maxlength="6"
          class="form-input"
          :disabled="loading"
          placeholder="6桁の数字"
        />
      </div>
      
      <button type="submit" :disabled="loading" class="auth-btn">
        <span v-if="loading">確認中...</span>
        <span v-else>確認</span>
      </button>
      
      <button type="button" @click="resendCode" :disabled="loading" class="auth-btn secondary">
        確認コードを再送信
      </button>
      
      <div v-if="error" class="error-message">{{ error }}</div>
    </form>
  </div>
</template>

<script>
import { ref, computed } from 'vue'
import { authService } from '../../api/auth.js'

export default {
  name: 'AuthComponent',
  emits: ['authenticated'],
  
  setup(props, { emit }) {
    const activeTab = ref('login')
    const loading = ref(false)
    const error = ref('')
    const showConfirmation = ref(false)
    const confirmationCode = ref('')
    const pendingEmail = ref('')
    
    const loginForm = ref({
      email: '',
      password: ''
    })
    
    const registerForm = ref({
      email: '',
      password: '',
      confirmPassword: ''
    })
    
    const isValidPassword = computed(() => {
      const password = registerForm.value.password
      const confirmPassword = registerForm.value.confirmPassword
      
      if (password.length < 8) return false
      if (!/[A-Z]/.test(password)) return false
      if (!/[a-z]/.test(password)) return false
      if (!/[0-9]/.test(password)) return false
      if (password !== confirmPassword) return false
      
      return true
    })
    
    const clearError = () => {
      error.value = ''
    }
    
    const handleLogin = async () => {
      clearError()
      loading.value = true
      
      try {
        const user = await authService.signIn(
          loginForm.value.email,
          loginForm.value.password
        )
        
        emit('authenticated', user)
      } catch (err) {
        console.error('Login error:', err)
        
        if (err.code === 'UserNotConfirmedException') {
          error.value = 'メールアドレスが確認されていません。確認コードを入力してください。'
          pendingEmail.value = loginForm.value.email
          showConfirmation.value = true
        } else if (err.code === 'NotAuthorizedException') {
          error.value = 'メールアドレスまたはパスワードが正しくありません。'
        } else if (err.code === 'UserNotFoundException') {
          error.value = 'ユーザーが見つかりません。'
        } else {
          error.value = 'ログインに失敗しました。もう一度お試しください。'
        }
      } finally {
        loading.value = false
      }
    }
    
    const handleRegister = async () => {
      clearError()
      
      if (!isValidPassword.value) {
        error.value = 'パスワードの条件を満たしていません。'
        return
      }
      
      loading.value = true
      
      try {
        await authService.signUp(
          registerForm.value.email,
          registerForm.value.password
        )
        
        pendingEmail.value = registerForm.value.email
        showConfirmation.value = true
        error.value = ''
      } catch (err) {
        console.error('Registration error:', err)
        
        if (err.code === 'UsernameExistsException') {
          error.value = 'このメールアドレスは既に登録されています。'
        } else if (err.code === 'InvalidPasswordException') {
          error.value = 'パスワードが条件を満たしていません。'
        } else if (err.code === 'InvalidParameterException') {
          error.value = '入力内容に不備があります。'
        } else {
          error.value = '登録に失敗しました。もう一度お試しください。'
        }
      } finally {
        loading.value = false
      }
    }
    
    const handleConfirmation = async () => {
      clearError()
      
      if (!confirmationCode.value || confirmationCode.value.length !== 6) {
        error.value = '6桁の確認コードを入力してください。'
        return
      }
      
      loading.value = true
      
      try {
        await authService.confirmSignUp(
          pendingEmail.value,
          confirmationCode.value
        )
        
        // 確認後、自動ログイン
        const user = await authService.signIn(
          pendingEmail.value,
          activeTab.value === 'register' ? registerForm.value.password : loginForm.value.password
        )
        
        emit('authenticated', user)
      } catch (err) {
        console.error('Confirmation error:', err)
        
        if (err.code === 'CodeMismatchException') {
          error.value = '確認コードが正しくありません。'
        } else if (err.code === 'ExpiredCodeException') {
          error.value = '確認コードの有効期限が切れています。再送信してください。'
        } else {
          error.value = '確認に失敗しました。もう一度お試しください。'
        }
      } finally {
        loading.value = false
      }
    }
    
    const resendCode = async () => {
      clearError()
      loading.value = true
      
      try {
        await authService.resendConfirmationCode(pendingEmail.value)
        error.value = ''
        // 成功メッセージを一時的に表示
        const originalError = error.value
        error.value = '確認コードを再送信しました。'
        setTimeout(() => {
          if (error.value === '確認コードを再送信しました。') {
            error.value = originalError
          }
        }, 3000)
      } catch (err) {
        console.error('Resend code error:', err)
        error.value = '確認コードの再送信に失敗しました。'
      } finally {
        loading.value = false
      }
    }
    
    return {
      activeTab,
      loading,
      error,
      showConfirmation,
      confirmationCode,
      loginForm,
      registerForm,
      isValidPassword,
      handleLogin,
      handleRegister,
      handleConfirmation,
      resendCode
    }
  }
}
</script>

<style scoped>
.auth-container {
  background-color: #001a00;
  border: 2px solid #00ff00;
  border-radius: 10px;
  padding: 20px;
  margin: 0 auto;
}

.auth-tabs {
  display: flex;
  margin-bottom: 20px;
  border-bottom: 1px solid #00ff00;
}

.tab-btn {
  flex: 1;
  padding: 10px;
  background-color: transparent;
  color: #00ff00;
  border: none;
  border-bottom: 2px solid transparent;
  cursor: pointer;
  font-family: inherit;
  font-size: 16px;
  transition: all 0.3s;
}

.tab-btn:hover {
  background-color: #003300;
}

.tab-btn.active {
  border-bottom-color: #00ff00;
  background-color: #003300;
}

.auth-form {
  max-width: 400px;
  margin: 0 auto;
}

.auth-form h2 {
  text-align: center;
  color: #ffff00;
  margin-bottom: 20px;
}

.form-group {
  margin-bottom: 15px;
}

.form-group label {
  display: block;
  margin-bottom: 5px;
  color: #00ff00;
  font-weight: bold;
}

.form-input {
  width: 100%;
  padding: 10px;
  background-color: #001100;
  color: #00ff00;
  border: 2px solid #00ff00;
  border-radius: 5px;
  font-family: inherit;
  font-size: 14px;
  box-sizing: border-box;
}

.form-input:focus {
  outline: none;
  border-color: #ffff00;
  box-shadow: 0 0 5px rgba(255, 255, 0, 0.3);
}

.form-input:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.password-hint {
  font-size: 12px;
  color: #888;
  margin-top: 5px;
}

.auth-btn {
  width: 100%;
  padding: 12px;
  background-color: #003300;
  color: #00ff00;
  border: 2px solid #00ff00;
  border-radius: 5px;
  font-family: inherit;
  font-size: 16px;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.3s;
  margin-bottom: 10px;
}

.auth-btn:hover:not(:disabled) {
  background-color: #006600;
  box-shadow: 0 0 10px rgba(0, 255, 0, 0.3);
}

.auth-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.auth-btn.secondary {
  background-color: transparent;
  border-color: #666;
  color: #666;
}

.auth-btn.secondary:hover:not(:disabled) {
  background-color: #333;
  border-color: #00ff00;
  color: #00ff00;
}

.error-message {
  color: #ff4444;
  background-color: #330000;
  border: 1px solid #ff4444;
  border-radius: 5px;
  padding: 10px;
  margin-top: 10px;
  text-align: center;
  font-size: 14px;
}
</style>