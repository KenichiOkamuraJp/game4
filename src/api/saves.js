// Saves API Service
import { authService } from './auth.js'
import { apiRequest } from './utils.js'

const API_BASE_URL = import.meta.env.VITE_AWS_API_ENDPOINT

class SavesAPI {
  constructor() {
    this.baseURL = `${API_BASE_URL}/saves`
  }

  /**
   * セーブデータを作成
   */
  async create(saveData) {
    try {
      // バリデーション
      if (!saveData.character || !saveData.character.id) {
        throw new Error('キャラクター情報が必要です')
      }

      const payload = this.prepareSaveData(saveData)

      const response = await apiRequest(`${this.baseURL}`, {
        method: 'POST',
        headers: await authService.getIAMHeaders(),
        body: JSON.stringify(payload)
      })

      return response
    } catch (error) {
      console.error('Failed to create save data:', error)
      if (error.message.includes('キャラクター')) {
        throw error
      }
      throw new Error('セーブデータの作成に失敗しました')
    }
  }

  /**
   * セーブデータを取得
   */
  async get(characterId) {
    try {
      if (!characterId) {
        throw new Error('キャラクターIDが必要です')
      }

      const response = await apiRequest(`${this.baseURL}/character/${characterId}`, {
        method: 'GET',
        headers: await authService.getIAMHeaders()
      })

      return response
    } catch (error) {
      console.error('Failed to fetch save data:', error)
      if (error.status === 404) {
        return null // セーブデータが存在しない場合
      }
      throw new Error('セーブデータの取得に失敗しました')
    }
  }

  /**
   * セーブデータを更新
   */
  async update(characterId, saveData) {
    try {
      if (!characterId) {
        throw new Error('キャラクターIDが必要です')
      }

      const payload = this.prepareSaveData(saveData)

      const response = await apiRequest(`${this.baseURL}/character/${characterId}`, {
        method: 'PUT',
        headers: await authService.getIAMHeaders(),
        body: JSON.stringify(payload)
      })

      return response
    } catch (error) {
      console.error('Failed to update save data:', error)
      throw new Error('セーブデータの更新に失敗しました')
    }
  }

  /**
   * セーブデータを削除
   */
  async delete(saveId) {
    try {
      if (!saveId) {
        throw new Error('セーブIDが必要です')
      }

      await apiRequest(`${this.baseURL}/${saveId}`, {
        method: 'DELETE',
        headers: await authService.getIAMHeaders()
      })

      return true
    } catch (error) {
      console.error('Failed to delete save data:', error)
      throw new Error('セーブデータの削除に失敗しました')
    }
  }

  /**
   * セーブデータを準備（サニタイズとデフォルト値設定）
   */
  prepareSaveData(saveData) {
    return {
      character: saveData.character,
      characterId: saveData.character.id,
      currentFloor: parseInt(saveData.currentFloor) || 1,
      playerX: parseInt(saveData.playerX) || 1,
      playerY: parseInt(saveData.playerY) || 6,
      potions: parseInt(saveData.potions) || 3,
      keys: parseInt(saveData.keys) || 0,
      doorStates: saveData.doorStates || {},
      chestStates: saveData.chestStates || {},
      playerPositions: saveData.playerPositions || this.getDefaultPlayerPositions(),
      messages: saveData.messages || []
    }
  }

  /**
   * デフォルトのプレイヤー位置を取得
   */
  getDefaultPlayerPositions() {
    return {
      1: { x: 1, y: 6 },
      2: { x: 1, y: 1 },
      3: { x: 1, y: 1 }
    }
  }

  /**
   * 新しいゲーム用のデフォルトセーブデータを作成
   */
  createDefaultSaveData(character) {
    return {
      character: character,
      currentFloor: 1,
      playerX: 1,
      playerY: 6,
      potions: 3,
      keys: 0,
      doorStates: {},
      chestStates: {},
      playerPositions: this.getDefaultPlayerPositions(),
      messages: [`${character.name}がダンジョンに入りました！`]
    }
  }

