// Characters API Service
import { authService } from './auth.js'
import { apiRequest } from './utils.js'

const API_BASE_URL = import.meta.env.VITE_AWS_API_ENDPOINT

class CharactersAPI {
  constructor() {
    this.baseURL = `${API_BASE_URL}/characters`
  }

  /**
   * 認証状態をチェック
   */
  async ensureAuthenticated() {
    if (!authService.isAuthenticated()) {
      try {
        await authService.getCurrentUser()
      } catch (error) {
        throw new Error('認証が必要です。ログインしてください。')
      }
    }
  }

  /**
   * キャラクター一覧を取得
   */
  async list() {
    try {
      await this.ensureAuthenticated()
      
      const response = await apiRequest(`${this.baseURL}`, {
        method: 'GET',
        headers: await authService.getIAMHeaders()
      })

      return response
    } catch (error) {
      console.error('Failed to fetch characters:', error)
      
      if (error.message.includes('認証')) {
        throw error
      }
      throw new Error('キャラクター一覧の取得に失敗しました')
    }
  }

  /**
   * キャラクターを作成
   */
  async create(characterData) {
    try {
      await this.ensureAuthenticated()
      
      // バリデーション
      if (!characterData.name || !characterData.name.trim()) {
        throw new Error('キャラクター名は必須です')
      }

      const payload = {
        name: characterData.name.trim(),
        level: characterData.level || 1,
        exp: characterData.exp || 0,
        expToNext: characterData.expToNext || 100,
        hp: characterData.hp || 50,
        maxHp: characterData.maxHp || 50,
        attack: characterData.attack || 10,
        defense: characterData.defense || 5,
        gold: characterData.gold || 0
      }

      const response = await apiRequest(`${this.baseURL}`, {
        method: 'POST',
        headers: await authService.getIAMHeaders(),
        body: JSON.stringify(payload)
      })

      return response
    } catch (error) {
      console.error('Failed to create character:', error)
      if (error.message.includes('キャラクター名') || error.message.includes('認証')) {
        throw error
      }
      throw new Error('キャラクターの作成に失敗しました')
    }
  }

  /**
   * キャラクターを更新
   */
  async update(characterId, characterData) {
    try {
      await this.ensureAuthenticated()
      
      if (!characterId) {
        throw new Error('キャラクターIDが必要です')
      }

      // IDやuserIdなどの変更不可フィールドを除外
      const { id, userId, createdAt, ...updateData } = characterData

      const response = await apiRequest(`${this.baseURL}/${characterId}`, {
        method: 'PUT',
        headers: await authService.getIAMHeaders(),
        body: JSON.stringify(updateData)
      })

      return response
    } catch (error) {
      console.error('Failed to update character:', error)
      if (error.message.includes('認証')) {
        throw error
      }
      throw new Error('キャラクターの更新に失敗しました')
    }
  }

  /**
   * キャラクターを削除
   */
  async delete(characterId) {
    try {
      await this.ensureAuthenticated()
      
      if (!characterId) {
        throw new Error('キャラクターIDが必要です')
      }

      await apiRequest(`${this.baseURL}/${characterId}`, {
        method: 'DELETE',
        headers: await authService.getIAMHeaders()
      })

      return true
    } catch (error) {
      console.error('Failed to delete character:', error)
      if (error.message.includes('認証')) {
        throw error
      }
      throw new Error('キャラクターの削除に失敗しました')
    }
  }

  /**
   * キャラクターの能力値をランダム生成
   */
  generateRandomStats() {
    const baseHp = 40 + Math.floor(Math.random() * 21) // 40-60
    const baseAttack = 8 + Math.floor(Math.random() * 5) // 8-12
    const baseDefense = 3 + Math.floor(Math.random() * 5) // 3-7

    return {
      hp: baseHp,
      maxHp: baseHp,
      attack: baseAttack,
      defense: baseDefense,
      level: 1,
      exp: 0,
      expToNext: 100,
      gold: 0
    }
  }

