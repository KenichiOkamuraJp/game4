<template>
  <div id="app">
    <!-- ローディング画面 -->
    <div v-if="loading" class="loading-screen">
      <div class="loading-content">
        <div class="loading-spinner">⚔️</div>
        <h2>ダンジョンRPG</h2>
        <p>読み込み中...</p>
      </div>
    </div>

    <!-- メインコンテンツ -->
    <div v-else class="app-content">
      <!-- 認証画面 -->
      <AuthComponent 
        v-if="currentScreen === 'auth'" 
        @authenticated="handleAuthenticated"
      />

      <!-- キャラクター作成画面 -->
      <CharacterCreation 
        v-if="currentScreen === 'character-creation'"
        @character-created="handleCharacterCreated"
        @character-selected="handleCharacterSelected"
      />

      <!-- 町画面 -->
      <TownScreen 
        v-if="currentScreen === 'town'"
        :character="selectedCharacter"
        @enter-dungeon="handleEnterDungeon"
        @enter-guild="handleEnterGuild"
        @character-updated="handleCharacterUpdated"
      />

      <!-- ギルド画面 -->
      <GuildScreen 
        v-if="currentScreen === 'guild'"
        :character="selectedCharacter"
        @leave-guild="handleLeaveGuild"
        @character-updated="handleCharacterUpdated"
      />

      <!-- ダンジョン画面 -->
      <DungeonView 
        v-if="currentScreen === 'dungeon'"
        :character="selectedCharacter"
        :game-progress="gameProgress"
        @combat-start="handleCombatStart"
        @victory="handleVictory"
        @game-progress-updated="handleGameProgressUpdated"
        @character-updated="handleCharacterUpdated"
        @return-to-town="handleReturnToTown"
      />

      <!-- 戦闘画面 -->
      <CombatScreen 
        v-if="currentScreen === 'combat'"
        :character="selectedCharacter"
        :enemy="currentEnemy"
        @combat-end="handleCombatEnd"
        @character-updated="handleCharacterUpdated"
      />

      <!-- 勝利画面 -->
      <VictoryScreen 
        v-if="currentScreen === 'victory'"
        :reward="victoryReward"
        :character="selectedCharacter"
        :game-stats="gameStats"
        @return-to-town="handleReturnToTown"
      />

      <!-- ゲームオーバー画面 -->
      <GameOverScreen 
        v-if="currentScreen === 'game-over'"
        :character="selectedCharacter"
        :game-stats="gameStats"
        @restart="handleRestart"
        @return-to-town="handleReturnToTown"
      />

      <!-- エラーメッセージ -->
      <div v-if="error" class="error-overlay">
        <div class="error-content">
          <h3>エラー</h3>
          <p>{{ error }}</p>
          <button @click="clearError" class="error-btn">閉じる</button>
        </div>
      </div>
    </div>

    <!-- デバッグ情報（開発時のみ） -->
    <div v-if="showDebugInfo" class="debug-info">
      <h4>Debug Info</h4>
      <div>Screen: {{ currentScreen }}</div>
      <div>Authenticated: {{ isAuthenticated }}</div>
      <div>Character: {{ selectedCharacter?.name || 'None' }}</div>
      <div>Characters Count: {{ characters.length }}</div>
    </div>
  </div>
</template>

<script>
import { ref, reactive, onMounted, computed } from 'vue'
import { authService } from './api/auth.js'
import { charactersAPI } from './api/characters.js'
import { savesAPI } from './api/saves.js'

// コンポーネントのインポート
import AuthComponent from './components/auth/AuthComponent.vue'
import CharacterCreation from './components/game/CharacterCreation.vue'
import TownScreen from './components/game/TownScreen.vue'
import GuildScreen from './components/game/GuildScreen.vue'
import DungeonView from './components/game/DungeonView.vue'
import CombatScreen from './components/game/CombatScreen.vue'
import VictoryScreen from './components/game/VictoryScreen.vue'
import GameOverScreen from './components/game/GameOverScreen.vue'

