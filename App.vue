<template>
  <div id="app">
    <div class="game-container">
      <h1 class="title">🏰 ダンジョンクエスト 🏰</h1>
      
      <!-- ローディング画面 -->
      <div v-if="loading" class="loading-screen">
        <div class="loading-text">読み込み中...</div>
      </div>
      
      <!-- 認証画面 -->
      <div v-else-if="!isAuthenticated" class="auth-screen">
        <AuthComponent @authenticated="onAuthenticated" />
      </div>
      
      <!-- ゲーム画面 -->
      <div v-else>
        <!-- キャラクター作成画面 -->
        <CharacterCreation 
          v-if="gameState === 'character-creation'" 
          @character-created="onCharacterCreated"
          @character-selected="onCharacterSelected"
        />
        
        <!-- 町画面 -->
        <TownScreen 
          v-else-if="gameState === 'town'" 
          :character="currentCharacter"
          @enter-dungeon="enterDungeon"
          @enter-guild="enterGuild"
          @character-updated="onCharacterUpdated"
        />
        
        <!-- ギルド画面 -->
        <GuildScreen 
          v-else-if="gameState === 'guild'"
          :character="currentCharacter"
          @leave-guild="leaveGuild"
          @character-updated="onCharacterUpdated"
        />
        
        <!-- ダンジョン探索画面 -->
        <DungeonView 
          v-else-if="gameState === 'playing'"
          :character="currentCharacter"
          :game-progress="gameProgress"
          @combat-start="startCombat"
          @victory="onVictory"
          @game-progress-updated="onGameProgressUpdated"
          @character-updated="onCharacterUpdated"
          @return-to-town="returnToTown"
        />
        
        <!-- 戦闘画面 -->
        <CombatScreen 
          v-else-if="gameState === 'combat'"
          :character="currentCharacter"
          :enemy="currentEnemy"
          @combat-end="endCombat"
          @character-updated="onCharacterUpdated"
        />
        
        <!-- 勝利画面 -->
        <VictoryScreen 
          v-else-if="gameState === 'victory'"
          :reward="lastReward"
          @return-to-town="returnToTown"
        />
        
        <!-- ゲームオーバー画面 -->
        <GameOverScreen 
          v-else-if="gameState === 'game-over'"
          @restart="resetGame"
        />
      </div>
    </div>
  </div>
</template>

