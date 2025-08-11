#!/usr/bin/env python3
"""
AWS Cognito認証 + Lambda API CORS テストスクリプト
認証からトークン取得、API接続テストまでを一貫して実行
"""

import boto3
import requests
import json
import sys
import getpass
import hmac
import hashlib
import base64
from typing import Optional, Dict, Any
from botocore.exceptions import ClientError, NoCredentialsError


class CognitoAuthenticator:
    def __init__(self, region: str, user_pool_id: str, client_id: str, client_secret: Optional[str] = None):
        """
        Cognito認証クラスの初期化
        
        Args:
            region: AWSリージョン
            user_pool_id: Cognito User Pool ID
            client_id: Cognito App Client ID
            client_secret: Cognito App Client Secret (オプション)
        """
        self.region = region
        self.user_pool_id = user_pool_id
        self.client_id = client_id
        self.client_secret = client_secret
        
        try:
            self.cognito_client = boto3.client('cognito-idp', region_name=region)
        except NoCredentialsError:
            print("❌ AWS認証情報が見つかりません。AWS CLIの設定を確認してください。")
            print("   aws configure または環境変数の設定が必要です。")
            sys.exit(1)
    
    def _calculate_secret_hash(self, username: str) -> Optional[str]:
        """
        Client Secretを使用してSecret Hashを計算
        
        Args:
            username: ユーザー名
            
        Returns:
            str: Secret Hash
        """
        if not self.client_secret:
            return None
            
        message = username + self.client_id
        dig = hmac.new(
            str(self.client_secret).encode('UTF-8'),
            msg=str(message).encode('UTF-8'),
            digestmod=hashlib.sha256
        ).digest()
        return base64.b64encode(dig).decode()
    
    def authenticate_user(self, username: str, password: str) -> Optional[Dict[str, Any]]:
        """
        ユーザー認証を実行してトークンを取得
        
        Args:
            username: ユーザー名
            password: パスワード
            
        Returns:
            Dict: 認証結果（トークン情報を含む）
        """
        try:
            # 認証パラメータの準備
            auth_params = {
                'USERNAME': username,
                'PASSWORD': password
            }
            
            # Client Secretがある場合はSecret Hashを追加
            secret_hash = self._calculate_secret_hash(username)
            if secret_hash:
                auth_params['SECRET_HASH'] = secret_hash
            
            print(f"🔐 Cognito認証中... (ユーザー: {username})")
            
            # 認証実行
            response = self.cognito_client.admin_initiate_auth(
                UserPoolId=self.user_pool_id,
                ClientId=self.client_id,
                AuthFlow='ADMIN_NO_SRP_AUTH',
                AuthParameters=auth_params
            )
            
            # 追加のチャレンジが必要かチェック
            if 'ChallengeName' in response:
                challenge_name = response['ChallengeName']
                print(f"⚠️  追加認証が必要: {challenge_name}")
                
                if challenge_name == 'NEW_PASSWORD_REQUIRED':
                    print("新しいパスワードの設定が必要です。")
                    return None
                elif challenge_name == 'MFA_SETUP':
                    print("MFAセットアップが必要です。")
                    return None
                else:
                    print(f"未対応のチャレンジ: {challenge_name}")
                    return None
            
            # 認証成功
            auth_result = response['AuthenticationResult']
            print("✅ Cognito認証成功!")
            print(f"   アクセストークン有効期限: {auth_result.get('ExpiresIn', '不明')}秒")
            
            return auth_result
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_message = e.response['Error']['Message']
            
            print(f"❌ Cognito認証エラー: {error_code}")
            print(f"   メッセージ: {error_message}")
            
            if error_code == 'NotAuthorizedException':
                print("   → ユーザー名またはパスワードが間違っています")
            elif error_code == 'UserNotFoundException':
                print("   → 指定されたユーザーが見つかりません")
            elif error_code == 'UserNotConfirmedException':
                print("   → ユーザーのメール確認が完了していません")
            elif error_code == 'TooManyRequestsException':
                print("   → リクエスト数が多すぎます。しばらく待ってから再試行してください")
            
            return None
        except Exception as e:
            print(f"❌ 予期しないエラー: {e}")
            return None


