<template>
  <div class="guild-screen">
    <h2>🎓 冒険者ギルド</h2>
    <p class="guild-description">ここでは蓄積した経験値を使ってレベルアップできます</p>
    
    <div class="guild-content">
      <!-- 現在のステータス -->
      <div class="status-section">
        <h3>📊 現在のステータス</h3>
        <div class="status-card">
          <div class="character-info">
            <div class="character-name">{{ character.name }}</div>
            <div class="character-level">レベル {{ character.level }}</div>
          </div>
          
          <div class="stats-grid">
            <div class="stat-item">
              <span class="stat-label">経験値:</span>
              <span class="stat-value">
                {{ character.exp }} / {{ character.expToNext }}
                <div class="exp-bar">
                  <div 
                    class="exp-fill" 
                    :style="{ width: expPercentage + '%' }"
                  ></div>
                </div>
              </span>
            </div>
            <div class="stat-item">
              <span class="stat-label">HP:</span>
              <span class="stat-value">{{ character.maxHp }}</span>
            </div>
            <div class="stat-item">
              <span class="stat-label">攻撃力:</span>
              <span class="stat-value">{{ character.attack }}</span>
            </div>
            <div class="stat-item">
              <span class="stat-label">防御力:</span>
              <span class="stat-value">{{ character.defense }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- レベルアップセクション -->
      <div class="levelup-section">
        <h3>⬆️ レベルアップ</h3>
        
        <div v-if="canLevelUp" class="levelup-available">
          <div class="levelup-notice">
            🎉 レベルアップが可能です！
          </div>
          
          <!-- 次回レベルアップ予想 -->
          <div class="levelup-preview">
            <h4>レベルアップ効果 (予想)</h4>
            <div class="preview-stats">
              <div class="preview-item">
                <span class="preview-label">レベル:</span>
                <span class="preview-change">
                  {{ character.level }} → {{ character.level + 1 }}
                </span>
              </div>
              <div class="preview-item">
                <span class="preview-label">HP:</span>
                <span class="preview-change">
                  {{ character.maxHp }} → {{ character.maxHp + estimatedGains.hp }}
                  <span class="gain-amount">(+{{ estimatedGains.hp }})</span>
                </span>
              </div>
              <div class="preview-item">
                <span class="preview-label">攻撃力:</span>
                <span class="preview-change">
                  {{ character.attack }} → {{ character.attack + estimatedGains.attack }}
                  <span class="gain-amount">(+{{ estimatedGains.attack }})</span>
                </span>
              </div>
              <div class="preview-item">
                <span class="preview-label">防御力:</span>
                <span class="preview-change">
                  {{ character.defense }} → {{ character.defense + estimatedGains.defense }}
                  <span class="gain-amount">(+{{ estimatedGains.defense }})</span>
                </span>
              </div>
            </div>
          </div>
          
          <button 
            @click="levelUp"
            :disabled="loading"
            class="levelup-btn"
          >
            <span v-if="loading">レベルアップ中...</span>
            <span v-else>⭐ レベルアップ！</span>
          </button>
        </div>
        
        <div v-else class="levelup-unavailable">
          <div class="exp-needed">
            レベルアップには あと <strong>{{ expNeeded }}EXP</strong> 必要です
          </div>
          <div class="advice">
            ダンジョンで敵を倒して経験値を獲得しよう！
          </div>
        </div>
      </div>

      <!-- レベルアップ履歴 -->
      <div v-if="levelUpHistory.length > 0" class="history-section">
        <h3>📈 レベルアップ履歴</h3>
        <div class="history-list">
          <div 
            v-for="(levelUp, index) in levelUpHistory" 
            :key="index"
            class="history-item"
          >
            <div class="history-level">Lv.{{ levelUp.level }}</div>
            <div class="history-gains">
              HP+{{ levelUp.gains.hp }}, 
              攻撃+{{ levelUp.gains.attack }}, 
              防御+{{ levelUp.gains.defense }}
            </div>
          </div>
        </div>
      </div>

      <!-- 町に戻るボタン -->
      <div class="guild-actions">
        <button 
          @click="leaveGuild"
          :disabled="loading"
          class="action-btn back-btn"
        >
          🏘️ 町に戻る
        </button>
      </div>
    </div>

    <!-- レベルアップ結果ダイアログ -->
    <div v-if="levelUpResult" class="levelup-dialog">
      <div class="dialog-content">
        <h3>🎉 レベルアップ成功！</h3>
        
        <div class="result-info">
          <div class="new-level">
            レベル {{ levelUpResult.newLevel }} になりました！
          </div>
          
          <div class="stat-increases">
            <h4>能力上昇:</h4>
            <div class="increase-item">
              <span class="increase-label">HP:</span>
              <span class="increase-value">+{{ levelUpResult.increases.hp }}</span>
            </div>
            <div class="increase-item">
              <span class="increase-label">攻撃力:</span>
              <span class="increase-value">+{{ levelUpResult.increases.attack }}</span>
            </div>
            <div class="increase-item">
              <span class="increase-label">防御力:</span>
              <span class="increase-value">+{{ levelUpResult.increases.defense }}</span>
            </div>
          </div>
          
          <div v-if="levelUpResult.remainingExp > 0" class="remaining-exp">
            残り経験値: {{ levelUpResult.remainingExp }}
          </div>
        </div>
        
        <button @click="closeLevelUpDialog" class="action-btn">
          OK
        </button>
      </div>
    </div>

    <!-- エラーメッセージ -->
    <div v-if="error" class="error-message">
      {{ error }}
    </div>
  </div>
</template>

<script>
import { ref, computed, reactive, onMounted } from 'vue'
import { charactersAPI } from '../../api/characters.js'

export default {
  name: 'GuildScreen',
  props: {
    character: {
      type: Object,
      required: true
    }
  },
  emits: ['leave-guild', 'character-updated'],
  
  setup(props, { emit }) {
    const loading = ref(false)
    const error = ref('')
    const levelUpResult = ref(null)
    const levelUpHistory = ref([])
    
    // 推定能力上昇値（実際のランダム値の中央値）
    const estimatedGains = reactive({
      hp: 10,      // 8-12の中央値
      attack: 3,   // 2-4の中央値  
      defense: 2   // 1-3の中央値
    })
    
    // 計算プロパティ
    const canLevelUp = computed(() => {
      return charactersAPI.canLevelUp(props.character)
    })
    
    const expNeeded = computed(() => {
      return charactersAPI.getExpNeeded(props.character)
    })
    
    const expPercentage = computed(() => {
      return Math.round((props.character.exp / props.character.expToNext) * 100)
    })
    
    onMounted(() => {
      // レベルアップ履歴をローカルストレージから読み込み
      loadLevelUpHistory()
    })
    
    // レベルアップ履歴の読み込み
    const loadLevelUpHistory = () => {
      try {
        const saved = localStorage.getItem(`levelup_history_${props.character.id}`)
        if (saved) {
          levelUpHistory.value = JSON.parse(saved).slice(-5) // 最新5件のみ
        }
      } catch (err) {
        console.warn('Failed to load level up history:', err)
      }
    }
    
    // レベルアップ履歴の保存
    const saveLevelUpHistory = (newEntry) => {
      try {
        levelUpHistory.value.push(newEntry)
        if (levelUpHistory.value.length > 5) {
          levelUpHistory.value = levelUpHistory.value.slice(-5)
        }
        
        localStorage.setItem(
          `levelup_history_${props.character.id}`,
          JSON.stringify(levelUpHistory.value)
        )
      } catch (err) {
        console.warn('Failed to save level up history:', err)
      }
    }
    
    // レベルアップ実行
    const levelUp = async () => {
      if (!canLevelUp.value) return
      
      try {
        loading.value = true
        error.value = ''
        
        // レベルアップ計算
        const levelUpData = charactersAPI.calculateLevelUp(props.character)
        
        // キャラクターデータを更新
        const updatedCharacter = {
          ...props.character,
          ...levelUpData
        }
        
        // サーバーに更新を送信
        const result = await charactersAPI.update(props.character.id, updatedCharacter)
        
        // レベルアップ結果を表示
        levelUpResult.value = {
          newLevel: result.level,
          increases: levelUpData.increases,
          remainingExp: result.exp
        }
        
        // 履歴に追加
        saveLevelUpHistory({
          level: result.level,
          gains: levelUpData.increases,
          timestamp: Date.now()
        })
        
        // 親コンポーネントに更新を通知
        emit('character-updated', result)
        
      } catch (err) {
        console.error('Failed to level up:', err)
        error.value = err.message || 'レベルアップに失敗しました'
      } finally {
        loading.value = false
      }
    }
    
    // レベルアップダイアログを閉じる
    const closeLevelUpDialog = () => {
      levelUpResult.value = null
    }
    
    // ギルドを出る
    const leaveGuild = () => {
      emit('leave-guild')
    }
    
    return {
      loading,
      error,
      levelUpResult,
      levelUpHistory,
      estimatedGains,
      canLevelUp,
      expNeeded,
      expPercentage,
      levelUp,
      closeLevelUpDialog,
      leaveGuild
    }
  }
}
</script>

<style scoped>
.guild-screen {
  max-width: 600px;
  margin: 0 auto;
  padding: 20px;
}

.guild-screen h2 {
  text-align: center;
  color: #ffff00;
  margin-bottom: 10px;
}

.guild-description {
  text-align: center;
  color: #888;
  margin-bottom: 30px;
}

.guild-content {
  display: flex;
  flex-direction: column;
  gap: 30px;
}

/* ステータスセクション */
.status-section h3 {
  color: #00ff00;
  margin-bottom: 15px;
}

.status-card {
  background-color: #001a00;
  border: 2px solid #00ff00;
  border-radius: 10px;
  padding: 20px;
}

.character-info {
  text-align: center;
  margin-bottom: 20px;
}

.character-name {
  font-size: 20px;
  font-weight: bold;
  color: #ffff00;
  margin-bottom: 5px;
}

.character-level {
  color: #00ff00;
  font-size: 16px;
}

.stats-grid {
  display: grid;
  gap: 15px;
}

.stat-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px;
  background-color: #002200;
  border-radius: 5px;
}