  /**
   * レベルアップ計算
   */
  calculateLevelUp(character) {
    if (character.exp < character.expToNext) {
      throw new Error('経験値が不足しています')
    }

    const hpIncrease = 8 + Math.floor(Math.random() * 5) // 8-12
    const attackIncrease = 2 + Math.floor(Math.random() * 3) // 2-4
    const defenseIncrease = 1 + Math.floor(Math.random() * 3) // 1-3

    return {
      level: character.level + 1,
      exp: character.exp - character.expToNext,
      expToNext: Math.floor(100 * Math.pow(1.2, character.level)),
      maxHp: character.maxHp + hpIncrease,
      hp: character.hp + hpIncrease, // レベルアップ時はHPも回復
      attack: character.attack + attackIncrease,
      defense: character.defense + defenseIncrease,
      increases: {
        hp: hpIncrease,
        attack: attackIncrease,
        defense: defenseIncrease
      }
    }
  }

  /**
   * レベルアップが可能かチェック
   */
  canLevelUp(character) {
    return character.exp >= character.expToNext
  }

  /**
   * 必要経験値を計算
   */
  getExpNeeded(character) {
    return Math.max(0, character.expToNext - character.exp)
  }

  /**
   * HPが満タンかチェック
   */
  isFullHP(character) {
    return character.hp >= character.maxHp
  }

  /**
   * キャラクターの状態をバリデート
   */
  validateCharacter(character) {
    const errors = []

    if (!character.name || !character.name.trim()) {
      errors.push('キャラクター名は必須です')
    }

    if (character.level < 1) {
      errors.push('レベルは1以上である必要があります')
    }

    if (character.hp < 0) {
      errors.push('HPは0以上である必要があります')
    }

    if (character.maxHp < 1) {
      errors.push('最大HPは1以上である必要があります')
    }

    if (character.hp > character.maxHp) {
      errors.push('HPが最大HPを超えています')
    }

    if (character.attack < 1) {
      errors.push('攻撃力は1以上である必要があります')
    }

    if (character.defense < 0) {
      errors.push('防御力は0以上である必要があります')
    }

    if (character.exp < 0) {
      errors.push('経験値は0以上である必要があります')
    }

    if (character.gold < 0) {
      errors.push('所持金は0以上である必要があります')
    }

    return errors
  }

  /**
   * キャラクターデータをクリーンアップ
   */
  cleanCharacterData(character) {
    return {
      id: character.id,
      userId: character.userId,
      name: character.name ? character.name.trim() : '',
      level: Math.max(1, parseInt(character.level) || 1),
      exp: Math.max(0, parseInt(character.exp) || 0),
      expToNext: Math.max(1, parseInt(character.expToNext) || 100),
      hp: Math.max(0, parseInt(character.hp) || 50),
      maxHp: Math.max(1, parseInt(character.maxHp) || 50),
      attack: Math.max(1, parseInt(character.attack) || 10),
      defense: Math.max(0, parseInt(character.defense) || 5),
      gold: Math.max(0, parseInt(character.gold) || 0),
      createdAt: character.createdAt,
      updatedAt: character.updatedAt
    }
  }

  /**
   * 戦闘での経験値とゴールド獲得
   */
  gainExpAndGold(character, exp, gold) {
    const updatedCharacter = { ...character }
    updatedCharacter.exp += exp
    updatedCharacter.gold += gold

    return updatedCharacter
  }

  /**
   * ダメージを受ける
   */
  takeDamage(character, damage) {
    const updatedCharacter = { ...character }
    updatedCharacter.hp = Math.max(0, character.hp - damage)
    return updatedCharacter
  }

  /**
   * HP回復
   */
  heal(character, amount) {
    const updatedCharacter = { ...character }
    updatedCharacter.hp = Math.min(character.maxHp, character.hp + amount)
    return updatedCharacter
  }

  /**
   * 完全回復
   */
  fullHeal(character) {
    const updatedCharacter = { ...character }
    updatedCharacter.hp = character.maxHp
    return updatedCharacter
  }

  /**
   * 所持金を減らす
   */
  spendGold(character, amount) {
    if (character.gold < amount) {
      throw new Error('所持金が不足しています')
    }

    const updatedCharacter = { ...character }
    updatedCharacter.gold -= amount
    return updatedCharacter
  }

  /**
   * キャラクターが死亡しているかチェック
   */
  isDead(character) {
    return character.hp <= 0
  }

  /**
   * キャラクター作成用のデフォルトデータ
   */
  getDefaultCharacterData(name = '') {
    const stats = this.generateRandomStats()
    return {
      name,
      ...stats
    }
  }
}

// シングルトンインスタンスをエクスポート
export const charactersAPI = new CharactersAPI()

// デフォルトエクスポート
export default charactersAPI