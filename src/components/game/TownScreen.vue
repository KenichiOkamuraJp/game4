<template>
  <div class="town-screen">
    <h2>🏘️ 冒険者の町</h2>
    <p class="welcome-message">ようこそ、{{ character.name }}さん！</p>
    
    <div class="town-menu">
      <!-- ステータスパネル -->
      <div class="town-panel status-panel">
        <h3>📊 ステータス</h3>
        <div class="status-grid">
          <div class="status-item">
            <span class="label">レベル:</span>
            <span class="value">{{ character.level }}</span>
          </div>
          <div class="status-item">
            <span class="label">EXP:</span>
            <span class="value">{{ character.exp }} / {{ character.expToNext }}</span>
          </div>
          <div class="status-item">
            <span class="label">HP:</span>
            <span class="value hp-bar">
              <span class="hp-current">{{ character.hp }}</span>
              <span class="hp-separator">/</span>
              <span class="hp-max">{{ character.maxHp }}</span>
              <div class="hp-visual">
                <div 
                  class="hp-fill" 
                  :style="{ width: hpPercentage + '%' }"
                ></div>
              </div>
            </span>
          </div>
          <div class="status-item">
            <span class="label">攻撃力:</span>
            <span class="value">{{ character.attack }}</span>
          </div>
          <div class="status-item">
            <span class="label">防御力:</span>
            <span class="value">{{ character.defense }}</span>
          </div>
          <div class="status-item gold">
            <span class="label">💰 所持金:</span>
            <span class="value">{{ character.gold }}G</span>
          </div>
        </div>
        
        <!-- レベルアップ通知 -->
        <div v-if="canLevelUp" class="level-up-notice">
          ⭐ レベルアップ可能！ギルドに行こう！
        </div>
      </div>

      <!-- 回復の泉 -->
      <div class="town-panel healing-panel">
        <h3>🏥 回復の泉</h3>
        <p class="panel-description">疲れた冒険者を癒します</p>
        
        <div class="heal-info">
          <div class="heal-cost">料金: {{ HEAL_COST }}G</div>
          <div v-if="character.hp >= character.maxHp" class="heal-status full">
            すでに満タンです
          </div>
          <div v-else-if="character.gold < HEAL_COST" class="heal-status insufficient">
            所持金が不足しています
          </div>
          <div v-else class="heal-status available">
            {{ character.maxHp - character.hp }}HP回復できます
          </div>
        </div>
        
        <button 
          @click="fullHeal"
          :disabled="!canHeal || loading"
          class="action-btn heal-btn"
        >
          <span v-if="loading">回復中...</span>
          <span v-else>💊 完全回復</span>
        </button>
      </div>

      <!-- 冒険者ギルド -->
      <div class="town-panel guild-panel">
        <h3>🎓 冒険者ギルド</h3>
        <p class="panel-description">経験を積んで強くなろう</p>
        
        <div class="guild-info">
          <div v-if="canLevelUp" class="guild-status highlight">
            ⭐ レベルアップ可能！
          </div>
          <div v-else class="guild-status">
            あと{{ expNeeded }}EXP でレベルアップ
          </div>
        </div>
        
        <button 
          @click="enterGuild"
          :disabled="loading"
          class="action-btn guild-btn"
        >
          📚 ギルドに入る
        </button>
      </div>
    </div>

    <!-- ダンジョン挑戦パネル -->
    <div class="dungeon-challenge">
      <div class="town-panel dungeon-panel">
        <h3>🏰 ダンジョン</h3>
        <p class="panel-description">危険なダンジョンが発見されました！</p>
        
        <div class="dungeon-info">
          <div class="dungeon-details">
            <div class="dungeon-floors">📚 3階層構造</div>
            <div class="dungeon-difficulty">⚔️ 難易度: 普通</div>
          </div>
          <div class="dungeon-rewards">
            <h4>🎁 クリア報酬:</h4>
            <div class="reward-item">💰 {{ DUNGEON_REWARDS.gold }}G</div>
            <div class="reward-item">⭐ {{ DUNGEON_REWARDS.exp }}EXP</div>
          </div>
        </div>
        
        <div class="dungeon-warning">
          ⚠️ 死亡した場合、町に戻されます
        </div>
        
        <button 
          @click="enterDungeon"
          :disabled="loading"
          class="action-btn dungeon-btn"
        >
          ⚔️ ダンジョンに挑戦
        </button>
      </div>
    </div>

    <!-- キャラクター管理 -->
    <div class="character-management">
      <div class="town-panel management-panel">
        <h3>👤 キャラクター管理</h3>
        <div class="management-actions">
          <button 
            @click="showCharacterList"
            :disabled="loading"
            class="action-btn secondary"
          >
            📋 キャラクター変更
          </button>
          <button 
            @click="logout"
            :disabled="loading"
            class="action-btn secondary"
          >
            🚪 ログアウト
          </button>
        </div>
      </div>
    </div>

    <!-- エラーメッセージ -->
    <div v-if="error" class="error-message">
      {{ error }}
    </div>

    <!-- 成功メッセージ -->
    <div v-if="successMessage" class="success-message">
      {{ successMessage }}
    </div>

    <!-- キャラクター選択ダイアログ -->
    <div v-if="showCharacterDialog" class="character-dialog">
      <div class="dialog-content">
        <h3>キャラクター選択</h3>
        <div class="character-list">
          <div 
            v-for="char in availableCharacters" 
            :key="char.id"
            class="character-option"
            :class="{ active: char.id === character.id }"
            @click="selectCharacter(char)"
          >
            <div class="char-name">{{ char.name }}</div>
            <div class="char-level">Lv.{{ char.level }}</div>
          </div>
        </div>
        <div class="dialog-actions">
          <button @click="closeCharacterDialog" class="action-btn secondary">
            キャンセル
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'
import { charactersAPI } from '../../api/characters.js'
import { authService } from '../../api/auth.js'

