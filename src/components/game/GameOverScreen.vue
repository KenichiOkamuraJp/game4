<template>
  <div class="gameover-screen">
    <div class="gameover-container">
      <!-- ゲームオーバータイトル -->
      <div class="gameover-title">
        <h2>💀 ゲームオーバー 💀</h2>
        <div class="skull-animation">☠️</div>
      </div>
      
      <!-- 敗北メッセージ -->
      <div class="defeat-message">
        <p class="character-name">{{ character.name }}</p>
        <p class="defeat-text">は力尽きてしまいました...</p>
        <div class="defeat-effect">
          <span class="fade-text">冒険はここで終わりです</span>
        </div>
      </div>
      
      <!-- 冒険の記録 -->
      <div class="adventure-record">
        <h3>📜 冒険の記録</h3>
        <div class="record-stats">
          <div class="record-item">
            <span class="record-label">到達階層:</span>
            <span class="record-value">{{ reachedFloor }}階</span>
          </div>
          <div class="record-item">
            <span class="record-label">獲得経験値:</span>
            <span class="record-value">{{ totalExp }}EXP</span>
          </div>
          <div class="record-item">
            <span class="record-label">獲得ゴールド:</span>
            <span class="record-value">{{ totalGold }}G</span>
          </div>
          <div class="record-item">
            <span class="record-label">撃破した敵:</span>
            <span class="record-value">{{ defeatedEnemies }}体</span>
          </div>
          <div class="record-item">
            <span class="record-label">冒険時間:</span>
            <span class="record-value">{{ adventureTime }}</span>
          </div>
        </div>
      </div>
      
      <!-- 最終ステータス -->
      <div class="final-status">
        <h3>⚰️ 最終ステータス</h3>
        <div class="status-grid">
          <div class="status-item">
            <span class="status-label">レベル:</span>
            <span class="status-value">{{ character.level }}</span>
          </div>
          <div class="status-item">
            <span class="status-label">攻撃力:</span>
            <span class="status-value">{{ character.attack }}</span>
          </div>
          <div class="status-item">
            <span class="status-label">防御力:</span>
            <span class="status-value">{{ character.defense }}</span>
          </div>
          <div class="status-item">
            <span class="status-label">所持金:</span>
            <span class="status-value">{{ character.gold }}G</span>
          </div>
        </div>
      </div>
      
      <!-- 敗因分析 -->
      <div class="defeat-analysis">
        <h3>🔍 敗因分析</h3>
        <div class="analysis-content">
          <p class="analysis-text">{{ defeatAnalysis }}</p>
          <div class="advice-section">
            <h4>💡 次回への助言</h4>
            <ul class="advice-list">
              <li v-for="(advice, index) in adviceList" :key="index">
                {{ advice }}
              </li>
            </ul>
          </div>
        </div>
      </div>
      
      <!-- 名言・格言 -->
      <div class="quote-section">
        <div class="quote-content">
          <p class="quote-text">"{{ randomQuote.text }}"</p>
          <p class="quote-author">{{ randomQuote.author }}</p>
        </div>
      </div>
      
      <!-- アクションボタン */
      <div class="gameover-actions">
        <button 
          @click="retryAdventure"
          class="action-btn retry-btn"
        >
          🔄 もう一度挑戦
        </button>
        
        <button 
          @click="returnToTown"
          class="action-btn town-btn"
        >
          🏘️ 町に戻る
        </button>
        
        <button 
          @click="viewHighScores"
          class="action-btn scores-btn"
        >
          🏆 記録を見る
        </button>
      </div>
      
      <!-- 復活オプション（将来の拡張用） -->
      <div v-if="showReviveOption" class="revive-option">
        <div class="revive-content">
          <h3>✨ 復活の機会</h3>
          <p>特別なアイテムで復活できるかもしれません...</p>
          <button class="action-btn revive-btn" disabled>
            🔮 復活アイテム (未実装)
          </button>
        </div>
      </div>
      
      <!-- 統計情報 -->
      <div class="statistics-footer">
        <p class="play-count">総プレイ回数: {{ totalPlayCount }}回</p>
        <p class="best-record">最高記録: {{ bestRecord }}</p>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'

