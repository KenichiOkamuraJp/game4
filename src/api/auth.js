// AWS Cognito認証サービス
import {
  CognitoUserPool,
  CognitoUser,
  AuthenticationDetails,
  CognitoUserAttribute
} from 'amazon-cognito-identity-js'

// AWS設定
const poolData = {
  UserPoolId: import.meta.env.VITE_AWS_USER_POOL_ID,
  ClientId: import.meta.env.VITE_AWS_USER_POOL_CLIENT_ID
}

const userPool = new CognitoUserPool(poolData)

class AuthService {
  constructor() {
    this.currentUser = null
    this.accessToken = null
    this.idToken = null
  }

  /**
   * 新規ユーザー登録
   */
  async signUp(email, password) {
    return new Promise((resolve, reject) => {
      const attributeList = [
        new CognitoUserAttribute({
          Name: 'email',
          Value: email
        })
      ]

      userPool.signUp(email, password, attributeList, null, (err, result) => {
        if (err) {
          reject(err)
          return
        }
        resolve(result.user)
      })
    })
  }

  /**
   * メール確認
   */
  async confirmSignUp(email, confirmationCode) {
    return new Promise((resolve, reject) => {
      const cognitoUser = new CognitoUser({
        Username: email,
        Pool: userPool
      })

      cognitoUser.confirmRegistration(confirmationCode, true, (err, result) => {
        if (err) {
          reject(err)
          return
        }
        resolve(result)
      })
    })
  }

  /**
   * 確認コード再送信
   */
  async resendConfirmationCode(email) {
    return new Promise((resolve, reject) => {
      const cognitoUser = new CognitoUser({
        Username: email,
        Pool: userPool
      })

      cognitoUser.resendConfirmationCode((err, result) => {
        if (err) {
          reject(err)
          return
        }
        resolve(result)
      })
    })
  }

  /**
   * ログイン
   */
  async signIn(email, password) {
    return new Promise((resolve, reject) => {
      const authenticationDetails = new AuthenticationDetails({
        Username: email,
        Password: password
      })

      const cognitoUser = new CognitoUser({
        Username: email,
        Pool: userPool
      })

      cognitoUser.authenticateUser(authenticationDetails, {
        onSuccess: (result) => {
          this.currentUser = cognitoUser
          this.accessToken = result.getAccessToken().getJwtToken()
          this.idToken = result.getIdToken().getJwtToken()
          
          // ユーザー情報を取得
          cognitoUser.getUserAttributes((err, attributes) => {
            if (err) {
              console.error('Failed to get user attributes:', err)
            }
            
            const userInfo = {
              username: cognitoUser.getUsername(),
              email: email,
              accessToken: this.accessToken,
              idToken: this.idToken,
              refreshToken: result.getRefreshToken().getToken(),
              attributes: attributes || []
            }
            
            // ローカルストレージに保存
            this.saveUserSession(userInfo)
            
            resolve(userInfo)
          })
        },
        onFailure: (err) => {
          reject(err)
        },
        newPasswordRequired: (userAttributes, requiredAttributes) => {
          // 新しいパスワードが必要な場合（初回ログイン等）
          reject(new Error('New password required'))
        }
      })
    })
  }

  /**
   * ログアウト
   */
  async signOut() {
    return new Promise((resolve) => {
      if (this.currentUser) {
        this.currentUser.signOut()
      }
      
      this.currentUser = null
      this.accessToken = null
      this.idToken = null
      
      // ローカルストレージをクリア
      localStorage.removeItem('dungeon_rpg_user')
      
      resolve()
    })
  }

  /**
   * 現在のユーザーを取得
   */
  async getCurrentUser() {
    return new Promise((resolve, reject) => {
      // まずローカルストレージから確認
      const savedUser = this.getSavedUserSession()
      if (savedUser && savedUser.accessToken) {
        this.accessToken = savedUser.accessToken
        this.idToken = savedUser.idToken
        
        // 保存されたトークンが有効かどうかチェック
        try {
          // JWTトークンの有効期限をチェック（簡易版）
          const tokenPayload = this.parseJWT(savedUser.accessToken)
          if (tokenPayload && tokenPayload.exp * 1000 > Date.now()) {
            resolve(savedUser)
            return
          }
        } catch (error) {
          console.warn('Invalid saved token:', error)
        }
      }

      const cognitoUser = userPool.getCurrentUser()
      if (!cognitoUser) {
        reject(new Error('No current user'))
        return
      }

      cognitoUser.getSession((err, session) => {
        if (err) {
          reject(err)
          return
        }

        if (!session.isValid()) {
          reject(new Error('Session is not valid'))
          return
        }

        this.currentUser = cognitoUser
        this.accessToken = session.getAccessToken().getJwtToken()
        this.idToken = session.getIdToken().getJwtToken()

        cognitoUser.getUserAttributes((err, attributes) => {
          if (err) {
            reject(err)
            return
          }

          const userInfo = {
            username: cognitoUser.getUsername(),
            accessToken: this.accessToken,
            idToken: this.idToken,
            refreshToken: session.getRefreshToken().getToken(),
            attributes: attributes || []
          }

          this.saveUserSession(userInfo)
          resolve(userInfo)
        })
      })
    })
  }

