<template>
  <div class="dungeon-view">
    <div class="dungeon-container">
      <!-- マップエリア -->
      <div class="map-container">
        <div class="dungeon-map">
          <div 
            v-for="(cell, index) in mapDisplay" 
            :key="index"
            :class="['cell', getCellClass(cell)]"
          >
            {{ getCellSymbol(cell) }}
          </div>
        </div>
        
        <!-- 移動コントロール -->
        <div class="controls">
          <div class="control-row">
            <button @click="move('up')" :disabled="loading" class="control-btn">
              ⬆️ 北
            </button>
          </div>
          <div class="control-row">
            <button @click="move('left')" :disabled="loading" class="control-btn">
              ⬅️ 西
            </button>
            <button @click="move('down')" :disabled="loading" class="control-btn">
              ⬇️ 南
            </button>
            <button @click="move('right')" :disabled="loading" class="control-btn">
              ➡️ 東
            </button>
          </div>
        </div>
      </div>
      
      <!-- ステータスパネル -->
      <div class="status-panel">
        <h3>{{ character.name }} の状態</h3>
        
        <div class="status-info">
          <div class="floor-info">
            <strong>🏰 {{ localGameProgress.currentFloor }}階</strong>
          </div>
          <div class="hp-info">
            HP: {{ character.hp }}/{{ character.maxHp }}
            <div class="hp-bar">
              <div 
                class="hp-fill" 
                :style="{ width: hpPercentage + '%' }"
              ></div>
            </div>
          </div>
          <div class="attack-info">攻撃力: {{ character.attack }}</div>
          <div class="position-info">位置: ({{ localGameProgress.playerX }}, {{ localGameProgress.playerY }})</div>
          <div class="items-info">
            <div>🗝️ 鍵: {{ localGameProgress.keys }}個</div>
            <div>🧪 回復薬: {{ localGameProgress.potions }}個</div>
          </div>
        </div>
        
        <!-- メッセージログ -->
        <div class="message-log">
          <div 
            v-for="(message, index) in localGameProgress.messages" 
            :key="index"
            class="message"
          >
            {{ message }}
          </div>
        </div>
        
        <!-- アクションボタン -->
        <div class="action-buttons">
          <!-- 回復薬使用 -->
          <button 
            @click="usePotion"
            :disabled="!canUsePotion || loading"
            class="action-btn potion-btn"
          >
            🧪 回復薬使用
          </button>
          
          <!-- 階段ボタン -->
          <div v-if="adjacentStairs" class="action-section">
            <button 
              @click="useStairs"
              :disabled="loading"
              class="action-btn stairs-btn"
            >
              {{ getStairsButtonText() }}
            </button>
          </div>
          
          <!-- 扉ボタン -->
          <div v-if="adjacentDoor" class="action-section">
            <button 
              v-if="!adjacentDoor.isOpen && !adjacentDoor.isLocked"
              @click="openDoor"
              :disabled="loading"
              class="action-btn door-btn"
            >
              🚪 扉を開ける
            </button>
            <button 
              v-if="!adjacentDoor.isOpen && adjacentDoor.isLocked && localGameProgress.keys > 0"
              @click="unlockDoor"
              :disabled="loading"
              class="action-btn door-btn"
            >
              🗝️ 鍵で扉を開ける
            </button>
            <button 
              v-if="!adjacentDoor.isOpen && adjacentDoor.isLocked && localGameProgress.keys === 0"
              disabled
              class="action-btn door-btn disabled"
            >
              🗝️ 鍵が必要です
            </button>
          </div>
          
          <!-- 宝箱ボタン -->
          <div v-if="adjacentChest" class="action-section">
            <button 
              v-if="!adjacentChest.isOpened"
              @click="openChest"
              :disabled="loading"
              class="action-btn chest-btn"
            >
              📦 宝箱を開ける
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- エラーメッセージ -->
    <div v-if="error" class="error-message">
      {{ error }}
    </div>
    
    <!-- デバッグ情報（開発時のみ） -->
    <div v-if="showDebugInfo" class="debug-panel">
      <h4>🐛 Debug Info</h4>
      <div>Player Position: ({{ localGameProgress.playerX }}, {{ localGameProgress.playerY }})</div>
      <div>Current Floor: {{ localGameProgress.currentFloor }}</div>
      <div>Loading: {{ loading }}</div>
      <div>Can Move Up: {{ isValidPositionDebug(localGameProgress.playerX, localGameProgress.playerY - 1) }}</div>
      <div>Can Move Down: {{ isValidPositionDebug(localGameProgress.playerX, localGameProgress.playerY + 1) }}</div>
      <div>Can Move Left: {{ isValidPositionDebug(localGameProgress.playerX - 1, localGameProgress.playerY) }}</div>
      <div>Can Move Right: {{ isValidPositionDebug(localGameProgress.playerX + 1, localGameProgress.playerY) }}</div>
    </div>
  </div>