export default {
  name: 'TownScreen',
  props: {
    character: {
      type: Object,
      required: true
    }
  },
  emits: ['enter-dungeon', 'enter-guild', 'character-updated'],
  
  setup(props, { emit }) {
    const loading = ref(false)
    const error = ref('')
    const successMessage = ref('')
    const showCharacterDialog = ref(false)
    const availableCharacters = ref([])
    
    // 定数
    const HEAL_COST = 50
    const DUNGEON_REWARDS = { gold: 500, exp: 200 }
    
    // 計算プロパティ
    const hpPercentage = computed(() => {
      return Math.round((props.character.hp / props.character.maxHp) * 100)
    })
    
    const canLevelUp = computed(() => {
      return charactersAPI.canLevelUp(props.character)
    })
    
    const expNeeded = computed(() => {
      return charactersAPI.getExpNeeded(props.character)
    })
    
    const canHeal = computed(() => {
      return props.character.hp < props.character.maxHp && 
             props.character.gold >= HEAL_COST
    })
    
    // メッセージ管理
    const showMessage = (message, isError = false) => {
      if (isError) {
        error.value = message
        successMessage.value = ''
      } else {
        successMessage.value = message
        error.value = ''
      }
      
      // メッセージを3秒後に自動で消す
      setTimeout(() => {
        error.value = ''
        successMessage.value = ''
      }, 3000)
    }
    
    // 完全回復
    const fullHeal = async () => {
      if (!canHeal.value) return
      
      try {
        loading.value = true
        error.value = ''
        
        // キャラクターのHPとゴールドを更新
        const updatedCharacter = {
          ...props.character,
          hp: props.character.maxHp,
          gold: props.character.gold - HEAL_COST
        }
        
        // サーバーに更新を送信
        const result = await charactersAPI.update(props.character.id, updatedCharacter)
        
        emit('character-updated', result)
        showMessage(`完全回復しました！（${HEAL_COST}G使用）`)
      } catch (err) {
        console.error('Failed to heal:', err)
        showMessage(err.message || '回復に失敗しました', true)
      } finally {
        loading.value = false
      }
    }
    
    // ギルドに入る
    const enterGuild = () => {
      emit('enter-guild')
    }
    
    // ダンジョンに挑戦
    const enterDungeon = () => {
      emit('enter-dungeon')
    }
    
    // キャラクター一覧を表示
    const showCharacterList = async () => {
      try {
        loading.value = true
        availableCharacters.value = await charactersAPI.list()
        showCharacterDialog.value = true
      } catch (err) {
        console.error('Failed to load characters:', err)
        showMessage('キャラクター一覧の取得に失敗しました', true)
      } finally {
        loading.value = false
      }
    }
    
    // キャラクター選択
    const selectCharacter = (character) => {
      emit('character-updated', character)
      showCharacterDialog.value = false
      showMessage(`${character.name}に変更しました`)
    }
    
    // キャラクター選択ダイアログを閉じる
    const closeCharacterDialog = () => {
      showCharacterDialog.value = false
    }
    
    // ログアウト
    const logout = async () => {
      try {
        await authService.signOut()
        // ページをリロードして認証状態をリセット
        window.location.reload()
      } catch (err) {
        console.error('Failed to logout:', err)
        showMessage('ログアウトに失敗しました', true)
      }
    }
    
    return {
      loading,
      error,
      successMessage,
      showCharacterDialog,
      availableCharacters,
      HEAL_COST,
      DUNGEON_REWARDS,
      hpPercentage,
      canLevelUp,
      expNeeded,
      canHeal,
      fullHeal,
      enterGuild,
      enterDungeon,
      showCharacterList,
      selectCharacter,
      closeCharacterDialog,
      logout
    }
  }
}
</script>

