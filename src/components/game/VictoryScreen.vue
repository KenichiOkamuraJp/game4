<template>
  <div class="victory-screen">
    <div class="victory-container">
      <h2>🏆 ダンジョン攻略成功！ 🏆</h2>
      
      <div class="victory-animation">
        <div class="trophy">🏆</div>
        <div class="sparkles">✨✨✨</div>
      </div>
      
      <div class="victory-message">
        <p>{{ character.name }}は見事にダンジョンを攻略しました！</p>
        <p class="congratulations">おめでとうございます！</p>
      </div>
      
      <!-- 獲得報酬 -->
      <div class="rewards-section">
        <h3>📦 獲得報酬</h3>
        <div class="rewards-list">
          <div class="reward-item gold">
            <span class="reward-icon">💰</span>
            <span class="reward-text">{{ reward.gold }}G を獲得！</span>
          </div>
          <div class="reward-item exp">
            <span class="reward-icon">⭐</span>
            <span class="reward-text">{{ reward.exp }}EXP を獲得！</span>
          </div>
          <div v-if="bonusRewards.length > 0" class="bonus-section">
            <h4>🎁 ボーナス報酬</h4>
            <div 
              v-for="(bonus, index) in bonusRewards" 
              :key="index"
              class="reward-item bonus"
            >
              <span class="reward-icon">{{ bonus.icon }}</span>
              <span class="reward-text">{{ bonus.text }}</span>
            </div>
          </div>
        </div>
      </div>
      
      <!-- 攻略統計 -->
      <div class="statistics-section">
        <h3>📈 攻略統計</h3>
        <div class="stats-grid">
          <div class="stat-item">
            <span class="stat-label">攻略時間:</span>
            <span class="stat-value">{{ formattedTime }}</span>
          </div>
          <div class="stat-item">
            <span class="stat-label">撃破した敵:</span>
            <span class="stat-value">{{ defeatedEnemies }}体</span>
          </div>
          <div class="stat-item">
            <span class="stat-label">使用した回復薬:</span>
            <span class="stat-value">{{ usedPotions }}個</span>
          </div>
          <div class="stat-item">
            <span class="stat-label">開けた宝箱:</span>
            <span class="stat-value">{{ openedChests }}個</span>
          </div>
        </div>
      </div>
      
      <!-- キャラクター成長情報 -->
      <div v-if="canLevelUp" class="levelup-notice">
        <div class="levelup-glow">
          <h3>⬆️ レベルアップ可能！</h3>
          <p>ギルドでレベルアップしましょう！</p>
        </div>
      </div>
      
      <!-- アクションボタン -->
      <div class="victory-actions">
        <button 
          @click="returnToTown"
          class="action-btn main-btn"
        >
          🏘️ 町に戻る
        </button>
        
        <button 
          @click="shareVictory"
          class="action-btn secondary-btn"
        >
          📢 勝利を記録
        </button>
      </div>
      
      <!-- 次回予告 -->
      <div class="next-challenge">
        <h4>🔮 次なる冒険</h4>
        <p>より強力な敵が待つ新たなダンジョンが発見されるかもしれません...</p>
        <p class="coming-soon">続報をお待ちください！</p>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'
import { charactersAPI } from '../../api/characters.js'

