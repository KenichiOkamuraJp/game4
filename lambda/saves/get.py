import json
import boto3
import os
import decimal
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
    セーブデータ取得 Lambda 関数
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
        character_id = event['pathParameters']['characterId']
        if not character_id:
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'error': 'キャラクターIDが必要です'}, ensure_ascii=False)
            }
        
        # セーブデータを取得
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
        
        save_data = response['Item']
        
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps(save_data, cls=DecimalEncoder, ensure_ascii=False)
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
            'body': json.dumps({'error': 'セーブデータの取得に失敗しました'}, ensure_ascii=False)
        }