export default {
  name: 'GameOverScreen',
  props: {
    character: {
      type: Object,
      required: true
    },
    gameStats: {
      type: Object,
      default: () => ({
        reachedFloor: 1,
        startTime: Date.now(),
        defeatedEnemies: 0,
        lastEnemy: null,
        deathCause: 'combat'
      })
    }
  },
  emits: ['restart', 'return-to-town'],
  
  setup(props, { emit }) {
    const showReviveOption = ref(false)
    const animationPhase = ref(0)
    
    // 冒険記録の計算
    const reachedFloor = computed(() => {
      return props.gameStats.reachedFloor || 1
    })
    
    const totalExp = computed(() => {
      return props.character.exp || 0
    })
    
    const totalGold = computed(() => {
      return props.character.gold || 0
    })
    
    const defeatedEnemies = computed(() => {
      return props.gameStats.defeatedEnemies || 0
    })
    
    const adventureTime = computed(() => {
      const timeDiff = Date.now() - (props.gameStats.startTime || Date.now())
      const minutes = Math.floor(timeDiff / 60000)
      const seconds = Math.floor((timeDiff % 60000) / 1000)
      return `${minutes}分${seconds}秒`
    })
    
    // 敗因分析
    const defeatAnalysis = computed(() => {
      const analyses = {
        combat: '戦闘中に力尽きました。より強力な装備やレベルアップが必要かもしれません。',
        low_hp: 'HPが不足していました。回復薬を多めに持参することをお勧めします。',
        strong_enemy: '強敵との遭遇でした。戦略を見直すか、より準備を整えてから挑戦しましょう。',
        early_game: '序盤での敗北です。基本的な戦闘システムに慣れることから始めましょう。'
      }
      
      const deathCause = props.gameStats.deathCause || 'combat'
      return analyses[deathCause] || analyses.combat
    })
    
    // アドバイスリスト
    const adviceList = computed(() => {
      const allAdvice = [
        'レベルアップしてから再挑戦しましょう',
        '回復薬を多めに持参することをお勧めします',
        '敵の攻撃パターンを観察して戦略を立てましょう',
        '宝箱からアイテムを入手してから進みましょう',
        '無理をせず、逃走も戦略の一つです',
        'ギルドでレベルアップしてから挑戦しましょう',
        '回復の泉でHPを満タンにしてからダンジョンに入りましょう'
      ]
      
      // ランダムに3つ選択
      const shuffled = [...allAdvice].sort(() => 0.5 - Math.random())
      return shuffled.slice(0, 3)
    })
    
    // 名言・格言
    const quotes = [
      { text: "失敗は成功のもと", author: "ことわざ" },
      { text: "七転び八起き", author: "ことわざ" },
      { text: "継続は力なり", author: "ことわざ" },
      { text: "石の上にも三年", author: "ことわざ" },
      { text: "負けるが勝ち", author: "ことわざ" },
      { text: "今日の負けは明日の勝ちの糧", author: "冒険者の格言" },
      { text: "真の勇者は何度でも立ち上がる", author: "古代の書" },
      { text: "経験こそが最高の師である", author: "賢者の言葉" }
    ]
    
    const randomQuote = computed(() => {
      return quotes[Math.floor(Math.random() * quotes.length)]
    })
    
    // ローカルストレージから統計取得
    const totalPlayCount = computed(() => {
      try {
        const saved = localStorage.getItem('rpg_total_plays')
        return saved ? parseInt(saved) + 1 : 1
      } catch {
        return 1
      }
    })
    
    const bestRecord = computed(() => {
      try {
        const saved = localStorage.getItem('rpg_best_record')
        if (saved) {
          const record = JSON.parse(saved)
          return `${record.floor}階・Lv.${record.level}`
        }
      } catch {
        // エラー時は現在の記録を返す
      }
      return `${reachedFloor.value}階・Lv.${props.character.level}`
    })
    
    // 統計情報の更新
    const updateStatistics = () => {
      try {
        // プレイ回数更新
        localStorage.setItem('rpg_total_plays', totalPlayCount.value.toString())
        
        // 最高記録更新チェック
        const currentRecord = {
          floor: reachedFloor.value,
          level: props.character.level,
          exp: props.character.exp
        }
        
        const savedBest = localStorage.getItem('rpg_best_record')
        if (savedBest) {
          const bestRecord = JSON.parse(savedBest)
          if (currentRecord.floor > bestRecord.floor || 
              (currentRecord.floor === bestRecord.floor && currentRecord.level > bestRecord.level)) {
            localStorage.setItem('rpg_best_record', JSON.stringify(currentRecord))
          }
        } else {
          localStorage.setItem('rpg_best_record', JSON.stringify(currentRecord))
        }
      } catch (error) {
        console.warn('Failed to update statistics:', error)
      }
    }
    
    // アクションハンドラー
    const retryAdventure = () => {
      emit('restart')
    }
    
    const returnToTown = () => {
      emit('return-to-town')
    }
    
    const viewHighScores = () => {
      alert(`最高記録: ${bestRecord.value}\n総プレイ回数: ${totalPlayCount.value}回`)
    }
    
    // 初期化
    onMounted(() => {
      updateStatistics()
      
      // アニメーション段階的実行
      setTimeout(() => animationPhase.value = 1, 1000)
      setTimeout(() => animationPhase.value = 2, 2000)
      setTimeout(() => animationPhase.value = 3, 3000)
      
      // 復活オプション表示（低確率）
      if (Math.random() < 0.1) {
        setTimeout(() => {
          showReviveOption.value = true
        }, 5000)
      }
    })
    
    return {
      showReviveOption,
      animationPhase,
      reachedFloor,
      totalExp,
      totalGold,
      defeatedEnemies,
      adventureTime,
      defeatAnalysis,
      adviceList,
      randomQuote,
      totalPlayCount,
      bestRecord,
      retryAdventure,
      returnToTown,
      viewHighScores
    }
  }
}
</script>