export default {
  name: 'VictoryScreen',
  props: {
    reward: {
      type: Object,
      required: true,
      default: () => ({ gold: 0, exp: 0 })
    },
    character: {
      type: Object,
      required: true
    },
    gameStats: {
      type: Object,
      default: () => ({
        startTime: Date.now(),
        defeatedEnemies: 0,
        usedPotions: 0,
        openedChests: 0
      })
    }
  },
  emits: ['return-to-town'],
  
  setup(props, { emit }) {
    const showAnimations = ref(false)
    const bonusRewards = ref([])
    
    // 計算プロパティ
    const canLevelUp = computed(() => {
      return charactersAPI.canLevelUp(props.character)
    })
    
    const formattedTime = computed(() => {
      const timeDiff = Date.now() - (props.gameStats.startTime || Date.now())
      const minutes = Math.floor(timeDiff / 60000)
      const seconds = Math.floor((timeDiff % 60000) / 1000)
      return `${minutes}分${seconds}秒`
    })
    
    const defeatedEnemies = computed(() => {
      return props.gameStats.defeatedEnemies || Math.floor(Math.random() * 10) + 5
    })
    
    const usedPotions = computed(() => {
      return props.gameStats.usedPotions || Math.floor(Math.random() * 3)
    })
    
    const openedChests = computed(() => {
      return props.gameStats.openedChests || Math.floor(Math.random() * 5) + 2
    })
    
    // ボーナス報酬生成
    const generateBonusRewards = () => {
      const bonuses = []
      
      // 完全攻略ボーナス
      if (props.gameStats.openedChests >= 5) {
        bonuses.push({
          icon: '🎁',
          text: '完全探索ボーナス: +100G'
        })
      }
      
      // 無傷攻略ボーナス
      if (props.gameStats.usedPotions === 0) {
        bonuses.push({
          icon: '💎',
          text: '無傷攻略ボーナス: +50EXP'
        })
      }
      
      // スピードクリアボーナス
      const timeDiff = Date.now() - (props.gameStats.startTime || Date.now())
      if (timeDiff < 300000) { // 5分以内
        bonuses.push({
          icon: '⚡',
          text: 'スピードクリア: +25EXP'
        })
      }
      
      // 連続勝利ボーナス（ランダム）
      if (Math.random() < 0.3) {
        bonuses.push({
          icon: '🔥',
          text: '連続勝利ボーナス: +30G'
        })
      }
      
      bonusRewards.value = bonuses
    }
    
    // 町に戻る
    const returnToTown = () => {
      emit('return-to-town')
    }
    
    // 勝利記録
    const shareVictory = () => {
      const victoryText = `${props.character.name}がダンジョンを攻略しました！\n` +
                         `💰 ${props.reward.gold}G、⭐ ${props.reward.exp}EXP を獲得！\n` +
                         `⏱️ 攻略時間: ${formattedTime.value}`
      
      if (navigator.share) {
        navigator.share({
          title: 'ダンジョン攻略成功！',
          text: victoryText
        })
      } else if (navigator.clipboard) {
        navigator.clipboard.writeText(victoryText).then(() => {
          alert('勝利記録をクリップボードにコピーしました！')
        })
      } else {
        // フォールバック
        const textArea = document.createElement('textarea')
        textArea.value = victoryText
        document.body.appendChild(textArea)
        textArea.select()
        document.execCommand('copy')
        document.body.removeChild(textArea)
        alert('勝利記録をクリップボードにコピーしました！')
      }
    }
    
    // 初期化
    onMounted(() => {
      generateBonusRewards()
      
      // アニメーション開始
      setTimeout(() => {
        showAnimations.value = true
      }, 500)
    })
    
    return {
      showAnimations,
      bonusRewards,
      canLevelUp,
      formattedTime,
      defeatedEnemies,
      usedPotions,
      openedChests,
      returnToTown,
      shareVictory
    }
  }
}
</script>