.stat-label {
  color: #888;
}

.stat-value {
  color: #00ff00;
  font-weight: bold;
  display: flex;
  align-items: center;
  gap: 10px;
}

.exp-bar {
  width: 120px;
  height: 8px;
  background-color: #330000;
  border-radius: 4px;
  overflow: hidden;
}

.exp-fill {
  height: 100%;
  background: linear-gradient(90deg, #6666ff, #00ff00);
  transition: width 0.3s;
}

/* レベルアップセクション */
.levelup-section h3 {
  color: #ffff00;
  margin-bottom: 15px;
}

.levelup-available {
  background-color: #002200;
  border: 2px solid #00ff00;
  border-radius: 10px;
  padding: 20px;
}

.levelup-notice {
  background-color: #333300;
  color: #ffff00;
  border: 1px solid #ffff00;
  border-radius: 5px;
  padding: 15px;
  text-align: center;
  font-weight: bold;
  margin-bottom: 20px;
  animation: pulse 2s infinite;
}

.levelup-preview {
  margin-bottom: 20px;
}

.levelup-preview h4 {
  color: #00ff00;
  margin-bottom: 15px;
  font-size: 16px;
}

.preview-stats {
  display: grid;
  gap: 10px;
}

.preview-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px;
  background-color: #001100;
  border-radius: 5px;
}