  /**
   * ダンジョンマップデータ（既存のindex.htmlから移植）
   */
  getDungeonMaps() {
    return {
      1: [
        [0,0,0,0,0,0,0,0],
        [0,1,1,4,1,1,1,0],
        [0,1,0,6,2,0,1,0],
        [0,4,0,1,1,0,1,0],
        [0,1,1,1,0,1,1,0],
        [0,0,0,1,2,1,0,0],
        [0,7,1,1,8,1,1,0],
        [0,0,0,0,0,0,0,0]
      ],
      2: [
        [0,0,0,0,0,0,0,0],
        [0,7,1,1,1,1,1,0],
        [0,1,0,6,2,0,1,0],
        [0,1,0,1,5,0,4,0],
        [0,1,1,1,0,1,1,0],
        [0,0,6,1,2,1,0,0],
        [0,1,1,1,8,1,1,0],
        [0,0,0,0,0,0,0,0]
      ],
      3: [
        [0,0,0,0,0,0,0,0],
        [0,7,1,1,1,1,1,0],
        [0,1,0,6,2,0,1,0],
        [0,5,0,1,1,0,5,0],
        [0,1,1,1,0,1,1,0],
        [0,0,0,5,2,5,0,0],
        [0,6,1,1,1,1,1,0],
        [0,0,0,0,3,0,0,0]
      ]
    }
  }

  /**
   * セルタイプの定義
   */
  getCellTypes() {
    return {
      WALL: 0,
      FLOOR: 1,
      ENEMY: 2,
      GOAL: 3,
      DOOR: 4,
      LOCKED_DOOR: 5,
      CHEST: 6,
      STAIRS_UP: 7,
      STAIRS_DOWN: 8
    }
  }

  /**
   * プレイヤーが移動可能かチェック
   */
  canMoveTo(x, y, floor, doorStates = {}, chestStates = {}) {
    const maps = this.getDungeonMaps()
    const cellTypes = this.getCellTypes()
    
    if (x < 0 || x >= 8 || y < 0 || y >= 8) return false
    
    const cell = maps[floor][y][x]
    
    if (cell === cellTypes.WALL) return false
    
    // 扉の状態チェック
    if (cell === cellTypes.DOOR || cell === cellTypes.LOCKED_DOOR) {
      const doorKey = `${floor}-${x}-${y}`
      return doorStates[doorKey] === true
    }
    
    // 宝箱は移動不可
    if (cell === cellTypes.CHEST) {
      return false
    }
    
    // 階段は特別な移動
    if (cell === cellTypes.STAIRS_UP || cell === cellTypes.STAIRS_DOWN) {
      return false
    }
    
    return true
  }

  /**
   * 隣接するセルを取得
   */
  getAdjacentCells(x, y, floor) {
    const maps = this.getDungeonMaps()
    const directions = [
      { dx: 0, dy: -1, name: 'up' },
      { dx: 0, dy: 1, name: 'down' },
      { dx: -1, dy: 0, name: 'left' },
      { dx: 1, dy: 0, name: 'right' }
    ]
    
    const adjacent = []
    
    for (const dir of directions) {
      const newX = x + dir.dx
      const newY = y + dir.dy
      
      if (newX >= 0 && newX < 8 && newY >= 0 && newY < 8) {
        const cell = maps[floor][newY][newX]
        adjacent.push({
          x: newX,
          y: newY,
          cell: cell,
          direction: dir.name
        })
      }
    }
    
    return adjacent
  }

  /**
   * 特定のセルタイプが隣接しているかチェック
   */
  hasAdjacentCellType(x, y, floor, cellType) {
    const adjacent = this.getAdjacentCells(x, y, floor)
    return adjacent.some(cell => cell.cell === cellType)
  }

  /**
   * 扉の状態を更新
   */
  updateDoorState(saveData, floor, x, y, isOpen) {
    const doorKey = `${floor}-${x}-${y}`
    const updatedSaveData = { ...saveData }
    updatedSaveData.doorStates = { ...saveData.doorStates }
    updatedSaveData.doorStates[doorKey] = isOpen
    return updatedSaveData
  }

