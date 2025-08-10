import json
import boto3
import os
import decimal
from datetime import datetime
from botocore.exceptions import ClientError

# DynamoDB client
dynamodb = boto3.resource('dynamodb')

class DecimalEncoder(json.JSONEncoder):
    """DynamoDBのDecimal型をJSONにエンコードするためのカスタムエンコーダー"""
    def default(self, obj):
        if isinstance(obj, decimal.Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    """
    セーブデータ更新 Lambda 関数
    """
    
    # CORS headers
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }
    
    try:
        # CORS preflight
        if event.get('httpMethod') == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': cors_headers,
                'body': ''
            }
        
        # ユーザーIDの取得（Cognito認証から）
        user_id = event['requestContext']['authorizer']['claims']['sub']
        if not user_id:
            return {
                'statusCode': 401,
                'headers': cors_headers,
                'body': json.dumps({'error': '認証が必要です'}, ensure_ascii=False)
            }
        
        # リクエストボディの解析
        try:
            save_data = json.loads(event['body'])
        except (json.JSONDecodeError, TypeError):
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': '無効なJSONです'}, ensure_ascii=False)
            }
        
        # バリデーション
        if not save_data.get('id') or not save_data.get('characterId'):
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': 'セーブデータIDとキャラクターIDが必要です'}, ensure_ascii=False)
            }
        
        character_id = save_data['characterId']
        
        # 既存のセーブデータを確認
        table = dynamodb.Table(os.environ['GAME_SAVES_TABLE'])
        
        try:
            response = table.get_item(
                Key={
                    'userId': user_id,
                    'characterId': character_id
                }
            )
        except ClientError as e:
            print(f"DynamoDB get_item error: {e}")
            return {
                'statusCode': 500,
                'headers': cors_headers,
                'body': json.dumps({'error': 'データベースエラーが発生しました'}, ensure_ascii=False)
            }
        
        if 'Item' not in response:
            return {
                'statusCode': 404,
                'headers': cors_headers,
                'body': json.dumps({'error': 'セーブデータが見つかりません'}, ensure_ascii=False)
            }
        
        existing_save = response['Item']
        
        # 更新データの準備（userIdは変更不可）
        updated_save = {
            **existing_save,
            **save_data,
            'userId': user_id,
            'updatedAt': datetime.utcnow().isoformat() + 'Z'
        }
        
        # DynamoDBを更新
        table.put_item(Item=updated_save)
        
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps(updated_save, cls=DecimalEncoder, ensure_ascii=False)
        }
        
    except ClientError as e:
        print(f"DynamoDB error: {e}")
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'error': 'データベースエラーが発生しました'}, ensure_ascii=False)
        }
    except Exception as e:
        print(f"Unexpected error: {e}")
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'error': 'セーブデータの更新に失敗しました'}, ensure_ascii=False)
        }