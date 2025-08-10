<template>
  <div class="combat-screen">
    <h2>⚔️ 戦闘！</h2>
    
    <div class="combat-area">
      <!-- 敵の情報 -->
      <div class="enemy-section">
        <h3>{{ currentEnemy.name }}</h3>
        <div class="enemy-hp">
          HP: {{ currentEnemy.hp }}/{{ currentEnemy.maxHp }}
          <div class="hp-bar">
            <div 
              class="hp-fill enemy" 
              :style="{ width: enemyHpPercentage + '%' }"
            ></div>
          </div>
        </div>
      </div>
      
      <!-- プレイヤーの情報 -->
      <div class="player-section">
        <h3>{{ character.name }}</h3>
        <div class="player-hp">
          HP: {{ character.hp }}/{{ character.maxHp }}
          <div class="hp-bar">
            <div 
              class="hp-fill player" 
              :style="{ width: playerHpPercentage + '%' }"
            ></div>
          </div>
        </div>
        <div class="player-stats">
          <span>攻撃: {{ character.attack }}</span>
          <span>防御: {{ character.defense }}</span>
        </div>
      </div>
    </div>
    
    <!-- 戦闘ログ -->
    <div class="combat-log">
      <div 
        v-for="(message, index) in combatMessages" 
        :key="index"
        class="combat-message"
        :class="getMessageClass(message)"
      >
        {{ message.text }}
      </div>
    </div>
    
    <!-- 戦闘アクション -->
    <div class="combat-actions" v-if="!battleEnded">
      <button 
        @click="attack"
        :disabled="loading || waitingForEnemy"
        class="action-btn attack-btn"
      >
        ⚔️ 攻撃
      </button>
      
      <button 
        @click="usePotion"
        :disabled="loading || waitingForEnemy || !canUsePotion"
        class="action-btn potion-btn"
      >
        🧪 回復薬使用
      </button>
      
      <button 
        @click="flee"
        :disabled="loading || waitingForEnemy"
        class="action-btn flee-btn"
      >
        🏃 逃げる
      </button>
    </div>
    
    <!-- 戦闘終了時のアクション -->
    <div class="combat-end-actions" v-if="battleEnded">
      <button 
        @click="continueBattle"
        class="action-btn continue-btn"
      >
        {{ battleResult.victory ? '✅ 続ける' : '💀 町に戻る' }}
      </button>
    </div>
    
    <!-- ローディング表示 -->
    <div v-if="loading" class="loading-overlay">
      <div class="loading-text">戦闘処理中...</div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted, watch } from 'vue'
import { charactersAPI } from '../../api/characters.js'