<style scoped>
.town-screen {
  max-width: 800px;
  margin: 0 auto;
  padding: 20px;
}

.town-screen h2 {
  text-align: center;
  color: #ffff00;
  margin-bottom: 10px;
}

.welcome-message {
  text-align: center;
  color: #00ff00;
  font-size: 18px;
  margin-bottom: 30px;
}

.town-menu {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 20px;
  margin-bottom: 30px;
}

.town-panel {
  background-color: #001a00;
  border: 2px solid #00ff00;
  border-radius: 10px;
  padding: 20px;
  transition: all 0.3s;
}

.town-panel:hover {
  box-shadow: 0 0 15px rgba(0, 255, 0, 0.2);
}

.town-panel h3 {
  color: #ffff00;
  margin-bottom: 15px;
  text-align: center;
}

.panel-description {
  color: #888;
  font-size: 14px;
  text-align: center;
  margin-bottom: 15px;
}

/* ステータスパネル */
.status-grid {
  display: grid;
  gap: 10px;
}

.status-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px;
  background-color: #002200;
  border-radius: 5px;
}

.status-item.gold {
  background-color: #332200;
  border: 1px solid #ffaa00;
}

.status-item .label {
  color: #888;
  font-size: 14px;
}

.status-item .value {
  color: #00ff00;
  font-weight: bold;
}

.hp-bar {
  display: flex !important;
  align-items: center;
  gap: 5px;
}

.hp-visual {
  width: 60px;
  height: 8px;
  background-color: #330000;
  border-radius: 4px;
  overflow: hidden;
  margin-left: 8px;
}

