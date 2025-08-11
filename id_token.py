#!/usr/bin/env python3
"""
IDトークンを表示するデバッグ版スクリプト
"""

import boto3
import json
import sys
import getpass
import hmac
import hashlib
import base64
from botocore.exceptions import ClientError, NoCredentialsError


class CognitoTokenDebug:
    def __init__(self, region: str, user_pool_id: str, client_id: str, client_secret=None):
        self.region = region
        self.user_pool_id = user_pool_id
        self.client_id = client_id
        self.client_secret = client_secret
        
        try:
            self.cognito_client = boto3.client('cognito-idp', region_name=region)
        except NoCredentialsError:
            print("❌ AWS認証情報が見つかりません")
            sys.exit(1)
    
    def _calculate_secret_hash(self, username: str):
        if not self.client_secret:
            return None
            
        message = username + self.client_id
        dig = hmac.new(
            str(self.client_secret).encode('UTF-8'),
            msg=str(message).encode('UTF-8'),
            digestmod=hashlib.sha256
        ).digest()
        return base64.b64encode(dig).decode()
    
    def get_tokens_with_debug(self, username: str, password: str):
        """
        認証を実行してトークンを取得・表示
        """
        try:
            auth_params = {
                'USERNAME': username,
                'PASSWORD': password
            }
            
            secret_hash = self._calculate_secret_hash(username)
            if secret_hash:
                auth_params['SECRET_HASH'] = secret_hash
            
            print(f"🔐 Cognito認証中... (ユーザー: {username})")
            
            response = self.cognito_client.admin_initiate_auth(
                UserPoolId=self.user_pool_id,
                ClientId=self.client_id,
                AuthFlow='ADMIN_NO_SRP_AUTH',
                AuthParameters=auth_params
            )
            
            if 'ChallengeName' in response:
                print(f"⚠️  追加認証が必要: {response['ChallengeName']}")
                return None
            
            auth_result = response['AuthenticationResult']
            
            print("✅ Cognito認証成功!")
            print(f"   アクセストークン有効期限: {auth_result.get('ExpiresIn', '不明')}秒")
            
            # 🎯 ここでトークンを表示
            id_token = auth_result.get('IdToken')
            access_token = auth_result.get('AccessToken')
            refresh_token = auth_result.get('RefreshToken')
            
            print("\n" + "=" * 80)
            print("🎫 取得したトークン情報")
            print("=" * 80)
            
            if id_token:
                print(f"📋 ID Token (長さ: {len(id_token)} 文字):")
                print("─" * 50)
                print(id_token)
                print("─" * 50)
                
                # Authorization ヘッダー形式で表示
                print(f"\n📤 Authorization ヘッダー用:")
                print("─" * 50)
                print(f"Bearer {id_token}")
                print("─" * 50)
            
            if access_token:
                print(f"\n🔑 Access Token (長さ: {len(access_token)} 文字):")
                print("─" * 30)
                print(access_token[:100] + "...")  # 最初の100文字のみ表示
                print("─" * 30)
            
            # トークンのペイロード部分を確認（デバッグ用）
            if id_token:
                try:
                    # JWTのペイロード部分をデコード（検証なし）
                    import base64
                    parts = id_token.split('.')
                    if len(parts) >= 2:
                        # padding調整
                        payload = parts[1]
                        payload += '=' * (4 - len(payload) % 4)
                        decoded = base64.b64decode(payload)
                        payload_json = json.loads(decoded)
                        
                        print(f"\n🔍 ID Token ペイロード:")
                        print("─" * 30)
                        print(json.dumps(payload_json, indent=2))
                        print("─" * 30)
                except Exception as e:
                    print(f"ペイロードデコードエラー: {e}")
            
            return auth_result
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            
            print(f"❌ Cognito認証エラー: {error_code}")
            print(f"   メッセージ: {error_message}")
            return None
        except Exception as e:
            print(f"❌ 予期しないエラー: {e}")
            return None


def main():
    """IDトークン取得・表示用メイン関数"""
    
    print("🧪 IDトークン取得・表示ツール")
    print("=" * 60)
    
    # 設定 - 実際の値に変更してください
    CONFIG = {
        'AWS_REGION': 'ap-northeast-1',
        'USER_POOL_ID': 'ap-northeast-1_klrsHrEDO',
        'CLIENT_ID': '4mbhalmjanqg8fqqnibb2kahcn',
        'CLIENT_SECRET': None
    }
    
    print(f"🌍 リージョン: {CONFIG['AWS_REGION']}")
    print(f"👥 User Pool: {CONFIG['USER_POOL_ID']}")
    print(f"📱 Client ID: {CONFIG['CLIENT_ID']}")
    
    # ユーザー認証情報の取得
    print("\n🔑 Cognito認証情報を入力してください")
    print("-" * 40)
    
    username = input("ユーザー名: ").strip()
    if not username:
        print("❌ ユーザー名が入力されていません")
        return
    
    password = getpass.getpass("パスワード: ")
    if not password:
        print("❌ パスワードが入力されていません")
        return
    
    # トークン取得・表示
    debug_tool = CognitoTokenDebug(
        region=CONFIG['AWS_REGION'],
        user_pool_id=CONFIG['USER_POOL_ID'],
        client_id=CONFIG['CLIENT_ID'],
        client_secret=CONFIG['CLIENT_SECRET']
    )
    
    auth_result = debug_tool.get_tokens_with_debug(username, password)
    
    if auth_result:
        id_token = auth_result.get('IdToken')
        
        print("\n" + "=" * 80)
        print("📝 次の手順")
        print("=" * 80)
        print("1. 上記の「ID Token」をコピーしてください")
        print("2. AWS Console → API Gateway → Authorizers")
        print("3. 使用中のAuthorizerをクリック → Test")
        print("4. Authorization Token欄に以下を貼り付け:")
        print(f"   Bearer {id_token}")
        print("5. Testボタンをクリック")
        print("\n🎯 これでAuthorizerのテストができます！")
        
    else:
        print("❌ トークンの取得に失敗しました")


if __name__ == "__main__":
    main()