  /**
   * JWTトークンをパース
   */
  parseJWT(token) {
    try {
      const base64Url = token.split('.')[1]
      const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/')
      const jsonPayload = decodeURIComponent(atob(base64).split('').map(function(c) {
        return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2)
      }).join(''))
      return JSON.parse(jsonPayload)
    } catch (error) {
      return null
    }
  }

  /**
   * アクセストークンを取得
   */
  getAccessToken() {
    return this.accessToken
  }

  /**
   * 認証状態をチェック
   */
  isAuthenticated() {
    if (!this.accessToken) {
      return false
    }
    
    try {
      const tokenPayload = this.parseJWT(this.accessToken)
      return tokenPayload && tokenPayload.exp * 1000 > Date.now()
    } catch {
      return false
    }
  }

  /**
   * 認証済みAPIリクエストヘッダーを取得
   */
  async getAuthHeaders() {
    if (!this.isAuthenticated()) {
      throw new Error('Not authenticated')
    }

    return {
      'Authorization': `Bearer ${this.accessToken}`,
      'Content-Type': 'application/json'
    }
  }

  /**
   * AWS IAM認証ヘッダーを生成
   */
  async getIAMHeaders() {
    if (!this.isAuthenticated()) {
      throw new Error('Not authenticated')
    }

  // 現在のユーザーセッションを確認
    const savedUser = this.getSavedUserSession()
    if (!savedUser || !savedUser.idToken) {
      throw new Error('Authentication session expired')
    }

    return {
      'Authorization': savedUser.idToken,
      'Content-Type': 'application/json'
    }
  }

  /**
   * セッション更新
   */
  async refreshSession() {
    return new Promise((resolve, reject) => {
      if (!this.currentUser) {
        reject(new Error('No current user'))
        return
      }

      this.currentUser.getSession((err, session) => {
        if (err) {
          reject(err)
          return
        }

        if (session.isValid()) {
          this.accessToken = session.getAccessToken().getJwtToken()
          this.idToken = session.getIdToken().getJwtToken()
          resolve(session)
        } else {
          reject(new Error('Session is not valid'))
        }
      })
    })
  }

  /**
   * ユーザーセッションを保存
   */
  saveUserSession(userInfo) {
    try {
      localStorage.setItem('dungeon_rpg_user', JSON.stringify({
        username: userInfo.username,
        email: userInfo.email,
        accessToken: userInfo.accessToken,
        idToken: userInfo.idToken,  // これを追加
        savedAt: Date.now()
      }))
    } catch (error) {
      console.warn('Failed to save user session:', error)
    }
  }
  /**
   * 保存されたユーザーセッションを取得
   */
  getSavedUserSession() {
    try {
      const saved = localStorage.getItem('dungeon_rpg_user')
      if (!saved) return null

      const userInfo = JSON.parse(saved)
      
      // 24時間以上古い場合は無効とする
      if (Date.now() - userInfo.savedAt > 24 * 60 * 60 * 1000) {
        localStorage.removeItem('dungeon_rpg_user')
        return null
      }

      return userInfo
    } catch (error) {
      console.warn('Failed to get saved user session:', error)
      return null
    }
  }

  /**
   * パスワードリセット
   */
  async forgotPassword(email) {
    return new Promise((resolve, reject) => {
      const cognitoUser = new CognitoUser({
        Username: email,
        Pool: userPool
      })

      cognitoUser.forgotPassword({
        onSuccess: (result) => {
          resolve(result)
        },
        onFailure: (err) => {
          reject(err)
        }
      })
    })
  }

  /**
   * パスワードリセット確認
   */
  async confirmPassword(email, confirmationCode, newPassword) {
    return new Promise((resolve, reject) => {
      const cognitoUser = new CognitoUser({
        Username: email,
        Pool: userPool
      })

      cognitoUser.confirmPassword(confirmationCode, newPassword, {
        onSuccess: () => {
          resolve()
        },
        onFailure: (err) => {
          reject(err)
        }
      })
    })
  }

  /**
   * ユーザー属性更新
   */
  async updateUserAttributes(attributes) {
    return new Promise((resolve, reject) => {
      if (!this.currentUser) {
        reject(new Error('Not authenticated'))
        return
      }

      const attributeList = attributes.map(attr => 
        new CognitoUserAttribute(attr)
      )

      this.currentUser.updateAttributes(attributeList, (err, result) => {
        if (err) {
          reject(err)
          return
        }
        resolve(result)
      })
    })
  }
}

// シングルトンインスタンスをエクスポート
export const authService = new AuthService()

// デフォルトエクスポート
export default authService