# 🎮 Vue.js ダンジョンRPG (Python Lambda版)

本格的なターン制ダンジョンRPGゲーム。Vue.js フロントエンド + Python AWS Lambda サーバーレスバックエンドで構築。

## ✨ 主要機能

- **キャラクター作成・管理**: ランダム能力値生成、レベルアップシステム
- **3階層ダンジョン探索**: 階段、扉、宝箱、敵との戦闘
- **戦闘システム**: ターン制バトル、アイテム使用、逃走システム
- **町システム**: 回復、ギルド、ステータス管理
- **クラウドセーブ**: AWS DynamoDB による永続化
- **マルチユーザー対応**: Cognito 認証によるユーザー管理

## 🏗️ アーキテクチャ

### フロントエンド
- **Vue.js 3**: Options API を使用したリアクティブUI
- **ターミナル風デザイン**: レトロなRPG体験
- **レスポンシブ対応**: デスクトップ・モバイル対応

### バックエンド (AWS + Python)
- **Python Lambda**: Python 3.11 ランタイムでのサーバーレス API
- **boto3**: AWS SDK for Python
- **DynamoDB**: NoSQL データベース
- **API Gateway**: RESTful API エンドポイント
- **Cognito**: ユーザー認証・認可
- **CloudFormation**: Infrastructure as Code

## 📋 前提条件

### 必須ソフトウェア
```powershell
# Windows の場合
winget install Python.Python.3.11
winget install OpenJS.NodeJS
winget install Amazon.AWSCLI
winget install Git.Git
```

### Python 要件
- **Python 3.8+** (推奨: Python 3.11)
- **pip** (Pythonと一緒にインストール)

### AWS 設定
```bash
aws configure
```

必要な AWS 権限:
- CloudFormation (フルアクセス)
- DynamoDB (フルアクセス)  
- Lambda (フルアクセス)
- API Gateway (フルアクセス)
- Cognito (フルアクセス)
- IAM (制限付きアクセス)

## 🚀 セットアップ手順

### 1. 依存関係のインストール

```powershell
# PowerShell 実行ポリシーの設定
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 依存関係のインストール（Python対応）
.\scripts\install-dependencies.ps1
```

### 2. プロジェクト初期化（新規作成の場合）

```powershell
# プロジェクトディレクトリの作成
mkdir vue-dungeon-rpg-python
cd vue-dungeon-rpg-python

# 基本ディレクトリ構造の作成
mkdir lambda\characters
mkdir lambda\saves
mkdir scripts

# フロントエンド初期化
npm init -y
```

### 3. ソースファイルの配置

以下のファイルを作成・配置してください：

#### Python Lambda 関数
```powershell
# Characters 関数群
# lambda/characters/create.py
# lambda/characters/list.py
# lambda/characters/update.py
# lambda/characters/delete.py
# lambda/characters/requirements.txt

# Saves 関数群  
# lambda/saves/create.py
# lambda/saves/get.py
# lambda/saves/update.py
# lambda/saves/delete.py
# lambda/saves/requirements.txt
```

#### スクリプト類
```powershell
# scripts/setup.ps1
# scripts/cleanup.ps1
# scripts/deploy-lambda.ps1 (Python版)
# scripts/install-dependencies.ps1 (Python版)
# scripts/cloudformation.yaml (Python版)
```

### 4. AWS インフラのデプロイ

```powershell
.\scripts\setup.ps1 -ProjectName "your-rpg" -AdminEmail "your-email@example.com" -AWSRegion "ap-northeast-1"
```

### 5. Python Lambda 関数のデプロイ

```powershell
.\scripts\deploy-lambda.ps1 -ProjectName "your-rpg" -AWSRegion "ap-northeast-1"
```

### 6. フロントエンドの起動

```powershell
npm install
npm run dev
```

ブラウザで `http://localhost:5173` にアクセス

## 📁 プロジェクト構造（Python版）

```
vue-dungeon-rpg/
├── scripts/                      # AWS デプロイスクリプト
│   ├── setup.ps1                # メインセットアップ
│   ├── cleanup.ps1              # リソース削除
│   ├── deploy-lambda.ps1        # Python Lambda 関数デプロイ
│   ├── install-dependencies.ps1 # 依存関係インストール
│   └── cloudformation.yaml     # AWS インフラ定義（Python版）
├── lambda/                      # Python Lambda 関数ソースコード
│   ├── characters/             # キャラクター管理 API
│   │   ├── requirements.txt    # Python 依存関係
│   │   ├── create.py          # POST /characters
│   │   ├── list.py            # GET /characters
│   │   ├── update.py          # PUT /characters/{id}
│   │   └── delete.py          # DELETE /characters/{id}
│   └── saves/                 # セーブデータ管理 API
│       ├── requirements.txt    # Python 依存関係
│       ├── create.py          # POST /saves
│       ├── get.py             # GET /saves/{characterId}
│       ├── update.py          # PUT /saves/{characterId}
│       └── delete.py          # DELETE /saves/{id}
├── index.html                 # メインゲームファイル
├── package.json              # フロントエンド依存関係
├── .env                       # AWS 設定（自動生成）
├── .gitignore                # Git 除外設定（Python対応）
└── README.md                 # このファイル
```