</template>

<script>
import { ref, computed, watch, nextTick } from 'vue'
import { savesAPI } from '../../api/saves.js'

export default {
  name: 'DungeonView',
  props: {
    character: {
      type: Object,
      required: true
    },
    gameProgress: {
      type: Object,
      required: true
    }
  },
  emits: [
    'combat-start', 
    'victory', 
    'game-progress-updated', 
    'character-updated',
    'return-to-town'
  ],
  
  setup(props, { emit }) {
    const loading = ref(false)
    const error = ref('')
    const showDebugInfo = ref(true) // デバッグ用
    
    // ローカル状態として gameProgress をコピー（即座に更新するため）
    const localGameProgress = ref({ ...props.gameProgress })
    
    // 定数
    const VIEW_RANGE = 2
    const MAP_SIZE = 8
    const POTION_HEAL = { min: 20, max: 30 }
    
    // ダンジョンマップ
    const dungeonMaps = savesAPI.getDungeonMaps()
    const cellTypes = savesAPI.getCellTypes()
    
    // propsの変更を監視してローカル状態を更新
    watch(() => props.gameProgress, (newProgress) => {
      console.log('GameProgress updated from parent:', newProgress)
      localGameProgress.value = { ...newProgress }
    }, { deep: true, immediate: true })
    
    // 計算プロパティ
    const hpPercentage = computed(() => {
      return Math.round((props.character.hp / props.character.maxHp) * 100)
    })
    
    const canUsePotion = computed(() => {
      return localGameProgress.value.potions > 0 && 
             props.character.hp < props.character.maxHp
    })
    
    // マップ表示用の計算プロパティ（ローカル状態使用）
    const mapDisplay = computed(() => {
      const display = []
      
      for (let dy = -VIEW_RANGE; dy <= VIEW_RANGE; dy++) {
        for (let dx = -VIEW_RANGE; dx <= VIEW_RANGE; dx++) {
          const x = localGameProgress.value.playerX + dx
          const y = localGameProgress.value.playerY + dy
          
          if (dx === 0 && dy === 0) {
            display.push('player')
            continue
          }
          
          if (x < 0 || x >= MAP_SIZE || y < 0 || y >= MAP_SIZE) {
            display.push('unknown')
            continue
          }
          
          display.push(getCellType(x, y))
        }
      }
      return display
    })
    
    // 隣接する特殊セルの検出（ローカル状態使用）
    const adjacentStairs = computed(() => {
      return findAdjacentCell([cellTypes.STAIRS_UP, cellTypes.STAIRS_DOWN], (cell, x, y) => {
        const isUp = cell === cellTypes.STAIRS_UP
        const isExit = localGameProgress.value.currentFloor === 1 && isUp
        const canUse = isExit || (isUp ? localGameProgress.value.currentFloor > 1 : localGameProgress.value.currentFloor < 3)
        
        return { isUp, canUse, isExit }
      })
    })
    
    const adjacentDoor = computed(() => {
      return findAdjacentCell([cellTypes.DOOR, cellTypes.LOCKED_DOOR], (cell, x, y) => {
        const doorKey = `${localGameProgress.value.currentFloor}-${x}-${y}`
        return {
          x, y,
          isOpen: localGameProgress.value.doorStates[doorKey] || false,
          isLocked: cell === cellTypes.LOCKED_DOOR,
          key: doorKey
        }
      })
    })
    
    const adjacentChest = computed(() => {
      return findAdjacentCell([cellTypes.CHEST], (cell, x, y) => {
        const chestKey = `${localGameProgress.value.currentFloor}-${x}-${y}`
        return {
          x, y,
          isOpened: localGameProgress.value.chestStates[chestKey] || false,
          key: chestKey
        }
      })
    })
    
    // ユーティリティ関数（ローカル状態使用）
    const getCellType = (x, y) => {
      const cell = dungeonMaps[localGameProgress.value.currentFloor][y][x]
      
      if (cell === cellTypes.WALL) return 'wall'
      if (cell === cellTypes.FLOOR || cell === cellTypes.ENEMY) return 'floor'
      if (cell === cellTypes.GOAL) return 'goal'
      if (cell === cellTypes.DOOR) {
        const doorKey = `${localGameProgress.value.currentFloor}-${x}-${y}`
        return localGameProgress.value.doorStates[doorKey] ? 'door-open' : 'door-closed'
      }
      if (cell === cellTypes.LOCKED_DOOR) {
        const doorKey = `${localGameProgress.value.currentFloor}-${x}-${y}`
        return localGameProgress.value.doorStates[doorKey] ? 'door-open' : 'door-locked'
      }
      if (cell === cellTypes.CHEST) {
        const chestKey = `${localGameProgress.value.currentFloor}-${x}-${y}`
        return localGameProgress.value.chestStates[chestKey] ? 'treasure-opened' : 'treasure-chest'
      }
      if (cell === cellTypes.STAIRS_UP) return 'stairs-up'
      if (cell === cellTypes.STAIRS_DOWN) return 'stairs-down'
      
      return 'floor'
    }
    
    const findAdjacentCell = (cellTypeList, dataFactory) => {
      const directions = [
        { dx: 0, dy: -1 }, { dx: 0, dy: 1 }, { dx: -1, dy: 0 }, { dx: 1, dy: 0 }
      ]
      
      for (let dir of directions) {
        const x = localGameProgress.value.playerX + dir.dx
        const y = localGameProgress.value.playerY + dir.dy
        
        if (x >= 0 && x < MAP_SIZE && y >= 0 && y < MAP_SIZE) {
          const cell = dungeonMaps[localGameProgress.value.currentFloor][y][x]
          if (cellTypeList.includes(cell)) {
            return dataFactory(cell, x, y)
          }
        }
      }
      return null
    }
    
    const getCellClass = (cell) => {
      return cell
    }
    
    const getCellSymbol = (cell) => {
      const symbols = {
        'wall': '█',
        'floor': '·',
        'player': '@',
        'enemy': 'M',
        'goal': '★',
        'unknown': '?',
        'visited': '·',
        'door-closed': '┃',
        'door-open': '╱',
        'door-locked': '🔒',
        'treasure-chest': '📦',
        'treasure-opened': '📭',
        'stairs-up': '⬆️',
        'stairs-down': '⬇️'
      }
      return symbols[cell] || ' '
    }
    
    const getStairsButtonText = () => {
      if (!adjacentStairs.value) return ''
      if (adjacentStairs.value.isExit) return '🏘️ 町に戻る'
      return adjacentStairs.value.isUp ? '⬆️ 上の階に行く' : '⬇️ 下の階に行く'
    }
    
    // ローカル状態を更新し、親に通知する関数
    const updateGameProgress = async (updatedProgress) => {
      console.log('Updating game progress:', updatedProgress)
      
      // ローカル状態を即座に更新
      localGameProgress.value = { ...updatedProgress }
      
      // 親コンポーネントに通知
      emit('game-progress-updated', updatedProgress)
      
      // DOM更新を待つ
      await nextTick()
    }
    
    const addMessage = async (text) => {
      const updatedProgress = { ...localGameProgress.value }
      updatedProgress.messages = [...localGameProgress.value.messages, text]
      
      if (updatedProgress.messages.length > 10) {
        updatedProgress.messages = updatedProgress.messages.slice(-10)
      }
      
      await updateGameProgress(updatedProgress)
    }
    
    // 移動処理の修正
    const move = async (direction) => {
      if (loading.value) {
        console.log('Move blocked: loading')
        return
      }
      
      const directions = {
        'up': { x: 0, y: -1 },
        'down': { x: 0, y: 1 },
        'left': { x: -1, y: 0 },
        'right': { x: 1, y: 0 }
      }
      
      const dir = directions[direction]
      if (!dir) return
      
      const currentX = localGameProgress.value.playerX
      const currentY = localGameProgress.value.playerY
      const newX = currentX + dir.x
      const newY = currentY + dir.y
      
      console.log(`Attempting move from (${currentX}, ${currentY}) to (${newX}, ${newY})`)
      
      if (!isValidPosition(newX, newY)) {
        await addMessage('そちらには進めません...')
        return
      }
      
      const cell = dungeonMaps[localGameProgress.value.currentFloor][newY][newX]
      console.log(`Target cell type: ${cell}`)
      
      if (!(await canMoveToCell(cell, newX, newY))) return
      
      // 移動実行
      loading.value = true
      try {
        await movePlayer(newX, newY)
        await handleCellEvent(cell)
      } finally {
        loading.value = false
      }
    }
    
    const isValidPosition = (x, y) => {
      if (x < 0 || x >= MAP_SIZE || y < 0 || y >= MAP_SIZE) {
        console.log(`Invalid position: out of bounds (${x}, ${y})`)
        return false
      }
      
      if (!dungeonMaps[localGameProgress.value.currentFloor] || 
          !dungeonMaps[localGameProgress.value.currentFloor][y]) {
        console.log(`Invalid position: no map data for floor ${localGameProgress.value.currentFloor}`)
        return false
      }
      
      const cell = dungeonMaps[localGameProgress.value.currentFloor][y][x]
      const isValid = cell !== cellTypes.WALL
      console.log(`Position (${x}, ${y}) cell type: ${cell}, valid: ${isValid}`)
      return isValid
    }
    
    const canMoveToCell = async (cell, x, y) => {
      if (cell === cellTypes.DOOR || cell === cellTypes.LOCKED_DOOR) {
        const doorKey = `${localGameProgress.value.currentFloor}-${x}-${y}`
        if (!localGameProgress.value.doorStates[doorKey]) {
          await addMessage('扉が閉まっています。')
          return false
        }
      }
      
      if (cell === cellTypes.CHEST) {
        const chestKey = `${localGameProgress.value.currentFloor}-${x}-${y}`
        if (!localGameProgress.value.chestStates[chestKey]) {
          await addMessage('宝箱があるため進めません。')
          return false
        }
      }
      
      if (cell === cellTypes.STAIRS_UP || cell === cellTypes.STAIRS_DOWN) {
        await addMessage('階段があります。階段ボタンを使ってください。')
        return false
      }
      
      return true
    }
    
    const movePlayer = async (x, y) => {
      console.log(`Moving player to (${x}, ${y})`)
      const updatedProgress = savesAPI.updatePlayerPosition(
        localGameProgress.value, 
        localGameProgress.value.currentFloor, 
        x, 
        y
      )
      await updateGameProgress(updatedProgress)
    }
    
    const handleCellEvent = async (cell) => {
      if (cell === cellTypes.ENEMY) {
        const enemy = savesAPI.generateRandomEnemy()
        emit('combat-start', enemy)
      } else if (cell === cellTypes.GOAL) {
        emit('victory', { gold: 500, exp: 200 })
      } else {
        await addMessage(`(${localGameProgress.value.playerX}, ${localGameProgress.value.playerY})に移動しました`)
      }
    }
    
    // 回復薬使用（ローカル状態使用）
    const usePotion = async () => {
      if (!canUsePotion.value) return
      
      loading.value = true
      try {
        const healAmount = POTION_HEAL.min + Math.floor(Math.random() * (POTION_HEAL.max - POTION_HEAL.min + 1))
        const newHp = Math.min(props.character.maxHp, props.character.hp + healAmount)
        
        const updatedCharacter = { ...props.character, hp: newHp }
        const updatedProgress = savesAPI.updateItems(localGameProgress.value, localGameProgress.value.potions - 1, undefined)
        
        emit('character-updated', updatedCharacter)
        await updateGameProgress(updatedProgress)
        await addMessage(`${healAmount}HP回復しました！`)
      } finally {
        loading.value = false
      }
    }
    
    // 階段使用（ローカル状態使用）
    const useStairs = async () => {
      if (!adjacentStairs.value || !adjacentStairs.value.canUse) return
      
      if (adjacentStairs.value.isExit) {
        emit('return-to-town')
        return
      }
      
      loading.value = true
      try {
        const newFloor = localGameProgress.value.currentFloor + (adjacentStairs.value.isUp ? -1 : 1)
        const playerPos = localGameProgress.value.playerPositions[newFloor]
        
        const updatedProgress = savesAPI.updatePlayerPosition(localGameProgress.value, newFloor, playerPos.x, playerPos.y)
        await updateGameProgress(updatedProgress)
        await addMessage(`${newFloor}階に移動しました。`)
      } finally {
        loading.value = false
      }
    }
    
    // 扉を開ける（ローカル状態使用）
    const openDoor = async () => {
      if (!adjacentDoor.value || adjacentDoor.value.isOpen || adjacentDoor.value.isLocked) return
      
      loading.value = true
      try {
        const updatedProgress = savesAPI.updateDoorState(
          localGameProgress.value,
          localGameProgress.value.currentFloor,
          adjacentDoor.value.x,
          adjacentDoor.value.y,
          true
        )
        
        await updateGameProgress(updatedProgress)
        await addMessage('扉を開けました。')
      } finally {
        loading.value = false
      }
    }
    
    // 鍵で扉を開ける（ローカル状態使用）
    const unlockDoor = async () => {
      if (!adjacentDoor.value || adjacentDoor.value.isOpen || !adjacentDoor.value.isLocked || localGameProgress.value.keys === 0) return
      
      loading.value = true
      try {
        let updatedProgress = savesAPI.updateDoorState(
          localGameProgress.value,
          localGameProgress.value.currentFloor,
          adjacentDoor.value.x,
          adjacentDoor.value.y,
          true
        )
        
        updatedProgress = savesAPI.updateItems(updatedProgress, undefined, localGameProgress.value.keys - 1)
        
        await updateGameProgress(updatedProgress)
        await addMessage(`鍵を使って扉を開けました！残り${localGameProgress.value.keys - 1}個`)
      } finally {
        loading.value = false
      }
    }
    
    // 宝箱を開ける（ローカル状態使用）
    const openChest = async () => {
      if (!adjacentChest.value || adjacentChest.value.isOpened) return
      
      loading.value = true
      try {
        let updatedProgress = savesAPI.updateChestState(
          localGameProgress.value,
          localGameProgress.value.currentFloor,
          adjacentChest.value.x,
          adjacentChest.value.y,
          true
        )
        
        const treasure = savesAPI.generateTreasure()
        
        if (treasure.type === 'key') {
          updatedProgress = savesAPI.updateItems(updatedProgress, undefined, localGameProgress.value.keys + 1)
        } else if (treasure.type === 'potion') {
          updatedProgress = savesAPI.updateItems(updatedProgress, localGameProgress.value.potions + 1, undefined)
        }
        
        updatedProgress = savesAPI.addMessage(updatedProgress, '宝箱を開けました！')
        updatedProgress = savesAPI.addMessage(updatedProgress, treasure.message)
        
        await updateGameProgress(updatedProgress)
      } finally {
        loading.value = false
      }
    }
    
    // デバッグ用の検証関数
    const isValidPositionDebug = (x, y) => {
      try {
        return isValidPosition(x, y)
      } catch (error) {
        console.error('Error in isValidPosition:', error)
        return false
      }
    }
    
    return {
      loading,
      error,
      showDebugInfo,
      localGameProgress,
      hpPercentage,
      canUsePotion,
      mapDisplay,
      adjacentStairs,
      adjacentDoor,
      adjacentChest,
      getCellClass,
      getCellSymbol,
      getStairsButtonText,
      move,
      usePotion,
      useStairs,
      openDoor,
      unlockDoor,
      openChest,
      isValidPositionDebug
    }
  }
}
</script>