.preview-label {
  color: #888;
}

.preview-change {
  color: #00ff00;
  font-weight: bold;
}

.gain-amount {
  color: #ffff00;
  font-size: 12px;
  margin-left: 8px;
}

.levelup-btn {
  width: 100%;
  padding: 15px;
  background-color: #004400;
  color: #00ff00;
  border: 3px solid #00ff00;
  border-radius: 10px;
  font-family: inherit;
  font-size: 18px;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.3s;
}

.levelup-btn:hover:not(:disabled) {
  background-color: #008800;
  box-shadow: 0 0 20px rgba(0, 255, 0, 0.4);
  transform: translateY(-2px);
}

.levelup-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.levelup-unavailable {
  background-color: #222;
  border: 2px solid #666;
  border-radius: 10px;
  padding: 20px;
  text-align: center;
}

.exp-needed {
  color: #ffaa00;
  font-size: 18px;
  font-weight: bold;
  margin-bottom: 10px;
}

.advice {
  color: #888;
  font-style: italic;
}

/* 履歴セクション */
.history-section h3 {
  color: #6666ff;
  margin-bottom: 15px;
}

.history-list {
  background-color: #001a00;
  border: 1px solid #6666ff;
  border-radius: 10px;
  padding: 15px;
  max-height: 200px;
  overflow-y: auto;
}

.history-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px;
  background-color: #000033;
  border-radius: 5px;
  margin-bottom: 8px;
}

.history-item:last-child {
  margin-bottom: 0;
}

.history-level {
  color: #6666ff;
  font-weight: bold;
}

.history-gains {
  color: #888;
  font-size: 14px;
}

/* アクション */
.guild-actions {
  text-align: center;
}

.action-btn {
  padding: 12px 30px;
  border: 2px solid;
  border-radius: 5px;
  font-family: inherit;
  font-size: 16px;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.3s;
}

.back-btn {
  background-color: #333;
  color: #888;
  border-color: #666;
}

.back-btn:hover:not(:disabled) {
  background-color: #555;
  color: #00ff00;
  border-color: #00ff00;
}

.action-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* レベルアップダイアログ */
.levelup-dialog {
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
  border: 3px solid #ffff00;
  border-radius: 15px;
  padding: 30px;
  max-width: 400px;
  text-align: center;
  animation: bounceIn 0.5s;
}

.dialog-content h3 {
  color: #ffff00;
  margin-bottom: 20px;
  font-size: 24px;
}

.new-level {
  color: #00ff00;
  font-size: 20px;
  font-weight: bold;
  margin-bottom: 20px;
}

.stat-increases h4 {
  color: #ffff00;
  margin-bottom: 15px;
}

.increase-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px;
  background-color: #003300;
  border-radius: 5px;
  margin-bottom: 8px;
}

.increase-label {
  color: #888;
}

.increase-value {
  color: #ffff00;
  font-weight: bold;
  font-size: 18px;
}

.remaining-exp {
  color: #6666ff;
  margin-top: 15px;
  margin-bottom: 20px;
}

/* エラーメッセージ */
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

@keyframes pulse {
  0% { opacity: 1; }
  50% { opacity: 0.7; }
  100% { opacity: 1; }
}

@keyframes bounceIn {
  0% {
    transform: scale(0.3);
    opacity: 0;
  }
  50% {
    transform: scale(1.05);
  }
  70% {
    transform: scale(0.9);
  }
  100% {
    transform: scale(1);
    opacity: 1;
  }
}
</style>