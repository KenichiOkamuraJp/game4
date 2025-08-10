// API Utilities
import { authService } from './auth.js'

/**
 * AWS IAM認証を使用したAPIリクエスト
 */
export async function apiRequest(url, options = {}) {
  const defaultOptions = {
    headers: {
      'Content-Type': 'application/json'
    }
  }

  // オプションをマージ
  const finalOptions = {
    ...defaultOptions,
    ...options,
    headers: {
      ...defaultOptions.headers,
      ...options.headers
    }
  }

  try {
    const response = await fetch(url, finalOptions)

    // レスポンスの詳細をログ出力（開発時のデバッグ用）
    if (process.env.NODE_ENV === 'development') {
      console.log(`API Request: ${finalOptions.method || 'GET'} ${url}`)
      console.log('Response status:', response.status)
    }

    // 認証エラーの場合
    if (response.status === 401 || response.status === 403) {
      throw new APIError('認証が必要です', response.status, response)
    }

    // レスポンスが成功でない場合
    if (!response.ok) {
      let errorMessage = `HTTP Error: ${response.status}`
      let errorData = null

      try {
        errorData = await response.json()
        errorMessage = errorData.error || errorData.message || errorMessage
      } catch {
        // JSONパースに失敗した場合はテキストを取得
        try {
          errorMessage = await response.text() || errorMessage
        } catch {
          // テキストも取得できない場合はステータスコードのみ
        }
      }

      throw new APIError(errorMessage, response.status, response, errorData)
    }

    // レスポンスボディがある場合はJSONとしてパース
    const contentType = response.headers.get('content-type')
    if (contentType && contentType.includes('application/json')) {
      const data = await response.json()
      return data
    }

    // JSONでない場合はテキストとして返す
    return await response.text()

  } catch (error) {
    if (error instanceof APIError) {
      throw error
    }

    // ネットワークエラーなど
    console.error('API Request failed:', error)
    throw new APIError(
      'ネットワークエラーが発生しました。接続を確認してください。',
      0,
      null,
      error
    )
  }
}

/**
 * AWS Signature Version 4 認証ヘッダーを生成
 * （簡略化版 - 実際のプロダクションではAWS SDKを使用）
 */
export async function generateAWSAuthHeaders(method, url, body = null) {
  try {
    const user = await authService.getCurrentUser()
    if (!user) {
      throw new Error('Not authenticated')
    }

    // 簡略化されたIAM認証ヘッダー
    // 実際のプロダクションでは、AWS SDK for JavaScript v3の
    // AWS Signature Version 4実装を使用することを推奨
    
    return {
      'Authorization': user.idToken,
      'Content-Type': 'application/json',
      'X-Amz-Date': new Date().toISOString().replace(/[:\-]|\.\d{3}/g, ''),
      'X-Amz-Security-Token': user.accessToken
    }
  } catch (error) {
    console.error('Failed to generate AWS auth headers:', error)
    throw new Error('認証ヘッダーの生成に失敗しました')
  }
}

/**
 * リクエストのリトライ処理
 */
export async function retryRequest(requestFn, maxRetries = 3, baseDelay = 1000) {
  let lastError

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await requestFn()
    } catch (error) {
      lastError = error

      // 認証エラーやクライアントエラーはリトライしない
      if (error instanceof APIError) {
        if (error.status >= 400 && error.status < 500) {
          throw error
        }
      }

      // 最後の試行でない場合は待機
      if (attempt < maxRetries) {
        const delay = baseDelay * Math.pow(2, attempt - 1) // 指数バックオフ
        await new Promise(resolve => setTimeout(resolve, delay))
        console.log(`API request retry ${attempt}/${maxRetries} after ${delay}ms`)
      }
    }
  }

  throw lastError
}

/**
 * APIエラークラス
 */
export class APIError extends Error {
  constructor(message, status = 0, response = null, data = null) {
    super(message)
    this.name = 'APIError'
    this.status = status
    this.response = response
    this.data = data
  }

