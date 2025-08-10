import json
import boto3
import os
from botocore.exceptions import ClientError

# DynamoDB client
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """
    キャラクター削除 Lambda 関数
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
        
        # キャラクターIDの取得
        character_id = event['pathParameters']['id']
        if not character_id:
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': 'キャラクターIDが必要です'}, ensure_ascii=False)
            }
        
        # キャラクターの存在確認
        characters_table = dynamodb.Table(os.environ['CHARACTERS_TABLE'])
        
        try:
            response = characters_table.get_item(
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
        
        # キャラクターを削除
        try:
            characters_table.delete_item(
                Key={
                    'userId': user_id,
                    'id': character_id
                }
            )
        except ClientError as e:
            print(f"DynamoDB delete_item error: {e}")
            return {
                'statusCode': 500,
                'headers': cors_headers,
                'body': json.dumps({'error': 'キャラクター削除に失敗しました'}, ensure_ascii=False)
            }
        
        # 関連するセーブデータも削除
        try:
            if 'GAME_SAVES_TABLE' in os.environ:
                saves_table = dynamodb.Table(os.environ['GAME_SAVES_TABLE'])
                saves_table.delete_item(
                    Key={
                        'userId': user_id,
                        'characterId': character_id
                    }
                )
        except ClientError as e:
            print(f"Save data deletion warning: {e}")
            # セーブデータの削除に失敗してもキャラクター削除は成功とする
        
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps({'message': 'キャラクターを削除しました'}, ensure_ascii=False)
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
            'body': json.dumps({'error': 'キャラクターの削除に失敗しました'}, ensure_ascii=False)
        }