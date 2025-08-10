import json
import boto3
import os
from botocore.exceptions import ClientError

# DynamoDB client
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """
    セーブデータ削除 Lambda 関数
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
        
        # セーブIDの取得
        save_id = event['pathParameters']['id']
        if not save_id:
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': 'セーブIDが必要です'}, ensure_ascii=False)
            }
        
        # セーブデータの存在確認（IDで検索）
        table = dynamodb.Table(os.environ['GAME_SAVES_TABLE'])
        
        try:
            # まずはIDでセーブデータを検索
            response = table.scan(
                FilterExpression='userId = :userId AND id = :saveId',
                ExpressionAttributeValues={
                    ':userId': user_id,
                    ':saveId': save_id
                }
            )
        except ClientError as e:
            print(f"DynamoDB scan error: {e}")
            return {
                'statusCode': 500,
                'headers': cors_headers,
                'body': json.dumps({'error': 'データベースエラーが発生しました'}, ensure_ascii=False)
            }
        
        if not response.get('Items') or len(response['Items']) == 0:
            return {
                'statusCode': 404,
                'headers': cors_headers,
                'body': json.dumps({'error': 'セーブデータが見つかりません'}, ensure_ascii=False)
            }
        
        save_data = response['Items'][0]
        character_id = save_data['characterId']
        
        # セーブデータを削除
        try:
            table.delete_item(
                Key={
                    'userId': user_id,
                    'characterId': character_id
                }
            )
        except ClientError as e:
            print(f"DynamoDB delete_item error: {e}")
            return {
                'statusCode': 500,
                'headers': cors_headers,
                'body': json.dumps({'error': 'セーブデータ削除に失敗しました'}, ensure_ascii=False)
            }
        
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps({'message': 'セーブデータを削除しました'}, ensure_ascii=False)
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
            'body': json.dumps({'error': 'セーブデータの削除に失敗しました'}, ensure_ascii=False)
        }