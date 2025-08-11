import json
import boto3
import uuid
import os
from datetime import datetime
from botocore.exceptions import ClientError

# DynamoDB client
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """
    キャラクター作成 Lambda 関数
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
        
        if http_method != 'POST':
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
        
        # リクエストボディの解析
        try:
            body = json.loads(event['body'])
            print(f"Request body: {body}")
        except (json.JSONDecodeError, TypeError) as e:
            print(f"JSON decode error: {e}")
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': '無効なJSONです'}, ensure_ascii=False)
            }
        
        # バリデーション
        name = body.get('name', '').strip()
        if not name:
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': 'キャラクター名は必須です'}, ensure_ascii=False)
            }
        
        # キャラクターデータの作成
        character_id = str(uuid.uuid4())
        now = datetime.utcnow().isoformat() + 'Z'
        
        character = {
            'userId': user_id,
            'id': character_id,
            'name': name,
            'level': body.get('level', 1),
            'exp': body.get('exp', 0),
            'expToNext': body.get('expToNext', 100),
            'hp': body.get('hp', 50),
            'maxHp': body.get('maxHp', 50),
            'attack': body.get('attack', 10),
            'defense': body.get('defense', 5),
            'gold': body.get('gold', 0),
            'createdAt': now,
            'updatedAt': now
        }
        
        print(f"Creating character: {character}")
        
        # DynamoDBに保存
        table = dynamodb.Table(os.environ['CHARACTERS_TABLE'])
        table.put_item(Item=character)
        
        print("Character created successfully")
        
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps(character, ensure_ascii=False)
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
            'body': json.dumps({'error': 'キャラクターの作成に失敗しました'}, ensure_ascii=False)
        }