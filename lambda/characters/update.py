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
    キャラクター更新 Lambda 関数
    """
    
    # CORS headers（強化版）
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
        'Access-Control-Max-Age': '86400'
    }
    
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # CORS preflight
        if event.get('httpMethod') == 'OPTIONS':
            print("Handling CORS preflight request")
            return {
                'statusCode': 200,
                'headers': cors_headers,
                'body': ''
            }
        
        # HTTPメソッドをチェック
        http_method = event.get('httpMethod')
        print(f"HTTP Method: {http_method}")
        
        if http_method != 'PUT':
            return {
                'statusCode': 405,
                'headers': cors_headers,
                'body': json.dumps({'error': 'Method Not Allowed'}, ensure_ascii=False)
            }
        
        # ユーザーIDの取得（Cognito認証から）
        try:
            user_id = event['requestContext']['authorizer']['claims']['sub']
            print(f"User ID: {user_id}")
        except (KeyError, TypeError) as e:
            print(f"Authentication error: {e}")
            return {
                'statusCode': 401,
                'headers': cors_headers,
                'body': json.dumps({'error': '認証が必要です'}, ensure_ascii=False)
            }
        
        if not user_id:
            return {
                'statusCode': 401,
                'headers': cors_headers,
                'body': json.dumps({'error': '認証が必要です'}, ensure_ascii=False)
            }
        
        # キャラクターIDの取得
        try:
            character_id = event['pathParameters']['id']
            print(f"Character ID: {character_id}")
        except (KeyError, TypeError) as e:
            print(f"Path parameter error: {e}")
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': 'キャラクターIDが必要です'}, ensure_ascii=False)
            }
        
        if not character_id:
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': 'キャラクターIDが必要です'}, ensure_ascii=False)
            }
        
        # リクエストボディの解析
        try:
            character_data = json.loads(event['body'])
            print(f"Character data: {character_data}")
        except (json.JSONDecodeError, TypeError) as e:
            print(f"JSON decode error: {e}")
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': '無効なJSONです'}, ensure_ascii=False)
            }
        
        # 既存のキャラクターを確認
        table = dynamodb.Table(os.environ['CHARACTERS_TABLE'])
        
        try:
            response = table.get_item(
                Key={
                    'userId': user_id,
                    'id': character_id
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
                'body': json.dumps({'error': 'キャラクターが見つかりません'}, ensure_ascii=False)
            }
        
        existing_character = response['Item']
        print(f"Existing character: {existing_character}")
        
        # 更新データの準備（IDとuserIdは変更不可）
        updated_character = {
            **existing_character,
            **character_data,
            'id': character_id,
            'userId': user_id,
            'updatedAt': datetime.utcnow().isoformat() + 'Z'
        }
        
        print(f"Updated character: {updated_character}")
        
        # DynamoDBを更新
        table.put_item(Item=updated_character)
        
        print("Character updated successfully")
        
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps(updated_character, cls=DecimalEncoder, ensure_ascii=False)
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
            'body': json.dumps({'error': 'キャラクターの更新に失敗しました'}, ensure_ascii=False)
        }