<style scoped>
.gameover-screen {
  min-height: 100vh;
  background: linear-gradient(135deg, #1a0000, #330000, #1a0000);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
}

.gameover-container {
  max-width: 600px;
  background-color: #220000;
  border: 3px solid #ff0000;
  border-radius: 15px;
  padding: 30px;
  text-align: center;
  box-shadow: 0 0 30px rgba(255, 0, 0, 0.3);
}

/* ゲームオーバータイトル */
.gameover-title h2 {
  color: #ff4444;
  font-size: 32px;
  margin-bottom: 15px;
  text-shadow: 2px 2px 4px rgba(0,0,0,0.8);
  animation: flicker 2s ease-in-out infinite;
}

.skull-animation {
  font-size: 48px;
  animation: pulse 2s ease-in-out infinite;
}

/* 敗北メッセージ */
.defeat-message {
  margin: 30px 0;
  padding: 20px;
  background-color: #330000;
  border: 1px solid #ff4444;
  border-radius: 10px;
}

.character-name {
  color: #ffff00;
  font-size: 20px;
  font-weight: bold;
  margin-bottom: 10px;
}

.defeat-text {
  color: #ff4444;
  font-size: 18px;
  margin-bottom: 15px;
}

.defeat-effect {
  margin-top: 15px;
}

.fade-text {
  color: #888;
  font-style: italic;
  animation: fadeInOut 3s ease-in-out infinite;
}

/* 冒険の記録 */
.adventure-record {
  margin: 25px 0;
  background-color: #001100;
  border: 2px solid #666;
  border-radius: 10px;
  padding: 20px;
}

.adventure-record h3 {
  color: #888;
  margin-bottom: 15px;
}

.record-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 10px;
}

.record-item {
  background-color: #222;
  border: 1px solid #444;
  border-radius: 5px;
  padding: 10px;
  text-align: center;
}

.record-label {
  display: block;
  color: #666;
  font-size: 12px;
  margin-bottom: 5px;
}

.record-value {
  color: #ff4444;
  font-weight: bold;
  font-size: 16px;
}

/* 最終ステータス */
.final-status {
  margin: 25px 0;
  background-color: #220011;
  border: 2px solid #666;
  border-radius: 10px;
  padding: 20px;
}