<script>
import { ref, reactive, onMounted, watch } from 'vue'
import AuthComponent from './components/auth/AuthComponent.vue'
import CharacterCreation from './components/game/CharacterCreation.vue'
import TownScreen from './components/game/TownScreen.vue'
import GuildScreen from './components/game/GuildScreen.vue'
import DungeonView from './components/game/DungeonView.vue'
import CombatScreen from './components/game/CombatScreen.vue'
import VictoryScreen from './components/game/VictoryScreen.vue'
import GameOverScreen from './components/game/GameOverScreen.vue'
import { authService } from './api/auth.js'
import { charactersAPI } from './api/characters.js'
import { savesAPI } from './api/saves.js'

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
    const loading = ref(true)
    const isAuthenticated = ref(false)
    const gameState = ref('character-creation')
    const currentCharacter = ref(null)
    const currentEnemy = ref(null)
    const lastReward = ref({ gold: 0, exp: 0 })
    
    // ゲーム進行状況
    const gameProgress = reactive({
      currentFloor: 1,
      playerX: 1,
      playerY: 6,
      potions: 3,
      keys: 0,
      doorStates: {},
      chestStates: {},
      playerPositions: {
        1: { x: 1, y: 6 },
        2: { x: 1, y: 1 },
        3: { x: 1, y: 1 }
      },
      messages: []
    })
    
    // 初期化
    onMounted(async () => {
      try {
        // 認証状態確認
        const user = await authService.getCurrentUser()
        if (user) {
          isAuthenticated.value = true
          await loadUserData()
        }
      } catch (error) {
        console.log('User not authenticated:', error)
      } finally {
        loading.value = false
      }
    })
    
    // 認証関連のハンドラー
    const onAuthenticated = async (user) => {
      isAuthenticated.value = true
      await loadUserData()
    }
    
    const loadUserData = async () => {
      try {
        // キャラクター一覧を取得
        const characters = await charactersAPI.list()
        if (characters.length > 0) {
          // 最後に使用したキャラクターまたは最初のキャラクターを選択
          currentCharacter.value = characters[0]
          await loadGameProgress()
          gameState.value = 'town'
        } else {
          // キャラクターが存在しない場合は作成画面へ
          gameState.value = 'character-creation'
        }
      } catch (error) {
        console.error('Failed to load user data:', error)
        gameState.value = 'character-creation'
      }
    }
    
    const loadGameProgress = async () => {
      if (!currentCharacter.value) return
      
      try {
        const saveData = await savesAPI.get(currentCharacter.value.id)
        if (saveData) {
          // セーブデータから進行状況を復元
          Object.assign(gameProgress, {
            currentFloor: saveData.currentFloor || 1,
            playerX: saveData.playerX || 1,
            playerY: saveData.playerY || 6,
            potions: saveData.potions || 3,
            keys: saveData.keys || 0,
            doorStates: saveData.doorStates || {},
            chestStates: saveData.chestStates || {},
            playerPositions: saveData.playerPositions || {
              1: { x: 1, y: 6 },
              2: { x: 1, y: 1 },
              3: { x: 1, y: 1 }
            },
            messages: saveData.messages || []
          })
        }
      } catch (error) {
        console.log('No save data found, using defaults')
        // セーブデータがない場合はデフォルト値を使用
      }
    }
    
    const saveGameProgress = async () => {
      if (!currentCharacter.value) return
      
      try {
        const saveData = {
          characterId: currentCharacter.value.id,
          character: currentCharacter.value,
          ...gameProgress
        }
        
        // 既存セーブデータがあるかチェック
        try {
          await savesAPI.get(currentCharacter.value.id)
          // 存在する場合は更新
          await savesAPI.update(currentCharacter.value.id, saveData)
        } catch {
          // 存在しない場合は作成
          await savesAPI.create(saveData)
        }
      } catch (error) {
        console.error('Failed to save game progress:', error)
      }
    }
    
    // キャラクター関連のハンドラー
    const onCharacterCreated = (character) => {
      currentCharacter.value = character
      gameState.value = 'town'
      saveGameProgress()
    }
    
    const onCharacterSelected = (character) => {
      currentCharacter.value = character
      loadGameProgress()
      gameState.value = 'town'
    }
    
    const onCharacterUpdated = async (updatedCharacter) => {
      currentCharacter.value = updatedCharacter
      await saveGameProgress()
    }
    
    // ゲーム状態のハンドラー
    const enterDungeon = () => {
      gameState.value = 'playing'
      saveGameProgress()
    }
    
    const enterGuild = () => {
      gameState.value = 'guild'
    }
    
    const leaveGuild = () => {
      gameState.value = 'town'
    }
    
    const startCombat = (enemy) => {
      currentEnemy.value = enemy
      gameState.value = 'combat'
    }
    
    const endCombat = (result) => {
      if (result.victory) {
        gameState.value = 'playing'
      } else if (result.fled) {
        gameState.value = 'playing'
      } else {
        // プレイヤー敗北
        gameState.value = 'game-over'
      }
      currentEnemy.value = null
      saveGameProgress()
    }
    
    const onVictory = (reward) => {
      lastReward.value = reward
      gameState.value = 'victory'
    }
    
    const returnToTown = () => {
      gameState.value = 'town'
      // ダンジョン進行状況をリセット
      Object.assign(gameProgress, {
        currentFloor: 1,
        playerX: 1,
        playerY: 6,
        potions: 3,
        keys: 0,
        doorStates: {},
        chestStates: {},
        playerPositions: {
          1: { x: 1, y: 6 },
          2: { x: 1, y: 1 },
          3: { x: 1, y: 1 }
        },
        messages: []
      })
      saveGameProgress()
    }
    
    const onGameProgressUpdated = (progress) => {
      Object.assign(gameProgress, progress)
      saveGameProgress()
    }
    
    const resetGame = () => {
      currentCharacter.value = null
      gameState.value = 'character-creation'
      Object.assign(gameProgress, {
        currentFloor: 1,
        playerX: 1,
        playerY: 6,
        potions: 3,
        keys: 0,
        doorStates: {},
        chestStates: {},
        playerPositions: {
          1: { x: 1, y: 6 },
          2: { x: 1, y: 1 },
          3: { x: 1, y: 1 }
        },
        messages: []
      })
    }
    
    // 自動保存（定期的にゲーム進行状況を保存）
    watch([currentCharacter, gameProgress], () => {
      if (currentCharacter.value && gameState.value !== 'character-creation') {
        saveGameProgress()
      }
    }, { deep: true })
    
    return {
      loading,
      isAuthenticated,
      gameState,
      currentCharacter,
      currentEnemy,
      lastReward,
      gameProgress,
      onAuthenticated,
      onCharacterCreated,
      onCharacterSelected,
      onCharacterUpdated,
      enterDungeon,
      enterGuild,
      leaveGuild,
      startCombat,
      endCombat,
      onVictory,
      returnToTown,
      onGameProgressUpdated,
      resetGame
    }
  }
}
</script>

<style scoped>
body {
  font-family: 'Courier New', monospace;
  background-color: #000;
  color: #00ff00;
  margin: 0;
  padding: 20px;
}

.game-container {
  max-width: 800px;
  margin: 0 auto;
  background-color: #001a00;
  border: 2px solid #00ff00;
  padding: 20px;
  border-radius: 10px;
}

.title {
  text-align: center;
  font-size: 24px;
  margin-bottom: 20px;
  color: #ffff00;
  text-shadow: 2px 2px 4px rgba(0,0,0,0.8);
}

.loading-screen {
  text-align: center;
  padding: 50px;
}

.loading-text {
  font-size: 18px;
  color: #00ff00;
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0% { opacity: 1; }
  50% { opacity: 0.5; }
  100% { opacity: 1; }
}

.auth-screen {
  max-width: 400px;
  margin: 0 auto;
}
</style>