<style scoped>
.dungeon-view {
  padding: 20px;
}

.dungeon-container {
  display: flex;
  gap: 20px;
  align-items: flex-start;
  max-width: 1000px;
  margin: 0 auto;
}

/* マップコンテナ */
.map-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.dungeon-map {
  display: grid;
  grid-template-columns: repeat(5, 40px);
  gap: 1px;
  border: 2px solid #00ff00;
  padding: 10px;
  background-color: #000;
  margin-bottom: 20px;
}

.cell {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  font-weight: bold;
}

.wall { background-color: #333; }
.floor { background-color: #002200; }
.player { background-color: #0066ff; color: white; }
.enemy { background-color: #ff0000; color: white; }
.goal { background-color: #ffff00; color: black; }
.unknown { background-color: #111; color: #444; }
.visited { background-color: #001100; color: #666; }
.door-closed { background-color: #8B4513; color: #DEB887; }
.door-open { background-color: #654321; color: #8B4513; }
.door-locked { background-color: #8B0000; color: #FFD700; }
.treasure-chest { background-color: #DAA520; color: #8B4513; }
.treasure-opened { background-color: #CD853F; color: #654321; }
.stairs-up { background-color: #4169E1; color: white; }
.stairs-down { background-color: #8A2BE2; color: white; }

/* コントロール */
.controls {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
}

.control-row {
  display: flex;
  gap: 10px;
}

.control-btn {
  padding: 10px 15px;
  background-color: #003300;
  color: #00ff00;
  border: 2px solid #00ff00;
  border-radius: 5px;
  font-family: inherit;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.3s;
  min-width: 80px;
}

.control-btn:hover:not(:disabled) {
  background-color: #006600;
  box-shadow: 0 0 10px rgba(0, 255, 0, 0.3);
}

.control-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* ステータスパネル */
.status-panel {
  min-width: 280px;
  background-color: #000;
  border: 2px solid #00ff00;
  border-radius: 5px;
  padding: 15px;
  height: fit-content;
}

.status-panel h3 {
  color: #ffff00;
  margin-bottom: 15px;
  text-align: center;
}

.status-info {
  margin-bottom: 15px;
}

.floor-info {
  color: #ffff00;
  font-size: 18px;
  text-align: center;
  margin-bottom: 10px;
}

.hp-info {
  color: #00ff00;
  margin-bottom: 8px;
}

.hp-bar {
  width: 100%;
  height: 10px;
  background-color: #330000;
  border-radius: 5px;
  overflow: hidden;
  margin-top: 5px;
}

.hp-fill {
  height: 100%;
  background: linear-gradient(90deg, #ff4444, #ffaa00, #00ff00);
  transition: width 0.3s;
}

.attack-info,
.position-info {
  color: #00ff00;
  margin-bottom: 8px;
}

.items-info {
  display: flex;
  gap: 15px;
  color: #ffaa00;
  margin-top: 10px;
}

/* メッセージログ */
.message-log {
  height: 150px;
  overflow-y: auto;
  background-color: #001100;
  border: 1px solid #00ff00;
  border-radius: 5px;
  padding: 10px;
  margin-bottom: 15px;
  font-size: 12px;
}

.message {
  color: #00ff00;
  margin-bottom: 5px;
  line-height: 1.4;
}

.message:last-child {
  margin-bottom: 0;
}

/* アクションボタン */
.action-buttons {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.action-section {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.action-btn {
  width: 100%;
  padding: 10px;
  border: 2px solid;
  border-radius: 5px;
  font-family: inherit;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.3s;
  font-size: 14px;
}

.potion-btn {
  background-color: #003300;
  color: #00ff00;
  border-color: #00ff00;
}

.potion-btn:hover:not(:disabled) {
  background-color: #006600;
  box-shadow: 0 0 10px rgba(0, 255, 0, 0.3);
}

.stairs-btn {
  background-color: #000033;
  color: #6666ff;
  border-color: #6666ff;
}

.stairs-btn:hover:not(:disabled) {
  background-color: #000066;
  box-shadow: 0 0 10px rgba(102, 102, 255, 0.3);
}

.door-btn {
  background-color: #332200;
  color: #ffaa00;
  border-color: #ffaa00;
}

.door-btn:hover:not(:disabled) {
  background-color: #664400;
  box-shadow: 0 0 10px rgba(255, 170, 0, 0.3);
}

.chest-btn {
  background-color: #330033;
  color: #ff66ff;
  border-color: #ff66ff;
}

.chest-btn:hover:not(:disabled) {
  background-color: #660066;
  box-shadow: 0 0 10px rgba(255, 102, 255, 0.3);
}

.action-btn:disabled,
.action-btn.disabled {
  opacity: 0.5;
  cursor: not-allowed;
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

/* デバッグパネル */
.debug-panel {
  position: fixed;
  bottom: 10px;
  left: 10px;
  background-color: rgba(0, 0, 0, 0.9);
  border: 1px solid #666;
  border-radius: 5px;
  padding: 10px;
  font-size: 12px;
  color: #888;
  z-index: 1000;
  max-width: 300px;
}

.debug-panel h4 {
  color: #00ff00;
  margin: 0 0 5px 0;
  font-size: 14px;
}

.debug-panel div {
  margin-bottom: 3px;
  word-break: break-all;
}

/* レスポンシブ対応 */
@media (max-width: 768px) {
  .dungeon-container {
    flex-direction: column;
    align-items: center;
  }
  
  .status-panel {
    min-width: auto;
    width: 100%;
    max-width: 400px;
  }
  
  .message-log {
    height: 100px;
  }
  
  .debug-panel {
    position: relative;
    bottom: auto;
    left: auto;
    margin-top: 20px;
    max-width: 100%;
  }
}
</style>