  /**
   * ユーザーフレンドリーなエラーメッセージを取得
   */
  getUserMessage() {
    switch (this.status) {
      case 400:
        return this.message || 'リクエストに問題があります'
      case 401:
        return '認証が必要です。ログインしてください。'
      case 403:
        return 'アクセス権限がありません'
      case 404:
        return 'データが見つかりません'
      case 429:
        return 'リクエストが多すぎます。しばらく待ってからお試しください。'
      case 500:
        return 'サーバーエラーが発生しました'
      case 502:
      case 503:
      case 504:
        return 'サーバーが一時的に利用できません'
      default:
        return this.message || 'エラーが発生しました'
    }
  }

  /**
   * エラーがリトライ可能かチェック
   */
  isRetryable() {
    // 5xx系エラーとネットワークエラーはリトライ可能
    return this.status >= 500 || this.status === 0
  }
}

/**
 * キャッシュ機能付きAPIリクエスト
 */
class APICache {
  constructor(ttl = 5 * 60 * 1000) { // デフォルト5分
    this.cache = new Map()
    this.ttl = ttl
  }

  /**
   * キャッシュキーを生成
   */
  generateKey(url, options) {
    const method = options.method || 'GET'
    const body = options.body || ''
    return `${method}:${url}:${body}`
  }

  /**
   * キャッシュから取得
   */
  get(url, options) {
    const key = this.generateKey(url, options)
    const cached = this.cache.get(key)

    if (!cached) return null

    // TTLチェック
    if (Date.now() - cached.timestamp > this.ttl) {
      this.cache.delete(key)
      return null
    }

    return cached.data
  }

  /**
   * キャッシュに保存
   */
  set(url, options, data) {
    const key = this.generateKey(url, options)
    this.cache.set(key, {
      data,
      timestamp: Date.now()
    })
  }

  /**
   * キャッシュをクリア
   */
  clear() {
    this.cache.clear()
  }

  /**
   * 期限切れのキャッシュを削除
   */
  cleanup() {
    const now = Date.now()
    for (const [key, value] of this.cache.entries()) {
      if (now - value.timestamp > this.ttl) {
        this.cache.delete(key)
      }
    }
  }
}

// グローバルキャッシュインスタンス
const apiCache = new APICache()

/**
 * キャッシュ機能付きAPIリクエスト
 */
export async function cachedApiRequest(url, options = {}, useCache = true) {
  // GETリクエストのみキャッシュ
  const method = options.method || 'GET'
  if (!useCache || method !== 'GET') {
    return apiRequest(url, options)
  }

  // キャッシュから取得試行
  const cached = apiCache.get(url, options)
  if (cached) {
    return cached
  }

  // キャッシュミス - APIから取得
  const data = await apiRequest(url, options)
  apiCache.set(url, options, data)

  return data
}

/**
 * フォームデータをJSONに変換
 */
export function formDataToJSON(formData) {
  const object = {}
  for (const [key, value] of formData.entries()) {
    // 配列の処理
    if (object[key]) {
      if (!Array.isArray(object[key])) {
        object[key] = [object[key]]
      }
      object[key].push(value)
    } else {
      object[key] = value
    }
  }
  return object
}

/**
 * URLクエリパラメータを構築
 */
export function buildQueryString(params) {
  const searchParams = new URLSearchParams()
  
  for (const [key, value] of Object.entries(params)) {
    if (value !== null && value !== undefined) {
      if (Array.isArray(value)) {
        value.forEach(item => searchParams.append(key, item))
      } else {
        searchParams.append(key, value)
      }
    }
  }
  
  return searchParams.toString()
}

/**
 * APIレスポンスのタイムスタンプを日本語形式に変換
 */
export function formatTimestamp(timestamp) {
  try {
    const date = new Date(timestamp)
    return date.toLocaleString('ja-JP', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    })
  } catch {
    return timestamp
  }
}

/**
 * デバッグ情報を出力
 */
export function debugLog(message, data = null) {
  if (process.env.NODE_ENV === 'development') {
    console.log(`[API Debug] ${message}`, data)
  }
}

// 定期的なキャッシュクリーンアップ
setInterval(() => {
  apiCache.cleanup()
}, 10 * 60 * 1000) // 10分ごと