## 🐍 Python Lambda 関数の特徴

### ランタイム・ハンドラー設定
- **Runtime**: `python3.11`
- **Handler**: `{ファイル名}.lambda_handler`
- **Timeout**: 30秒

### 依存関係管理
```text
# requirements.txt
boto3==1.34.0
```

### 共通機能
- **JSON シリアライゼーション**: DynamoDB Decimal型対応
- **CORS 対応**: すべてのAPIでCORS ヘッダー設定
- **エラーハンドリング**: ClientError, 一般例外の適切な処理
- **ログ出力**: CloudWatch Logs への詳細ログ
- **日本語対応**: `ensure_ascii=False` でUTF-8出力

### サンプルコード構造
```python
import json
import boto3
import os
from datetime import datetime
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    # CORS headers
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }
    
    try:
        # ビジネスロジック
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps(result, ensure_ascii=False)
        }
    except Exception as e:
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'error': 'エラーメッセージ'}, ensure_ascii=False)
        }
```

## 🎯 API エンドポイント

### Characters API
```
POST   /characters           # キャラクター作成
GET    /characters           # キャラクター一覧
PUT    /characters/{id}      # キャラクター更新  
DELETE /characters/{id}      # キャラクター削除
```

### Saves API
```
POST   /saves                    # セーブデータ作成
GET    /saves/{characterId}      # セーブデータ取得
PUT    /saves/{characterId}      # セーブデータ更新
DELETE /saves/{id}              # セーブデータ削除
```

## 🗃️ データベーススキーマ

### Characters テーブル
```python
{
    "userId": "user-cognito-id",        # パーティションキー
    "id": "character-uuid",             # ソートキー
    "name": "キャラクター名",
    "level": 1,
    "exp": 0,
    "expToNext": 100,
    "hp": 50,
    "maxHp": 50,
    "attack": 10,
    "defense": 5,
    "gold": 0,
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T00:00:00Z"
}
```

### Saves テーブル
```python
{
    "userId": "user-cognito-id",        # パーティションキー
    "characterId": "character-uuid",    # ソートキー
    "id": "save-uuid",
    "character": { /* キャラクター情報 */ },
    "currentFloor": 1,
    "playerX": 1,
    "playerY": 6,
    "potions": 3,
    "keys": 0,
    "doorStates": {},
    "chestStates": {},
    "playerPositions": {
        "1": {"x": 1, "y": 6},
        "2": {"x": 1, "y": 1},
        "3": {"x": 1, "y": 1}
    },
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T00:00:00Z"
}
```

## 🎮 ゲームの遊び方

### キャラクター作成
1. 名前を入力
2. 能力値をランダム生成（振り直し可能）
3. 冒険開始

### 町での活動
- **回復の泉**: HPを完全回復（50G）
- **ギルド**: 経験値でレベルアップ
- **ダンジョン**: 危険な冒険に出発

### ダンジョン探索
- **移動**: 矢印キーで四方向移動
- **戦闘**: 敵と遭遇時はターン制バトル
- **アイテム**: 宝箱から鍵や回復薬を取得
- **扉**: 通常扉と鍵付き扉
- **階段**: 上下階層への移動

### 戦闘システム
- **攻撃**: 敵にダメージを与える
- **逃走**: 70%の確率で逃げられる
- **アイテム**: 回復薬で HP 回復

## 🧹 リソースの削除

全てのAWSリソースを削除する場合：

```powershell
.\scripts\cleanup.ps1 -ProjectName "your-rpg"
```

⚠️ **警告**: 全てのデータが削除されます！

## 💰 料金見積もり

### 月間コスト（小規模利用）
- **DynamoDB**: $1-5 (オンデマンド課金)
- **Lambda**: $0-1 (100万リクエスト以下無料)
- **API Gateway**: $0-1 (100万コール以下無料)
- **Cognito**: $0 (50,000 MAU以下無料)

**合計**: 月額 $1-7 程度

## 🔧 開発

### ローカル開発
```bash
npm run dev      # 開発サーバー起動
npm run build    # プロダクションビルド
npm run preview  # ビルド結果プレビュー
```

### Python Lambda関数の開発・テスト
```python
# ローカルでのテスト例
import json
from lambda.characters.create import lambda_handler

# テストイベントの作成
test_event = {
    'httpMethod': 'POST',
    'requestContext': {
        'authorizer': {
            'claims': {
                'sub': 'test-user-id'
            }
        }
    },
    'body': json.dumps({
        'name': 'テストキャラクター',
        'hp': 50,
        'attack': 10
    })
}

# 関数実行
result = lambda_handler(test_event, None)
print(json.dumps(result, indent=2))
```

### Lambda関数の更新
```powershell
# 関数を修正後、再デプロイ
.\scripts\deploy-lambda.ps1
```

