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
            'createdAt': now,
            'updatedAt': now
        }
        
        # DynamoDBに保存
        table = dynamodb.Table(os.environ['GAME_SAVES_TABLE'])
        table.put_item(Item=game_save)
        
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