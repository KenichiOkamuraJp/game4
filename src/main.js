import { createApp } from 'vue'
import App from './App.vue'

// グローバルスタイル
import './style.css'

const app = createApp(App)

// エラーハンドリング
app.config.errorHandler = (err, instance, info) => {
  console.error('Vue Error:', err)
  console.error('Error Info:', info)
}

// パフォーマンス測定（開発環境のみ）
if (import.meta.env.DEV) {
  app.config.performance = true
}

// アプリケーションマウント
app.mount('#app')