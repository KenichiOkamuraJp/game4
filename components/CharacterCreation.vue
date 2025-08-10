<template>
  <div class="character-creation">
    <!-- 既存キャラクター選択 -->
    <div v-if="existingCharacters.length > 0" class="existing-characters">
      <h2>🏰 既存のキャラクター</h2>
      <div class="character-list">
        <div 
          v-for="character in existingCharacters" 
          :key="character.id"
          class="character-card"
          @click="selectCharacter(character)"
        >
          <div class="character-name">{{ character.name }}</div>
          <div class="character-stats">
            <div>レベル: {{ character.level }}</div>
            <div>HP: {{ character.hp }}/{{ character.maxHp }}</div>
            <div>攻撃: {{ character.attack }}</div>
            <div>防御: {{ character.defense }}</div>
            <div>💰 {{ character.gold }}G</div>
          </div>
          <div class="character-actions">
            <button 
              @click.stop="deleteCharacter(character)"
              class="delete-btn"
              :disabled="loading"
            >
              削除
            </button>
          </div>
        </div>
      </div>
      <div class="divider">または</div>
    </div>

    <!-- 新規キャラクター作成 -->
    <div class="character-creation-form">
      <h2>🧙‍♂️ 新しいキャラクター作成</h2>
      
      <form @submit.prevent="createCharacter">
        <div class="form-group">
          <label>名前:</label>
          <input 
            v-model="newCharacter.name"
            type="text"
            required
            maxlength="20"
            class="form-input"
            placeholder="冒険者の名前"
            :disabled="loading"
          />
        </div>

        <div class="stats-section">
          <h3>能力値</h3>
          <div class="stat-display">
            <div class="stat-item">
              <strong>HP:</strong> {{ newCharacter.hp }}/{{ newCharacter.maxHp }}
            </div>
            <div class="stat-item">
              <strong>攻撃力:</strong> {{ newCharacter.attack }}
            </div>
            <div class="stat-item">
              <strong>防御力:</strong> {{ newCharacter.defense }}
            </div>
          </div>
          
          <button 
            type="button" 
            @click="rollStats" 
            class="roll-btn"
            :disabled="loading"
          >
            🎲 能力値を振り直す
          </button>
        </div>

        <div class="form-actions">
          <button 
            type="submit" 
            :disabled="!newCharacter.name.trim() || loading"
            class="create-btn"
          >
            <span v-if="loading">作成中...</span>
            <span v-else>⚔️ 冒険開始</span>
          </button>
        </div>
      </form>
    </div>

    <!-- エラーメッセージ -->
    <div v-if="error" class="error-message">
      {{ error }}
    </div>

    <!-- 確認ダイアログ -->
    <div v-if="showDeleteConfirm" class="confirm-dialog">
      <div class="confirm-content">
        <h3>キャラクター削除確認</h3>
        <p>{{ deleteTarget?.name }}を削除しますか？</p>
        <p class="warning">この操作は取り消せません。</p>
        <div class="confirm-actions">
          <button @click="confirmDelete" class="confirm-btn danger">削除</button>
          <button @click="cancelDelete" class="confirm-btn">キャンセル</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, reactive, onMounted } from 'vue'
import { charactersAPI } from '../../api/characters.js'