  /**
   * 宝箱の状態を更新
   */
  updateChestState(saveData, floor, x, y, isOpened) {
    const chestKey = `${floor}-${x}-${y}`
    const updatedSaveData = { ...saveData }
    updatedSaveData.chestStates = { ...saveData.chestStates }
    updatedSaveData.chestStates[chestKey] = isOpened
    return updatedSaveData
  }

  /**
   * プレイヤー位置を更新
   */
  updatePlayerPosition(saveData, floor, x, y) {
    const updatedSaveData = { ...saveData }
    updatedSaveData.currentFloor = floor
    updatedSaveData.playerX = x
    updatedSaveData.playerY = y
    updatedSaveData.playerPositions = { ...saveData.playerPositions }
    updatedSaveData.playerPositions[floor] = { x, y }
    return updatedSaveData
  }

  /**
   * アイテム数を更新
   */
  updateItems(saveData, potions, keys) {
    const updatedSaveData = { ...saveData }
    if (potions !== undefined) updatedSaveData.potions = Math.max(0, potions)
    if (keys !== undefined) updatedSaveData.keys = Math.max(0, keys)
    return updatedSaveData
  }

  /**
   * メッセージを追加
   */
  addMessage(saveData, message, maxMessages = 10) {
    const updatedSaveData = { ...saveData }
    updatedSaveData.messages = [...saveData.messages, message]
    
    // メッセージ数制限
    if (updatedSaveData.messages.length > maxMessages) {
      updatedSaveData.messages = updatedSaveData.messages.slice(-maxMessages)
    }
    
    return updatedSaveData
  }

  /**
   * セーブデータをリセット（新しいダンジョンアタック用）
   */
  resetForNewDungeon(character) {
    return this.createDefaultSaveData(character)
  }

  /**
   * セーブデータのバリデーション
   */
  validateSaveData(saveData) {
    const errors = []

    if (!saveData.character) {
      errors.push('キャラクター情報が必要です')
    }

    if (!saveData.character?.id) {
      errors.push('キャラクターIDが必要です')
    }

    if (saveData.currentFloor < 1 || saveData.currentFloor > 3) {
      errors.push('現在の階層は1-3の間である必要があります')
    }

    if (saveData.playerX < 0 || saveData.playerX >= 8) {
      errors.push('プレイヤーのX座標が無効です')
    }

    if (saveData.playerY < 0 || saveData.playerY >= 8) {
      errors.push('プレイヤーのY座標が無効です')
    }

    if (saveData.potions < 0) {
      errors.push('回復薬の数は0以上である必要があります')
    }

    if (saveData.keys < 0) {
      errors.push('鍵の数は0以上である必要があります')
    }

    return errors
  }

  /**
   * 敵の情報を取得
   */
  getEnemyData() {
    return [
      { 
        name: 'スライム', 
        hp: 20, 
        maxHp: 20, 
        attack: 6, 
        expReward: { min: 5, max: 10 }, 
        goldReward: { min: 3, max: 8 } 
      },
      { 
        name: 'ゴブリン', 
        hp: 30, 
        maxHp: 30, 
        attack: 8, 
        expReward: { min: 10, max: 15 }, 
        goldReward: { min: 8, max: 15 } 
      },
      { 
        name: 'オーク', 
        hp: 40, 
        maxHp: 40, 
        attack: 10, 
        expReward: { min: 15, max: 25 }, 
        goldReward: { min: 15, max: 25 } 
      }
    ]
  }

  /**
   * ランダムな敵を生成
   */
  generateRandomEnemy() {
    const enemies = this.getEnemyData()
    const template = enemies[Math.floor(Math.random() * enemies.length)]
    return { ...template }
  }

  /**
   * 宝箱のアイテムを生成
   */
  generateTreasure() {
    const treasures = [
      { type: 'key', message: '✨ 鍵を見つけました！' },
      { type: 'potion', message: '✨ 回復薬を見つけました！' },
      { type: 'nothing', message: '宝箱は空でした...' }
    ]
    return treasures[Math.floor(Math.random() * treasures.length)]
  }
}

// シングルトンインスタンスをエクスポート
export const savesAPI = new SavesAPI()

// デフォルトエクスポート
export default savesAPI