class LambdaCorsTest:
    def __init__(self, api_endpoint: str, id_token: Optional[str] = None):
        """
        Lambda CORS テストクラスの初期化
        
        Args:
            api_endpoint: API Gateway のエンドポイントURL
            id_token: Cognito ID Token
        """
        self.api_endpoint = api_endpoint.rstrip('/')
        self.id_token = id_token
        self.session = requests.Session()
        
        # デフォルトヘッダー
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        })
        
        # Authorization ヘッダーの設定
        if self.id_token:
            self.session.headers.update({
                'Authorization': f'Bearer {self.id_token}'
            })
    
    def test_cors_preflight(self) -> bool:
        """CORS Preflight リクエスト（OPTIONS）のテスト"""
        print("\n" + "=" * 60)
        print("🚀 CORS Preflight テスト (OPTIONS)")
        print("=" * 60)
        
        try:
            response = self.session.options(
                f"{self.api_endpoint}/characters",
                headers={
                    'Origin': 'http://localhost:3000',
                    'Access-Control-Request-Method': 'GET',
                    'Access-Control-Request-Headers': 'authorization,content-type'
                }
            )
            
            print(f"ステータスコード: {response.status_code}")
            print(f"CORSヘッダー:")
            
            cors_headers = {}
            for header, value in response.headers.items():
                if header.lower().startswith('access-control'):
                    cors_headers[header] = value
                    print(f"  {header}: {value}")
            
            if not cors_headers:
                print("  (CORSヘッダーなし)")
            
            # CORS ヘッダーの確認
            required_headers = ['Access-Control-Allow-Origin', 'Access-Control-Allow-Methods']
            missing_headers = [h for h in required_headers if h not in response.headers]
            
            if response.status_code == 200 and not missing_headers:
                print("✅ CORS Preflight テスト成功!")
                return True
            else:
                print(f"❌ CORS Preflight テスト失敗:")
                if response.status_code != 200:
                    print(f"  - ステータスコード: {response.status_code} (期待値: 200)")
                if missing_headers:
                    print(f"  - 不足ヘッダー: {', '.join(missing_headers)}")
                return False
                
        except Exception as e:
            print(f"❌ CORS Preflight テストでエラー: {e}")
            return False
    
    def test_get_characters(self) -> bool:
        """キャラクター一覧取得（GET）のテスト"""
        print("\n" + "=" * 60)
        print("📋 キャラクター一覧取得テスト (GET)")
        print("=" * 60)
        
        try:
            response = self.session.get(
                f"{self.api_endpoint}/characters",
                headers={'Origin': 'http://localhost:3000'}
            )
            
            print(f"ステータスコード: {response.status_code}")
            print(f"Content-Type: {response.headers.get('Content-Type', 'なし')}")
            
            # CORSヘッダーの表示
            cors_headers = {h: v for h, v in response.headers.items() 
                          if h.lower().startswith('access-control')}
            if cors_headers:
                print("CORSヘッダー:")
                for header, value in cors_headers.items():
                    print(f"  {header}: {value}")
            
            if response.status_code == 200:
                try:
                    data = response.json()
                    print(f"✅ JSON パース成功")
                    
                    if isinstance(data, list):
                        print(f"📊 キャラクター数: {len(data)}")
                        if len(data) > 0:
                            print("最初のキャラクター例:")
                            first_char = data[0]
                            for key, value in first_char.items():
                                print(f"  {key}: {value}")
                        else:
                            print("キャラクターリストは空です")
                    else:
                        print("予期しないデータ形式:")
                        print(json.dumps(data, indent=2, ensure_ascii=False))
                    
                    print("✅ キャラクター一覧取得テスト成功!")
                    return True
                    
                except json.JSONDecodeError as e:
                    print(f"❌ JSON パースエラー: {e}")
                    print(f"レスポンステキスト: {response.text[:500]}...")
                    return False
            
            elif response.status_code == 401:
                print("🔐 認証エラー (401)")
                try:
                    error_data = response.json()
                    print(f"エラー: {error_data.get('error', '認証が必要です')}")
                except:
                    print(f"エラーレスポンス: {response.text}")
                print("💡 IDトークンが無効または期限切れの可能性があります")
                return False
            
            else:
                print(f"❌ 予期しないステータスコード: {response.status_code}")
                try:
                    error_data = response.json()
                    print(f"エラー: {json.dumps(error_data, indent=2, ensure_ascii=False)}")
                except:
                    print(f"レスポンス: {response.text}")
                return False
                
        except Exception as e:
            print(f"❌ キャラクター一覧取得テストでエラー: {e}")
            return False
    
    def test_invalid_method(self) -> bool:
        """無効なHTTPメソッド（POST）のテスト"""
        print("\n" + "=" * 60)
        print("🚫 無効メソッドテスト (POST)")
        print("=" * 60)
        
        try:
            response = self.session.post(
                f"{self.api_endpoint}/characters",
                headers={'Origin': 'http://localhost:3000'},
                json={"test": "data"}
            )
            
            print(f"ステータスコード: {response.status_code}")
            
            if response.status_code == 405:
                try:
                    error_data = response.json()
                    print(f"エラーメッセージ: {error_data.get('error', 'Method Not Allowed')}")
                except:
                    print(f"レスポンス: {response.text}")
                print("✅ 無効メソッドテスト成功 (405 Method Not Allowed)")
                return True
            else:
                print(f"❌ 期待するステータスコード: 405, 実際: {response.status_code}")
                return False
                
        except Exception as e:
            print(f"❌ 無効メソッドテストでエラー: {e}")
            return False
    
    def run_all_tests(self) -> bool:
        """すべてのテストを実行"""
        results = [
            self.test_cors_preflight(),
            self.test_get_characters(),
            self.test_invalid_method()
        ]
        
        # 結果サマリー
        print("\n" + "=" * 60)
        print("📊 API テスト結果サマリー")
        print("=" * 60)
        
        test_names = ["CORS Preflight", "キャラクター一覧取得", "無効メソッド"]
        for i, (name, result) in enumerate(zip(test_names, results)):
            status = "✅ 成功" if result else "❌ 失敗"
            print(f"{i+1}. {name}: {status}")
        
        success_count = sum(results)
        print(f"\n成功: {success_count}/{len(results)}")
        
        return success_count == len(results)