export default {
  name: 'App',
  components: {
    AuthComponent,
    CharacterCreation,
    TownScreen,
    GuildScreen,
    DungeonView,
    CombatScreen,
    VictoryScreen,
    GameOverScreen
  },
  
  setup() {
    // リアクティブデータ
    const isAuthenticated = ref(false)
    const user = ref(null)
    const characters = ref([])
    const selectedCharacter = ref(null)
    const loading = ref(true)
    const error = ref('')
    const currentScreen = ref('auth')
    const showDebugInfo = ref(import.meta.env.DEV) // 開発時のみ
    
    // ゲーム関連の状態
    const gameProgress = ref(null)
    const currentEnemy = ref(null)
    const victoryReward = ref(null)
    const gameStats = reactive({
      startTime: null,
      defeatedEnemies: 0,
      usedPotions: 0,
      openedChests: 0,
      reachedFloor: 1,
      deathCause: null
    })
    
    // 計算プロパティ
    const canShowGame = computed(() => {
      return isAuthenticated.value && selectedCharacter.value
    })
    
    // エラー管理
    const clearError = () => {
      error.value = ''
    }
    
    const setError = (message) => {
      error.value = message
      console.error('App Error:', message)
    }
    
    // 認証チェック（修正版）
    const checkAuthentication = async () => {
      try {
        loading.value = true
        error.value = ''
        
        console.log('Checking authentication...')
        
        // 認証状態をチェック
        if (!authService.isAuthenticated()) {
          // 保存されたセッションから復元を試行
          try {
            const savedUser = await authService.getCurrentUser()
            if (savedUser) {
              user.value = savedUser
              isAuthenticated.value = true
              
              console.log('Restored user session:', savedUser)
              
              // 認証成功後にデータを読み込み
              await loadUserData()
              return
            }
          } catch (err) {
            console.log('No saved session found:', err.message)
          }
        } else {
          // 既に認証済みの場合
          if (!user.value) {
            try {
              const currentUser = await authService.getCurrentUser()
              user.value = currentUser
            } catch (err) {
              console.error('Failed to get current user:', err)
              // 認証エラーの場合はログアウト状態にする
              await authService.signOut()
              isAuthenticated.value = false
              user.value = null
              currentScreen.value = 'auth'
              return
            }
          }
          
          isAuthenticated.value = true
          await loadUserData()
          return
        }
        
        // 認証されていない場合
        isAuthenticated.value = false
        currentScreen.value = 'auth'
        
      } catch (err) {
        console.error('Authentication check failed:', err)
        setError('認証チェックに失敗しました')
        isAuthenticated.value = false
        currentScreen.value = 'auth'
      } finally {
        loading.value = false
      }
    }
    
    // ユーザーデータ読み込み（修正版）
    const loadUserData = async () => {
      try {
        // 認証状態を再確認
        if (!authService.isAuthenticated()) {
          throw new Error('認証が必要です')
        }
        
        console.log('Loading user data...')
        
        // キャラクター一覧を取得
        const userCharacters = await charactersAPI.list()
        characters.value = userCharacters || []
        
        console.log('Loaded characters:', userCharacters)
        
        // キャラクターが存在する場合は選択、なければキャラクター作成画面へ
        if (characters.value.length > 0) {
          selectedCharacter.value = characters.value[0]
          currentScreen.value = 'town'
        } else {
          currentScreen.value = 'character-creation'
        }
        
      } catch (err) {
        console.error('Failed to load user data:', err)
        
        // 認証エラーの場合
        if (err.message.includes('認証') || err.message.includes('Not authenticated')) {
          setError('認証の有効期限が切れました。再度ログインしてください。')
          await authService.signOut()
          isAuthenticated.value = false
          user.value = null
          currentScreen.value = 'auth'
        } else {
          // その他のエラー - キャラクター作成画面に遷移
          console.log('No characters found, showing character creation')
          currentScreen.value = 'character-creation'
        }
      }
    }
    
    // 認証成功ハンドラー
    const handleAuthenticated = async (userData) => {
      try {
        user.value = userData
        isAuthenticated.value = true
        error.value = ''
        
        console.log('Authentication successful:', userData)
        
        // 認証成功後にデータを読み込み
        await loadUserData()
        
      } catch (err) {
        console.error('Post-authentication setup failed:', err)
        setError('ログイン後の初期化に失敗しました')
      }
    }
    
    // キャラクター作成ハンドラー
    const handleCharacterCreated = async (character) => {
      try {
        characters.value.push(character)
        selectedCharacter.value = character
        currentScreen.value = 'town'
        error.value = ''
        
        console.log('Character created:', character)
        
      } catch (err) {
        console.error('Character creation handler failed:', err)
        setError('キャラクター作成の処理に失敗しました')
      }
    }
    
    // キャラクター選択ハンドラー
    const handleCharacterSelected = (character) => {
      selectedCharacter.value = character
      currentScreen.value = 'town'
      error.value = ''
      
      console.log('Character selected:', character)
    }
    
    // キャラクター更新ハンドラー
    const handleCharacterUpdated = (updatedCharacter) => {
      selectedCharacter.value = updatedCharacter
      
      // キャラクター一覧も更新
      const index = characters.value.findIndex(char => char.id === updatedCharacter.id)
      if (index !== -1) {
        characters.value[index] = updatedCharacter
      }
      
      console.log('Character updated:', updatedCharacter)
    }
    
    // ダンジョン進入ハンドラー
    const handleEnterDungeon = async () => {
      try {
        // セーブデータを取得または作成
        let saveData = await savesAPI.get(selectedCharacter.value.id)
        
        if (!saveData) {
          // 新しいセーブデータを作成
          saveData = savesAPI.createDefaultSaveData(selectedCharacter.value)
          await savesAPI.create(saveData)
        }
        
        gameProgress.value = saveData
        gameStats.startTime = Date.now()
        gameStats.defeatedEnemies = 0
        gameStats.usedPotions = 0
        gameStats.openedChests = 0
        gameStats.reachedFloor = saveData.currentFloor
        gameStats.deathCause = null
        
        currentScreen.value = 'dungeon'
        
        console.log('Entered dungeon with save data:', saveData)
        
      } catch (err) {
        console.error('Failed to enter dungeon:', err)
        setError('ダンジョンへの進入に失敗しました')
      }
    }
    
    // ギルド進入ハンドラー
    const handleEnterGuild = () => {
      currentScreen.value = 'guild'
    }
    
    // ギルド退出ハンドラー
    const handleLeaveGuild = () => {
      currentScreen.value = 'town'
    }
    
    // ゲーム進行更新ハンドラー
    const handleGameProgressUpdated = async (updatedProgress) => {
      try {
        gameProgress.value = updatedProgress
        
        // セーブデータを更新
        await savesAPI.update(selectedCharacter.value.id, updatedProgress)
        
        console.log('Game progress updated:', updatedProgress)
        
      } catch (err) {
        console.error('Failed to update game progress:', err)
        setError('ゲーム進行の保存に失敗しました')
      }
    }
    
    // 戦闘開始ハンドラー
    const handleCombatStart = (enemy) => {
      currentEnemy.value = enemy
      currentScreen.value = 'combat'
      
      console.log('Combat started against:', enemy)
    }
    
    // 戦闘終了ハンドラー
    const handleCombatEnd = async (result) => {
      try {
        if (result.victory) {
          // 勝利の場合
          gameStats.defeatedEnemies++
          currentScreen.value = 'dungeon'
          
          // キャラクターを更新（経験値・ゴールド獲得済み）
          const updatedCharacter = await charactersAPI.update(
            selectedCharacter.value.id, 
            selectedCharacter.value
          )
          selectedCharacter.value = updatedCharacter
          
        } else if (result.fled) {
          // 逃走の場合
          currentScreen.value = 'dungeon'
          
        } else {
          // 敗北の場合
          gameStats.deathCause = 'combat'
          currentScreen.value = 'game-over'
        }
        
        currentEnemy.value = null
        
      } catch (err) {
        console.error('Combat end handler failed:', err)
        setError('戦闘結果の処理に失敗しました')
      }
    }
    
    // 勝利ハンドラー
    const handleVictory = async (reward) => {
      try {
        victoryReward.value = reward
        
        // キャラクターに報酬を追加
        const updatedCharacter = charactersAPI.gainExpAndGold(
          selectedCharacter.value, 
          reward.exp, 
          reward.gold
        )
        
        // キャラクターを更新
        const result = await charactersAPI.update(updatedCharacter.id, updatedCharacter)
        selectedCharacter.value = result
        
        currentScreen.value = 'victory'
        
        console.log('Victory! Reward:', reward)
        
      } catch (err) {
        console.error('Victory handler failed:', err)
        setError('勝利報酬の処理に失敗しました')
      }
    }
    
    // 町に戻るハンドラー
    const handleReturnToTown = () => {
      currentScreen.value = 'town'
      gameProgress.value = null
      currentEnemy.value = null
      victoryReward.value = null
      
      // ゲーム統計をリセット
      gameStats.startTime = null
      gameStats.defeatedEnemies = 0
      gameStats.usedPotions = 0
      gameStats.openedChests = 0
      gameStats.reachedFloor = 1
      gameStats.deathCause = null
    }
    
    // リスタートハンドラー
    const handleRestart = () => {
      handleReturnToTown()
      handleEnterDungeon()
    }
    
    // 初期化
    onMounted(async () => {
      console.log('App mounted, checking authentication...')
      await checkAuthentication()
    })
    
    return {
      // 状態
      isAuthenticated,
      user,
      characters,
      selectedCharacter,
      loading,
      error,
      currentScreen,
      showDebugInfo,
      gameProgress,
      currentEnemy,
      victoryReward,
      gameStats,
      
      // 計算プロパティ
      canShowGame,
      
      // メソッド
      clearError,
      handleAuthenticated,
      handleCharacterCreated,
      handleCharacterSelected,
      handleCharacterUpdated,
      handleEnterDungeon,
      handleEnterGuild,
      handleLeaveGuild,
      handleGameProgressUpdated,
      handleCombatStart,
      handleCombatEnd,
      handleVictory,
      handleReturnToTown,
      handleRestart,
      loadUserData,
      checkAuthentication
    }
  }
}
</script>