export default {
  name: 'CharacterCreation',
  emits: ['character-created', 'character-selected'],
  
  setup(props, { emit }) {
    const loading = ref(false)
    const error = ref('')
    const existingCharacters = ref([])
    const showDeleteConfirm = ref(false)
    const deleteTarget = ref(null)

    const newCharacter = reactive({
      name: '',
      level: 1,
      exp: 0,
      expToNext: 100,
      hp: 50,
      maxHp: 50,
      attack: 10,
      defense: 5,
      gold: 0
    })

    // 初期化
    onMounted(async () => {
      await loadExistingCharacters()
      rollStats()
    })

    // 既存キャラクター読み込み
    const loadExistingCharacters = async () => {
      try {
        loading.value = true
        existingCharacters.value = await charactersAPI.list()
      } catch (err) {
        console.error('Failed to load characters:', err)
        error.value = 'キャラクター一覧の読み込みに失敗しました'
      } finally {
        loading.value = false
      }
    }

    // 能力値をランダム生成
    const rollStats = () => {
      const stats = charactersAPI.generateRandomStats()
      Object.assign(newCharacter, stats)
    }

    // キャラクター作成
    const createCharacter = async () => {
      error.value = ''
      
      if (!newCharacter.name.trim()) {
        error.value = 'キャラクター名を入力してください'
        return
      }

      // 名前の重複チェック
      if (existingCharacters.value.some(char => char.name === newCharacter.name.trim())) {
        error.value = 'この名前は既に使用されています'
        return
      }

      try {
        loading.value = true
        
        const characterData = {
          name: newCharacter.name.trim(),
          level: newCharacter.level,
          exp: newCharacter.exp,
          expToNext: newCharacter.expToNext,
          hp: newCharacter.hp,
          maxHp: newCharacter.maxHp,
          attack: newCharacter.attack,
          defense: newCharacter.defense,
          gold: newCharacter.gold
        }

        const createdCharacter = await charactersAPI.create(characterData)
        emit('character-created', createdCharacter)
      } catch (err) {
        console.error('Failed to create character:', err)
        error.value = err.message || 'キャラクターの作成に失敗しました'
      } finally {
        loading.value = false
      }
    }

    // 既存キャラクター選択
    const selectCharacter = (character) => {
      emit('character-selected', character)
    }

    // キャラクター削除
    const deleteCharacter = (character) => {
      deleteTarget.value = character
      showDeleteConfirm.value = true
    }

    const confirmDelete = async () => {
      if (!deleteTarget.value) return

      try {
        loading.value = true
        await charactersAPI.delete(deleteTarget.value.id)
        
        // 一覧から削除
        existingCharacters.value = existingCharacters.value.filter(
          char => char.id !== deleteTarget.value.id
        )
        
        showDeleteConfirm.value = false
        deleteTarget.value = null
      } catch (err) {
        console.error('Failed to delete character:', err)
        error.value = err.message || 'キャラクターの削除に失敗しました'
        showDeleteConfirm.value = false
      } finally {
        loading.value = false
      }
    }

    const cancelDelete = () => {
      showDeleteConfirm.value = false
      deleteTarget.value = null
    }

    return {
      loading,
      error,
      existingCharacters,
      newCharacter,
      showDeleteConfirm,
      deleteTarget,
      rollStats,
      createCharacter,
      selectCharacter,
      deleteCharacter,
      confirmDelete,
      cancelDelete
    }
  }
}
</script>

<style scoped>
.character-creation {
  max-width: 600px;
  margin: 0 auto;
  padding: 20px;
}

.existing-characters {
  margin-bottom: 30px;
}

.existing-characters h2 {
  text-align: center;
  color: #ffff00;
  margin-bottom: 20px;
}

.character-list {
  display: grid;
  gap: 15px;
  margin-bottom: 20px;
}

.character-card {
  background-color: #003300;
  border: 2px solid #00ff00;
  border-radius: 10px;
  padding: 15px;
  cursor: pointer;
  transition: all 0.3s;
  position: relative;
}

.character-card:hover {
  background-color: #006600;
  box-shadow: 0 0 15px rgba(0, 255, 0, 0.3);
  transform: translateY(-2px);
}

.character-name {
  font-size: 18px;
  font-weight: bold;
  color: #ffff00;
  margin-bottom: 10px;
}

.character-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 8px;
  color: #00ff00;
  font-size: 14px;
}

.character-actions {
  position: absolute;
  top: 10px;
  right: 10px;
}