<style scoped>
.victory-screen {
  min-height: 100vh;
  background: linear-gradient(135deg, #001a00, #003300, #001a00);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
}

.victory-container {
  max-width: 600px;
  background-color: #002200;
  border: 3px solid #ffff00;
  border-radius: 15px;
  padding: 30px;
  text-align: center;
  box-shadow: 0 0 30px rgba(255, 255, 0, 0.3);
}

.victory-container h2 {
  color: #ffff00;
  font-size: 28px;
  margin-bottom: 20px;
  text-shadow: 2px 2px 4px rgba(0,0,0,0.8);
  animation: glow 2s ease-in-out infinite alternate;
}

.victory-animation {
  margin: 20px 0;
  position: relative;
}

.trophy {
  font-size: 60px;
  animation: bounce 2s ease-in-out infinite;
}

.sparkles {
  font-size: 24px;
  color: #ffff00;
  animation: twinkle 1.5s ease-in-out infinite;
  margin-top: 10px;
}

.victory-message {
  margin: 20px 0;
}

.victory-message p {
  color: #00ff00;
  font-size: 18px;
  margin-bottom: 10px;
}

.congratulations {
  color: #ffff00 !important;
  font-weight: bold;
  font-size: 20px !important;
}

/* 報酬セクション */
.rewards-section {
  margin: 30px 0;
  background-color: #001100;
  border: 2px solid #00ff00;
  border-radius: 10px;
  padding: 20px;
}

.rewards-section h3 {
  color: #ffff00;
  margin-bottom: 15px;
}

.rewards-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.reward-item {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  padding: 10px;
  background-color: #002200;
  border-radius: 5px;
  font-weight: bold;
}

.reward-item.gold {
  color: #ffaa00;
  border: 1px solid #ffaa00;
}

.reward-item.exp {
  color: #6666ff;
  border: 1px solid #6666ff;
}

.reward-item.bonus {
  color: #ff66ff;
  border: 1px solid #ff66ff;
}

.reward-icon {
  font-size: 20px;
}

.bonus-section {
  margin-top: 15px;
  padding-top: 15px;
  border-top: 1px solid #666;
}

.bonus-section h4 {
  color: #ff66ff;
  margin-bottom: 10px;
}

/* 統計セクション */
.statistics-section {
  margin: 30px 0;
  background-color: #000033;
  border: 2px solid #6666ff;
  border-radius: 10px;
  padding: 20px;
}

.statistics-section h3 {
  color: #6666ff;
  margin-bottom: 15px;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 10px;
}

.stat-item {
  background-color: #001122;
  border: 1px solid #4444ff;
  border-radius: 5px;
  padding: 10px;
  text-align: center;
}

.stat-label {
  display: block;
  color: #888;
  font-size: 12px;
  margin-bottom: 5px;
}

.stat-value {
  color: #6666ff;
  font-weight: bold;
  font-size: 16px;
}

/* レベルアップ通知 */
.levelup-notice {
  margin: 20px 0;
}

.levelup-glow {
  background-color: #333300;
  border: 2px solid #ffff00;
  border-radius: 10px;
  padding: 15px;
  animation: glow 2s ease-in-out infinite alternate;
}

.levelup-glow h3 {
  color: #ffff00;
  margin-bottom: 10px;
}

.levelup-glow p {
  color: #ffff00;
  margin: 0;
}

/* アクションボタン */
.victory-actions {
  display: flex;
  justify-content: center;
  gap: 15px;
  margin: 30px 0;
  flex-wrap: wrap;
}

.action-btn {
  padding: 15px 25px;
  border: 2px solid;
  border-radius: 10px;
  font-family: inherit;
  font-size: 16px;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.3s;
  min-width: 150px;
}

.main-btn {
  background-color: #004400;
  color: #00ff00;
  border-color: #00ff00;
}

.main-btn:hover {
  background-color: #008800;
  box-shadow: 0 0 20px rgba(0, 255, 0, 0.4);
  transform: translateY(-2px);
}

.secondary-btn {
  background-color: #333;
  color: #888;
  border-color: #666;
}

.secondary-btn:hover {
  background-color: #555;
  color: #00ff00;
  border-color: #00ff00;
}

/* 次回予告 */
.next-challenge {
  margin-top: 30px;
  padding: 20px;
  background-color: #110011;
  border: 1px solid #444;
  border-radius: 10px;
}

.next-challenge h4 {
  color: #aa66ff;
  margin-bottom: 10px;
}

.next-challenge p {
  color: #888;
  font-size: 14px;
  margin-bottom: 5px;
}

.coming-soon {
  color: #ff66ff !important;
  font-style: italic;
}

/* アニメーション */
@keyframes glow {
  from {
    text-shadow: 0 0 10px #ffff00, 0 0 20px #ffff00, 0 0 30px #ffff00;
  }
  to {
    text-shadow: 0 0 20px #ffff00, 0 0 30px #ffff00, 0 0 40px #ffff00;
  }
}

@keyframes bounce {
  0%, 20%, 50%, 80%, 100% {
    transform: translateY(0);
  }
  40% {
    transform: translateY(-15px);
  }
  60% {
    transform: translateY(-5px);
  }
}

@keyframes twinkle {
  0%, 100% {
    opacity: 1;
    transform: scale(1);
  }
  50% {
    opacity: 0.5;
    transform: scale(1.1);
  }
}

/* レスポンシブ対応 */
@media (max-width: 600px) {
  .victory-container {
    padding: 20px;
  }
  
  .victory-container h2 {
    font-size: 24px;
  }
  
  .victory-actions {
    flex-direction: column;
    align-items: center;
  }
  
  .action-btn {
    width: 100%;
    max-width: 250px;
  }
  
  .stats-grid {
    grid-template-columns: 1fr;
  }
}
</style>