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
    セーブデータ作成 Lambda 関数
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
            save_data = json.loads(event['body'])
            print(f"Save data: {save_data}")
        except (json.JSONDecodeError, TypeError) as e:
            print(f"JSON decode error: {e}")
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': '無効なJSONです'}, ensure_ascii=False)
            }
        
        # バリデーション
        if not save_data.get('character') or not save_data['character'].get('id'):
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': 'キャラクター情報が必要です'}, ensure_ascii=False)
            }
        
        character_id = save_data['character']['id']
        now = datetime.utcnow().isoformat() + 'Z'
        
        # セーブデータの作成
        game_save = {
            'userId': user_id,
            'characterId': character_id,
            'id': str(uuid.uuid4()),
            'character': save_data['character'],
            'currentFloor': save_data.get('currentFloor', 1),
            'playerX': save_data.get('playerX', 1),
            'playerY': save_data.get('playerY', 6),
            'potions': save_data.get('potions', 3),
            'keys': save_data.get('keys', 0),
            'doorStates': save_data.get('doorStates', {}),
            'chestStates': save_data.get('chestStates', {}),
            'playerPositions': save_data.get('playerPositions', {
                '1': {'x': 1, 'y': 6},
                '2': {'x': 1, 'y': 1},
                '3': {'x': 1, 'y': 1}
            }),
            'messages': save_data.get('messages', []),
            'createdAt': now,
            'updatedAt': now
        }
        
        print(f"Creating game save: {game_save}")
        
        # DynamoDBに保存
        table = dynamodb.Table(os.environ['GAME_SAVES_TABLE'])
        table.put_item(Item=game_save)
        
        print("Game save created successfully")
        
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps(game_save, ensure_ascii=False)
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
            'body': json.dumps({'error': 'ゲームの保存に失敗しました'}, ensure_ascii=False)
        }