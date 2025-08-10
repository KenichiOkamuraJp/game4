import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  server: {
    port: 5173,
    host: true,
    open: true,
    // プロキシ設定（必要に応じて）
    proxy: {
      // AWS API Gatewayへのプロキシ（開発時のCORS回避用）
      '/api': {
        target: process.env.VITE_AWS_API_ENDPOINT || 'http://localhost:3000',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, '')
      }
    }
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    minify: 'terser',
    sourcemap: false,
    // チャンクサイズ警告の閾値を増やす
    chunkSizeWarningLimit: 1000,
    rollupOptions: {
      output: {
        // チャンク分割の設定
        manualChunks: {
          'aws-cognito': ['amazon-cognito-identity-js'],
          'vue-vendor': ['vue']
        }
      }
    }
  },
  define: {
    // 環境変数の定義
    __VUE_OPTIONS_API__: true,
    __VUE_PROD_DEVTOOLS__: false,
    __APP_VERSION__: JSON.stringify(process.env.npm_package_version)
  }
})