.hp-fill {
  height: 100%;
  background: linear-gradient(90deg, #ff4444, #ffaa00, #00ff00);
  transition: width 0.3s;
}

.level-up-notice {
  background-color: #332200;
  color: #ffff00;
  border: 1px solid #ffff00;
  border-radius: 5px;
  padding: 10px;
  text-align: center;
  margin-top: 15px;
  font-weight: bold;
  animation: pulse 2s infinite;
}

/* 回復の泉 */
.heal-info {
  margin-bottom: 15px;
}

.heal-cost {
  color: #ffaa00;
  font-weight: bold;
  margin-bottom: 8px;
}

.heal-status {
  font-size: 14px;
  padding: 5px;
  border-radius: 3px;
}

.heal-status.full {
  color: #00ff00;
  background-color: #003300;
}

.heal-status.insufficient {
  color: #ff4444;
  background-color: #330000;
}

.heal-status.available {
  color: #ffff00;
  background-color: #333300;
}

/* ギルド */
.guild-info {
  margin-bottom: 15px;
}

.guild-status {
  padding: 8px;
  border-radius: 5px;
  text-align: center;
  font-weight: bold;
}

.guild-status.highlight {
  color: #ffff00;
  background-color: #333300;
  border: 1px solid #ffff00;
  animation: pulse 2s infinite;
}

/* ダンジョン */
.dungeon-challenge {
  margin-bottom: 30px;
}

.dungeon-info {
  margin-bottom: 15px;
}

.dungeon-details {
  display: flex;
  justify-content: space-between;
  margin-bottom: 15px;
  font-size: 14px;
  color: #888;
}

.dungeon-rewards h4 {
  color: #ffaa00;
  margin-bottom: 8px;
  font-size: 16px;
}

.reward-item {
  color: #00ff00;
  margin-bottom: 5px;
}

.dungeon-warning {
  background-color: #330000;
  color: #ff4444;
  border: 1px solid #ff4444;
  border-radius: 5px;
  padding: 8px;
  font-size: 12px;
  text-align: center;
  margin-bottom: 15px;
}

/* キャラクター管理 */
.character-management {
  margin-bottom: 20px;
}

.management-actions {
  display: flex;
  gap: 10px;
}

/* ボタンスタイル */
.action-btn {
  width: 100%;
  padding: 12px;
  border: 2px solid;
  border-radius: 5px;
  font-family: inherit;
  font-size: 16px;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.3s;
}

.heal-btn {
  background-color: #003300;
  color: #00ff00;
  border-color: #00ff00;
}

.heal-btn:hover:not(:disabled) {
  background-color: #006600;
  box-shadow: 0 0 15px rgba(0, 255, 0, 0.3);
}

.guild-btn {
  background-color: #000033;
  color: #6666ff;
  border-color: #6666ff;
}

.guild-btn:hover:not(:disabled) {
  background-color: #000066;
  box-shadow: 0 0 15px rgba(102, 102, 255, 0.3);
}

.dungeon-btn {
  background-color: #330000;
  color: #ff4444;
  border-color: #ff4444;
  font-size: 18px;
  padding: 15px;
}

.dungeon-btn:hover:not(:disabled) {
  background-color: #660000;
  box-shadow: 0 0 15px rgba(255, 68, 68, 0.3);
}

.action-btn.secondary {
  background-color: #333;
  color: #888;
  border-color: #666;
  font-size: 14px;
}

.action-btn.secondary:hover:not(:disabled) {
  background-color: #555;
  color: #00ff00;
  border-color: #00ff00;
}

.action-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* メッセージ */
.error-message {
  background-color: #330000;
  color: #ff4444;
  border: 2px solid #ff4444;
  border-radius: 10px;
  padding: 15px;
  margin-top: 20px;
  text-align: center;
  font-weight: bold;
}

.success-message {
  background-color: #003300;
  color: #00ff00;
  border: 2px solid #00ff00;
  border-radius: 10px;
  padding: 15px;
  margin-top: 20px;
  text-align: center;
  font-weight: bold;
}

/* キャラクター選択ダイアログ */
.character-dialog {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.8);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.dialog-content {
  background-color: #001a00;
  border: 2px solid #00ff00;
  border-radius: 10px;
  padding: 30px;
  max-width: 400px;
  width: 90%;
}

.dialog-content h3 {
  color: #ffff00;
  text-align: center;
  margin-bottom: 20px;
}

.character-list {
  max-height: 300px;
  overflow-y: auto;
  margin-bottom: 20px;
}

.character-option {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px;
  background-color: #002200;
  border: 1px solid #004400;
  border-radius: 5px;
  margin-bottom: 8px;
  cursor: pointer;
  transition: all 0.3s;
}

.character-option:hover {
  background-color: #004400;
  border-color: #00ff00;
}

.character-option.active {
  background-color: #003300;
  border-color: #00ff00;
  box-shadow: 0 0 10px rgba(0, 255, 0, 0.3);
}

.char-name {
  color: #00ff00;
  font-weight: bold;
}

.char-level {
  color: #888;
  font-size: 14px;
}

.dialog-actions {
  text-align: center;
}

@keyframes pulse {
  0% { opacity: 1; }
  50% { opacity: 0.7; }
  100% { opacity: 1; }
}
</style>