export default {
  name: 'CombatScreen',
  props: {
    character: {
      type: Object,
      required: true
    },
    enemy: {
      type: Object,
      required: true
    }
  },
  emits: ['combat-end', 'character-updated'],
  
  setup(props, { emit }) {
    const loading = ref(false)
    const waitingForEnemy = ref(false)
    const battleEnded = ref(false)
    const combatMessages = ref([])
    const battleResult = ref({ victory: false, fled: false })
    
    // 現在の敵データ（変更可能）
    const currentEnemy = ref({ ...props.enemy })
    const currentCharacter = ref({ ...props.character })
    
    // 定数
    const POTION_HEAL = { min: 20, max: 30 }
    const FLEE_SUCCESS_RATE = 0.7
    
    // 計算プロパティ
    const enemyHpPercentage = computed(() => {
      return Math.round((currentEnemy.value.hp / currentEnemy.value.maxHp) * 100)
    })
    
    const playerHpPercentage = computed(() => {
      return Math.round((currentCharacter.value.hp / currentCharacter.value.maxHp) * 100)
    })
    
    const canUsePotion = computed(() => {
      return currentCharacter.value.hp < currentCharacter.value.maxHp
    })
    
    // 戦闘メッセージの追加
    const addCombatMessage = (text, type = 'normal') => {
      combatMessages.value.push({ text, type, timestamp: Date.now() })
      
      // メッセージ数制限
      if (combatMessages.value.length > 10) {
        combatMessages.value = combatMessages.value.slice(-10)
      }
      
      // 自動スクロール
      setTimeout(() => {
        const log = document.querySelector('.combat-log')
        if (log) log.scrollTop = log.scrollHeight
      }, 50)
    }
    
    const getMessageClass = (message) => {
      return {
        'damage-message': message.type === 'damage',
        'heal-message': message.type === 'heal',
        'system-message': message.type === 'system',
        'victory-message': message.type === 'victory',
        'defeat-message': message.type === 'defeat'
      }
    }
    
    // 攻撃処理
    const attack = async () => {
      loading.value = true
      waitingForEnemy.value = false
      
      try {
        // プレイヤー攻撃
        const playerDamage = Math.max(1, currentCharacter.value.attack - Math.floor(Math.random() * 3))
        currentEnemy.value.hp = Math.max(0, currentEnemy.value.hp - playerDamage)
        
        addCombatMessage(`${currentEnemy.value.name}に${playerDamage}のダメージ！`, 'damage')
        
        // 敵撃破チェック
        if (currentEnemy.value.hp <= 0) {
          await handleEnemyDefeated()
          return
        }
        
        // 短い待機
        await new Promise(resolve => setTimeout(resolve, 1000))
        
        // 敵攻撃
        await enemyAttack()
        
      } finally {
        loading.value = false
      }
    }
    
    // 敵の攻撃
    const enemyAttack = async () => {
      waitingForEnemy.value = true
      
      await new Promise(resolve => setTimeout(resolve, 1500))
      
      const enemyDamage = Math.max(1, currentEnemy.value.attack - currentCharacter.value.defense)
      currentCharacter.value.hp = Math.max(0, currentCharacter.value.hp - enemyDamage)
      
      addCombatMessage(`${enemyDamage}のダメージを受けました！`, 'damage')
      
      // プレイヤー敗北チェック
      if (currentCharacter.value.hp <= 0) {
        await handlePlayerDefeated()
        return
      }
      
      waitingForEnemy.value = false
    }
    
    // 敵撃破処理
    const handleEnemyDefeated = async () => {
      addCombatMessage(`${currentEnemy.value.name}を倒しました！`, 'victory')
      
      // 経験値とゴールド獲得
      const expGained = getRandomReward(currentEnemy.value.expReward)
      const goldGained = getRandomReward(currentEnemy.value.goldReward)
      
      currentCharacter.value.exp += expGained
      currentCharacter.value.gold += goldGained
      
      addCombatMessage(`${expGained}EXP、${goldGained}G を獲得！`, 'victory')
      
      // アイテムドロップ判定
      if (Math.random() < 0.4) {
        addCombatMessage('回復薬を見つけました！', 'heal')
      }
      
      // キャラクター更新
      try {
        const updatedCharacter = await charactersAPI.update(currentCharacter.value.id, currentCharacter.value)
        emit('character-updated', updatedCharacter)
      } catch (error) {
        console.error('Failed to update character:', error)
      }
      
      battleEnded.value = true
      battleResult.value = { victory: true, fled: false }
    }
    
    // プレイヤー敗北処理
    const handlePlayerDefeated = async () => {
      addCombatMessage('力尽きてしまいました...', 'defeat')
      
      battleEnded.value = true
      battleResult.value = { victory: false, fled: false }
    }
    
    // 回復薬使用
    const usePotion = async () => {
      if (!canUsePotion.value) return
      
      loading.value = true
      
      try {
        const healAmount = POTION_HEAL.min + Math.floor(Math.random() * (POTION_HEAL.max - POTION_HEAL.min + 1))
        currentCharacter.value.hp = Math.min(currentCharacter.value.maxHp, currentCharacter.value.hp + healAmount)
        
        addCombatMessage(`${healAmount}HP回復しました！`, 'heal')
        
        // 短い待機後、敵攻撃
        await new Promise(resolve => setTimeout(resolve, 1000))
        await enemyAttack()
        
      } finally {
        loading.value = false
      }
    }
    
    // 逃走処理
    const flee = async () => {
      loading.value = true
      
      try {
        if (Math.random() < FLEE_SUCCESS_RATE) {
          addCombatMessage('逃げ出しました！', 'system')
          
          await new Promise(resolve => setTimeout(resolve, 1000))
          
          battleEnded.value = true
          battleResult.value = { victory: false, fled: true }
        } else {
          addCombatMessage('逃げられませんでした！', 'system')
          
          await new Promise(resolve => setTimeout(resolve, 1000))
          await enemyAttack()
        }
      } finally {
        loading.value = false
      }
    }
    
    // 戦闘続行
    const continueBattle = () => {
      emit('combat-end', battleResult.value)
    }
    
    // ユーティリティ関数
    const getRandomReward = (rewardRange) => {
      return rewardRange.min + Math.floor(Math.random() * (rewardRange.max - rewardRange.min + 1))
    }
    
    // 初期化
    onMounted(() => {
      addCombatMessage(`${currentEnemy.value.name}と遭遇！`, 'system')
    })
    
    // キャラクター変更監視
    watch(() => props.character, (newCharacter) => {
      currentCharacter.value = { ...newCharacter }
    }, { deep: true })
    
    return {
      loading,
      waitingForEnemy,
      battleEnded,
      combatMessages,
      battleResult,
      currentEnemy,
      currentCharacter,
      enemyHpPercentage,
      playerHpPercentage,
      canUsePotion,
      addCombatMessage,
      getMessageClass,
      attack,
      usePotion,
      flee,
      continueBattle
    }
  }
}
</script>

