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
    キャラクター一覧取得 Lambda 関数
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
        # CORS preflight（必ず最初に処理）
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
        
        if http_method != 'GET':
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
        
        # ユーザーのキャラクター一覧を取得
        table = dynamodb.Table(os.environ['CHARACTERS_TABLE'])
        print(f"Querying table: {os.environ['CHARACTERS_TABLE']}")
        
        response = table.query(
            KeyConditionExpression='userId = :userId',
            ExpressionAttributeValues={
                ':userId': user_id
            },
            ScanIndexForward=False  # 作成日時の降順
        )
        
        characters = response.get('Items', [])
        print(f"Found {len(characters)} characters")
        
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps(characters, cls=DecimalEncoder, ensure_ascii=False)
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
            'body': json.dumps({'error': 'キャラクター一覧の取得に失敗しました'}, ensure_ascii=False)
        }