### インフラの更新
```powershell
# CloudFormation テンプレート修正後
.\scripts\setup.ps1
```

## 🔍 トラブルシューティング

### よくある問題

#### 1. Python環境関連
```powershell
# Python バージョン確認
python --version

# pip バージョン確認
pip --version

# 仮想環境作成（任意）
python -m venv venv
venv\Scripts\activate  # Windows
```

#### 2. PowerShell 実行エラー
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### 3. AWS 認証エラー
```bash
aws configure
aws sts get-caller-identity  # 確認
```

#### 4. Lambda デプロイエラー
```powershell
# 詳細ログで確認
.\scripts\deploy-lambda.ps1 -Verbose

# 手動でZIPファイル確認
cd lambda/characters
pip install -r requirements.txt -t .
```

#### 5. DynamoDB アクセスエラー
```python
# IAM権限確認
# Lambda実行ロールにDynamoDBアクセス権限があるか確認
```

### ログの確認
```powershell
# CloudWatch Logs 確認
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/your-rpg

# 特定関数のログ確認
aws logs describe-log-streams --log-group-name /aws/lambda/your-rpg-characters-create

# ログ出力
aws logs get-log-events --log-group-name /aws/lambda/your-rpg-characters-create --log-stream-name "最新のストリーム名"
```

### Python 固有のトラブルシューティング

#### 1. boto3 バージョン競合
```text
# requirements.txt で固定
boto3==1.34.0
```

#### 2. JSON シリアライゼーションエラー
```python
# Decimal型の処理
import decimal

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

# 使用例
json.dumps(data, cls=DecimalEncoder)
```

#### 3. 文字エンコーディング問題
```python
# 日本語出力の場合
json.dumps(data, ensure_ascii=False)
```

## 📈 本番運用

### セキュリティ
- Cognito パスワードポリシー強化
- API Gateway レート制限設定
- Lambda 環境変数の暗号化
- CloudTrail ログ監視

### パフォーマンス
- DynamoDB キャパシティ監視
- Lambda 実行時間最適化（Python最適化）
- CloudWatch メトリクス設定
- Lambda コールドスタート対策

### モニタリング
```python
# Lambda関数でのカスタムメトリクス
import boto3
cloudwatch = boto3.client('cloudwatch')

cloudwatch.put_metric_data(
    Namespace='DungeonRPG',
    MetricData=[
        {
            'MetricName': 'CharacterCreated',
            'Value': 1,
            'Unit': 'Count'
        }
    ]
)
```

### バックアップ
- DynamoDB ポイントインタイムリカバリ
- 定期的なデータエクスポート
- Lambda関数コードのバージョン管理
- CloudFormation テンプレートのバージョン管理

## 🧪 テスト

### 単体テスト例
```python
# test_characters.py
import unittest
import json
from unittest.mock import patch, MagicMock
from lambda.characters.create import lambda_handler

class TestCharacterCreate(unittest.TestCase):
    @patch('lambda.characters.create.dynamodb')
    def test_create_character_success(self, mock_dynamodb):
        # モックの設定
        mock_table = MagicMock()
        mock_dynamodb.Table.return_value = mock_table
        
        # テストデータ
        event = {
            'httpMethod': 'POST',
            'requestContext': {
                'authorizer': {
                    'claims': {'sub': 'test-user'}
                }
            },
            'body': json.dumps({'name': 'テストキャラ'})
        }
        
        # 実行
        result = lambda_handler(event, None)
        
        # 検証
        self.assertEqual(result['statusCode'], 200)
        mock_table.put_item.assert_called_once()

if __name__ == '__main__':
    unittest.main()
```

## 🤝 コントリビューション

1. Fork このリポジトリ
2. フィーチャーブランチ作成 (`git checkout -b feature/amazing-feature`)
3. コミット (`git commit -m 'Add amazing feature'`)
4. プッシュ (`git push origin feature/amazing-feature`)
5. Pull Request 作成

## 🎓 学習リソース

### Python AWS 開発
- [AWS SDK for Python (Boto3)](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)
- [AWS Lambda Python Programming Model](https://docs.aws.amazon.com/lambda/latest/dg/python-programming-model.html)
- [DynamoDB Python Tutorial](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GettingStarted.Python.html)

### Vue.js
- [Vue.js 3 Documentation](https://vuejs.org/)
- [Vue.js Options API Guide](https://vuejs.org/guide/introduction.html)

## 📄 ライセンス

MIT License - 詳細は [LICENSE](LICENSE) ファイルを参照

## 🙏 謝辞

- Vue.js コミュニティ
- Python コミュニティ
- AWS サーバーレスコミュニティ
- オープンソースソフトウェア開発者の皆様

---

**🐍 Python Lambda版の特徴**
- 読みやすいコード: Pythonの可読性を活かした実装
- 豊富なエラーハンドリング: boto3のClientErrorを適切に処理
- 日本語対応: UTF-8エンコーディングで日本語メッセージ対応
- テスト容易性: unittest による単体テスト作成が簡単
- デバッグ性: print文によるCloudWatch Logsへの詳細ログ出力