<style scoped>
.combat-screen {
  max-width: 600px;
  margin: 0 auto;
  padding: 20px;
  background-color: #330000;
  border: 2px solid #ff0000;
  border-radius: 10px;
  text-align: center;
  position: relative;
}

.combat-screen h2 {
  color: #ff4444;
  margin-bottom: 20px;
  font-size: 24px;
  text-shadow: 2px 2px 4px rgba(0,0,0,0.8);
}

.combat-area {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
  margin-bottom: 20px;
}

.enemy-section,
.player-section {
  background-color: #001100;
  border: 1px solid #ff0000;
  border-radius: 5px;
  padding: 15px;
}

.enemy-section h3,
.player-section h3 {
  color: #ffff00;
  margin-bottom: 10px;
}

.enemy-hp,
.player-hp {
  margin-bottom: 10px;
  color: #00ff00;
}

.hp-bar {
  width: 100%;
  height: 10px;
  background-color: #330000;
  border-radius: 5px;
  overflow: hidden;
  margin-top: 5px;
}

.hp-fill.enemy {
  height: 100%;
  background: linear-gradient(90deg, #ff4444, #ffaa00);
  transition: width 0.5s;
}

.hp-fill.player {
  height: 100%;
  background: linear-gradient(90deg, #ff4444, #ffaa00, #00ff00);
  transition: width 0.5s;
}

.player-stats {
  display: flex;
  justify-content: space-between;
  color: #888;
  font-size: 14px;
}

.combat-log {
  height: 150px;
  overflow-y: auto;
  background-color: #001100;
  border: 1px solid #00ff00;
  border-radius: 5px;
  padding: 10px;
  margin-bottom: 20px;
  text-align: left;
}

.combat-message {
  margin-bottom: 5px;
  font-size: 14px;
  line-height: 1.4;
}

.combat-message:last-child {
  margin-bottom: 0;
}

.damage-message {
  color: #ff4444;
}

.heal-message {
  color: #00ff00;
}

.system-message {
  color: #ffaa00;
}

.victory-message {
  color: #ffff00;
  font-weight: bold;
}

.defeat-message {
  color: #ff0000;
  font-weight: bold;
}

.combat-actions,
.combat-end-actions {
  display: flex;
  justify-content: center;
  gap: 15px;
  flex-wrap: wrap;
}

.action-btn {
  padding: 12px 20px;
  border: 2px solid;
  border-radius: 5px;
  font-family: inherit;
  font-size: 16px;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.3s;
  min-width: 120px;
}

.attack-btn {
  background-color: #330000;
  color: #ff4444;
  border-color: #ff4444;
}

.attack-btn:hover:not(:disabled) {
  background-color: #660000;
  box-shadow: 0 0 15px rgba(255, 68, 68, 0.3);
}

.potion-btn {
  background-color: #003300;
  color: #00ff00;
  border-color: #00ff00;
}

.potion-btn:hover:not(:disabled) {
  background-color: #006600;
  box-shadow: 0 0 15px rgba(0, 255, 0, 0.3);
}

.flee-btn {
  background-color: #333300;
  color: #ffff00;
  border-color: #ffff00;
}

.flee-btn:hover:not(:disabled) {
  background-color: #666600;
  box-shadow: 0 0 15px rgba(255, 255, 0, 0.3);
}

.continue-btn {
  background-color: #000033;
  color: #6666ff;
  border-color: #6666ff;
}

.continue-btn:hover {
  background-color: #000066;
  box-shadow: 0 0 15px rgba(102, 102, 255, 0.3);
}

.action-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.loading-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.8);
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 10px;
}

.loading-text {
  color: #ffff00;
  font-size: 18px;
  font-weight: bold;
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0% { opacity: 1; }
  50% { opacity: 0.5; }
  100% { opacity: 1; }
}

/* レスポンシブ対応 */
@media (max-width: 600px) {
  .combat-area {
    grid-template-columns: 1fr;
  }
  
  .combat-actions,
  .combat-end-actions {
    flex-direction: column;
    align-items: center;
  }
  
  .action-btn {
    width: 100%;
    max-width: 200px;
  }
}
</style>