def get_user_credentials():
    """ユーザーから認証情報を取得"""
    print("🔑 Cognito認証情報を入力してください")
    print("-" * 40)
    
    username = input("ユーザー名: ").strip()
    if not username:
        print("❌ ユーザー名が入力されていません")
        return None, None
    
    password = getpass.getpass("パスワード: ")
    if not password:
        print("❌ パスワードが入力されていません")
        return None, None

    return username, password


def main():
    """メイン関数"""
    print("🧪 AWS Cognito認証 + Lambda API テスト")
    print("=" * 60)
    
    # 設定 - 実際の値に変更してください
    CONFIG = {
        'AWS_REGION': 'ap-northeast-1',
        'USER_POOL_ID': 'ap-northeast-1_klrsHrEDO',  # 実際のUser Pool IDに変更
        'CLIENT_ID': '4mbhalmjanqg8fqqnibb2kahcn',               # 実際のApp Client IDに変更
        'CLIENT_SECRET': None,                       # Client Secretがある場合は設定
        'API_ENDPOINT': 'https://dlmus6jbn8.execute-api.ap-northeast-1.amazonaws.com/prod'
    }
    
    # コマンドライン引数で設定を上書き可能
    if len(sys.argv) > 1:
        CONFIG['API_ENDPOINT'] = sys.argv[1]
    if len(sys.argv) > 2:
        CONFIG['USER_POOL_ID'] = sys.argv[2]
    if len(sys.argv) > 3:
        CONFIG['CLIENT_ID'] = sys.argv[3]
    
    print(f"🌍 リージョン: {CONFIG['AWS_REGION']}")
    print(f"👥 User Pool: {CONFIG['USER_POOL_ID']}")
    print(f"📱 Client ID: {CONFIG['CLIENT_ID']}")
    print(f"🔗 API エンドポイント: {CONFIG['API_ENDPOINT']}")
    
    # 設定値のバリデーション
    if 'XXXXXXXXX' in CONFIG['USER_POOL_ID'] or 'your-' in CONFIG['CLIENT_ID']:
        print("\n❌ 設定エラー:")
        print("   CONFIG辞書内の以下の値を実際の値に変更してください:")
        print(f"   - USER_POOL_ID: {CONFIG['USER_POOL_ID']}")
        print(f"   - CLIENT_ID: {CONFIG['CLIENT_ID']}")
        print(f"   - API_ENDPOINT: {CONFIG['API_ENDPOINT']}")
        return
    
    # Cognito認証
    authenticator = CognitoAuthenticator(
        region=CONFIG['AWS_REGION'],
        user_pool_id=CONFIG['USER_POOL_ID'],
        client_id=CONFIG['CLIENT_ID'],
        client_secret=CONFIG['CLIENT_SECRET']
    )
    
    # ユーザー認証情報の取得
    username, password = get_user_credentials()
    if not username or not password:
        return
    
    # 認証実行
    auth_result = authenticator.authenticate_user(username, password)
    if not auth_result:
        print("❌ 認証に失敗しました。処理を終了します。")
        return
    
    # IDトークンを取得
    id_token = auth_result.get('IdToken')
    if not id_token:
        print("❌ IDトークンが取得できませんでした")
        return
    
    print(f"🎫 IDトークンを取得しました (長さ: {len(id_token)} 文字)")
    
    # API接続テスト実行
    print("\n" + "=" * 60)
    print("🚀 API接続テスト開始")
    print("=" * 60)
    
    tester = LambdaCorsTest(CONFIG['API_ENDPOINT'], id_token)
    success = tester.run_all_tests()
    
    # 最終結果
    print("\n" + "=" * 60)
    print("🏁 最終結果")
    print("=" * 60)
    
    if success:
        print("🎉 すべてのテストが成功しました!")
        print("✅ Cognito認証とLambda API接続が正常に動作しています")
    else:
        print("⚠️  いくつかのテストが失敗しました")
        print("💡 失敗の詳細を確認して設定やコードを見直してください")
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()