.final-status h3 {
  color: #ff6666;
  margin-bottom: 15px;
}

.status-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 10px;
}

.status-item {
  background-color: #330022;
  border: 1px solid #ff4444;
  border-radius: 5px;
  padding: 10px;
}

.status-label {
  display: block;
  color: #888;
  font-size: 12px;
  margin-bottom: 5px;
}

.status-value {
  color: #ff6666;
  font-weight: bold;
  font-size: 16px;
}

/* 敗因分析 */
.defeat-analysis {
  margin: 25px 0;
  background-color: #111111;
  border: 2px solid #444;
  border-radius: 10px;
  padding: 20px;
  text-align: left;
}

.defeat-analysis h3 {
  color: #ffaa00;
  margin-bottom: 15px;
  text-align: center;
}

.analysis-text {
  color: #ccc;
  margin-bottom: 15px;
  line-height: 1.6;
}

.advice-section h4 {
  color: #ffaa00;
  margin-bottom: 10px;
}

.advice-list {
  list-style: none;
  padding: 0;
}

.advice-list li {
  color: #aaa;
  margin-bottom: 8px;
  padding-left: 20px;
  position: relative;
}

.advice-list li::before {
  content: "💡";
  position: absolute;
  left: 0;
}

/* 名言セクション */
.quote-section {
  margin: 25px 0;
  padding: 20px;
  background-color: #001122;
  border: 1px solid #446688;
  border-radius: 10px;
}

.quote-text {
  color: #aaccff;
  font-style: italic;
  font-size: 16px;
  margin-bottom: 10px;
}

.quote-author {
  color: #6688aa;
  font-size: 14px;
  text-align: right;
}

/* アクションボタン */
.gameover-actions {
  display: flex;
  justify-content: center;
  gap: 15px;
  margin: 30px 0;
  flex-wrap: wrap;
}

.action-btn {
  padding: 12px 20px;
  border: 2px solid;
  border-radius: 8px;
  font-family: inherit;
  font-size: 16px;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.3s;
  min-width: 140px;
}

.retry-btn {
  background-color: #003300;
  color: #00ff00;
  border-color: #00ff00;
}

.retry-btn:hover {
  background-color: #006600;
  box-shadow: 0 0 15px rgba(0, 255, 0, 0.3);
}

.town-btn {
  background-color: #000033;
  color: #6666ff;
  border-color: #6666ff;
}

.town-btn:hover {
  background-color: #000066;
  box-shadow: 0 0 15px rgba(102, 102, 255, 0.3);
}

.scores-btn {
  background-color: #333300;
  color: #ffff00;
  border-color: #ffff00;
}

.scores-btn:hover {
  background-color: #666600;
  box-shadow: 0 0 15px rgba(255, 255, 0, 0.3);
}

.revive-btn {
  background-color: #333;
  color: #666;
  border-color: #444;
  cursor: not-allowed;
}

/* 復活オプション */
.revive-option {
  margin: 25px 0;
  padding: 20px;
  background-color: #110022;
  border: 2px dashed #666;
  border-radius: 10px;
}

.revive-content h3 {
  color: #aa66ff;
  margin-bottom: 10px;
}

.revive-content p {
  color: #888;
  margin-bottom: 15px;
}

/* 統計情報 */
.statistics-footer {
  margin-top: 30px;
  padding-top: 20px;
  border-top: 1px solid #444;
}

.statistics-footer p {
  color: #666;
  font-size: 14px;
  margin-bottom: 5px;
}

/* アニメーション */
@keyframes flicker {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.7; }
}

@keyframes pulse {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.1); }
}

@keyframes fadeInOut {
  0%, 100% { opacity: 0.5; }
  50% { opacity: 1; }
}

/* レスポンシブ対応 */
@media (max-width: 600px) {
  .gameover-container {
    padding: 20px;
  }
  
  .gameover-title h2 {
    font-size: 28px;
  }
  
  .gameover-actions {
    flex-direction: column;
    align-items: center;
  }
  
  .action-btn {
    width: 100%;
    max-width: 250px;
  }
  
  .record-stats,
  .status-grid {
    grid-template-columns: 1fr;
  }
}
</style>