.delete-btn {
  background-color: #330000;
  color: #ff4444;
  border: 1px solid #ff4444;
  border-radius: 5px;
  padding: 5px 10px;
  font-size: 12px;
  cursor: pointer;
  transition: all 0.3s;
}

.delete-btn:hover:not(:disabled) {
  background-color: #660000;
  box-shadow: 0 0 10px rgba(255, 68, 68, 0.3);
}

.delete-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.divider {
  text-align: center;
  color: #666;
  font-size: 16px;
  margin: 20px 0;
  position: relative;
}

.divider::before,
.divider::after {
  content: '';
  position: absolute;
  top: 50%;
  width: 40%;
  height: 1px;
  background-color: #666;
}

.divider::before { left: 0; }
.divider::after { right: 0; }

.character-creation-form h2 {
  text-align: center;
  color: #ffff00;
  margin-bottom: 20px;
}

.form-group {
  margin-bottom: 20px;
}

.form-group label {
  display: block;
  color: #00ff00;
  font-weight: bold;
  margin-bottom: 8px;
}

.form-input {
  width: 100%;
  padding: 12px;
  background-color: #001100;
  color: #00ff00;
  border: 2px solid #00ff00;
  border-radius: 5px;
  font-family: inherit;
  font-size: 16px;
  box-sizing: border-box;
}

.form-input:focus {
  outline: none;
  border-color: #ffff00;
  box-shadow: 0 0 10px rgba(255, 255, 0, 0.3);
}

.form-input:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.stats-section {
  background-color: #002200;
  border: 1px solid #00ff00;
  border-radius: 10px;
  padding: 20px;
  margin-bottom: 20px;
}

.stats-section h3 {
  color: #ffff00;
  margin-bottom: 15px;
  text-align: center;
}

.stat-display {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 15px;
  margin-bottom: 20px;
}

.stat-item {
  background-color: #001100;
  border: 1px solid #00ff00;
  border-radius: 5px;
  padding: 10px;
  text-align: center;
  color: #00ff00;
}

.roll-btn {
  width: 100%;
  padding: 12px;
  background-color: #003300;
  color: #00ff00;
  border: 2px solid #00ff00;
  border-radius: 5px;
  font-family: inherit;
  font-size: 16px;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.3s;
}

.roll-btn:hover:not(:disabled) {
  background-color: #006600;
  box-shadow: 0 0 15px rgba(0, 255, 0, 0.3);
}

.roll-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.form-actions {
  text-align: center;
}

.create-btn {
  padding: 15px 30px;
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

.create-btn:hover:not(:disabled) {
  background-color: #008800;
  box-shadow: 0 0 20px rgba(0, 255, 0, 0.4);
  transform: translateY(-2px);
}

.create-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  transform: none;
}

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

.confirm-dialog {
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

.confirm-content {
  background-color: #001a00;
  border: 2px solid #ff4444;
  border-radius: 10px;
  padding: 30px;
  max-width: 400px;
  text-align: center;
}

.confirm-content h3 {
  color: #ff4444;
  margin-bottom: 15px;
}

.confirm-content p {
  color: #00ff00;
  margin-bottom: 10px;
}

.warning {
  color: #ffff00 !important;
  font-weight: bold;
  margin-bottom: 20px !important;
}

.confirm-actions {
  display: flex;
  gap: 15px;
  justify-content: center;
}

.confirm-btn {
  padding: 10px 20px;
  border: 2px solid;
  border-radius: 5px;
  font-family: inherit;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.3s;
}

.confirm-btn.danger {
  background-color: #330000;
  color: #ff4444;
  border-color: #ff4444;
}

.confirm-btn.danger:hover {
  background-color: #660000;
}

.confirm-btn:not(.danger) {
  background-color: #003300;
  color: #00ff00;
  border-color: #00ff00;
}

.confirm-btn:not(.danger):hover {
  background-color: #006600;
}
</style>