<style scoped>
#app {
  min-height: 100vh;
  background-color: #000;
  color: #00ff00;
  font-family: 'Courier New', monospace;
}

.loading-screen {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #001100, #003300, #001100);
}

.loading-content {
  text-align: center;
  background-color: #001a00;
  border: 2px solid #00ff00;
  border-radius: 10px;
  padding: 40px;
  box-shadow: 0 0 20px rgba(0, 255, 0, 0.3);
}

.loading-spinner {
  font-size: 48px;
  animation: spin 2s linear infinite;
  margin-bottom: 20px;
}

.loading-content h2 {
  color: #ffff00;
  margin-bottom: 10px;
  font-size: 24px;
}

.loading-content p {
  color: #888;
  margin: 0;
}

.app-content {
  min-height: 100vh;
}

.error-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.8);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
}

.error-content {
  background-color: #330000;
  border: 2px solid #ff4444;
  border-radius: 10px;
  padding: 30px;
  max-width: 400px;
  text-align: center;
}

.error-content h3 {
  color: #ff4444;
  margin-bottom: 15px;
}

.error-content p {
  color: #fff;
  margin-bottom: 20px;
  line-height: 1.5;
}

.error-btn {
  background-color: #ff4444;
  color: #fff;
  border: none;
  border-radius: 5px;
  padding: 10px 20px;
  font-family: inherit;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.3s;
}

.error-btn:hover {
  background-color: #ff6666;
  box-shadow: 0 0 10px rgba(255, 68, 68, 0.5);
}

.debug-info {
  position: fixed;
  top: 10px;
  right: 10px;
  background-color: rgba(0, 0, 0, 0.8);
  border: 1px solid #666;
  border-radius: 5px;
  padding: 10px;
  font-size: 12px;
  color: #888;
  z-index: 1000;
}

.debug-info h4 {
  color: #00ff00;
  margin: 0 0 5px 0;
  font-size: 14px;
}

.debug-info div {
  margin-bottom: 3px;
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

/* レスポンシブ対応 */
@media (max-width: 768px) {
  .loading-content {
    margin: 20px;
    padding: 30px;
  }
  
  .error-content {
    margin: 20px;
    padding: 20px;
  }
  
  .debug-info {
    top: 5px;
    right: 5px;
    font-size: 10px;
    padding: 5px;
  }
}
</style>