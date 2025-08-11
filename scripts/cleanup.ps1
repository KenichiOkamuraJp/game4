#Requires -Version 5.1
# AWS Dungeon RPG Complete Cleanup Script
# このスクリプトはプロジェクトに関連する全てのAWSリソースを削除します

[CmdletBinding()]
param(
    [string]$ProjectName = "dungeon-rpg",
    [string]$AWSRegion = "ap-northeast-1",
    [switch]$SkipConfirmation = $false,
    [switch]$Force = $false
)

# エンコーディング設定
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

$ErrorActionPreference = "Continue"  # エラーが発生しても続行

Write-Host "================================================" -ForegroundColor Red
Write-Host "    AWS Dungeon RPG クリーンアップスクリプト" -ForegroundColor Red
Write-Host "================================================" -ForegroundColor Red
Write-Host ""

# ログ関数
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Success {
    param([string]$Message)
    Write-Host "[?] $Message" -ForegroundColor Cyan
}

# AWS CLI確認
try {
    $awsVersion = aws --version 2>$null
    if (-not $awsVersion) {
        throw "AWS CLI not found"
    }
    Write-Info "AWS CLI found: $($awsVersion.Split()[0])"
} catch {
    Write-Error-Custom "AWS CLIがインストールされていません"
    exit 1
}

# AWS認証確認
try {
    $callerIdentity = aws sts get-caller-identity --output json 2>$null | ConvertFrom-Json
    if (-not $callerIdentity) {
        throw "Authentication failed"
    }
    Write-Info "AWS Account: $($callerIdentity.Account)"
    Write-Info "User/Role: $($callerIdentity.Arn)"
} catch {
    Write-Error-Custom "AWS認証情報が設定されていません"
    Write-Info "aws configure で設定してください"
    exit 1
}

Write-Host ""
Write-Warn "==================== 警告 ===================="
Write-Warn "このスクリプトは以下のリソースを削除します:"
Write-Warn "- CloudFormationスタック: $ProjectName-stack"
Write-Warn "- すべてのLambda関数 (プレフィックス: $ProjectName-)"
Write-Warn "- DynamoDBテーブル"
Write-Warn "- API Gateway"
Write-Warn "- Cognito User Pool & Identity Pool"
Write-Warn "- IAMロールとポリシー"
Write-Warn "- S3バケット（存在する場合）"
Write-Warn "=============================================="
Write-Host ""

if (-not $SkipConfirmation) {
    Write-Host "本当に削除しますか？ この操作は取り消せません！" -ForegroundColor Red
    $confirmation = Read-Host "削除を実行する場合は 'DELETE' と入力してください"
    
    if ($confirmation -ne "DELETE") {
        Write-Info "クリーンアップをキャンセルしました"
        exit 0
    }
}

Write-Host ""
Write-Info "クリーンアップを開始します..."
Write-Host ""

$deletedResources = @()
$failedResources = @()

# 1. CloudFormationスタックの削除
Write-Info "CloudFormationスタックを確認中..."
$stackName = "$ProjectName-stack"

try {
    $stack = aws cloudformation describe-stacks `
        --stack-name $stackName `
        --region $AWSRegion `
        --output json 2>$null | ConvertFrom-Json
    
    if ($stack) {
        Write-Info "CloudFormationスタック '$stackName' を削除中..."
        
        # スタック削除を開始
        aws cloudformation delete-stack `
            --stack-name $stackName `
            --region $AWSRegion 2>&1 | Out-Null
        
        Write-Info "スタック削除を待機中... (これには数分かかる場合があります)"
        
        # 削除完了を待機（タイムアウト10分）
        $timeout = 600
        $elapsed = 0
        $checkInterval = 10
        
        while ($elapsed -lt $timeout) {
            Start-Sleep -Seconds $checkInterval
            $elapsed += $checkInterval
            
            # スタックの状態を確認
            $stackStatus = aws cloudformation describe-stacks `
                --stack-name $stackName `
                --region $AWSRegion `
                --query 'Stacks[0].StackStatus' `
                --output text 2>$null
            
            if (-not $stackStatus) {
                Write-Success "CloudFormationスタックが削除されました"
                $deletedResources += "CloudFormationスタック: $stackName"
                break
            }
            
            Write-Info "スタックステータス: $stackStatus (経過時間: ${elapsed}秒)"
        }
        
        if ($elapsed -ge $timeout) {
            Write-Warn "スタック削除がタイムアウトしました。AWS コンソールで確認してください。"
            $failedResources += "CloudFormationスタック: $stackName (タイムアウト)"
        }
    } else {
        Write-Info "CloudFormationスタックが見つかりません"
    }
} catch {
    Write-Info "CloudFormationスタックが存在しません"
}

# 2. 残存するLambda関数の削除
Write-Info "Lambda関数を確認中..."

try {
    $lambdaFunctions = aws lambda list-functions `
        --query "Functions[?starts_with(FunctionName, '$ProjectName-')].FunctionName" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($lambdaFunctions -and $lambdaFunctions.Count -gt 0) {
        Write-Info "$($lambdaFunctions.Count)個のLambda関数が見つかりました"
        
        foreach ($functionName in $lambdaFunctions) {
            try {
                Write-Info "Lambda関数を削除中: $functionName"
                aws lambda delete-function `
                    --function-name $functionName `
                    --region $AWSRegion 2>&1 | Out-Null
                
                Write-Success "削除完了: $functionName"
                $deletedResources += "Lambda関数: $functionName"
            } catch {
                Write-Error-Custom "削除失敗: $functionName"
                $failedResources += "Lambda関数: $functionName"
            }
        }
    } else {
        Write-Info "Lambda関数が見つかりません"
    }
} catch {
    Write-Warn "Lambda関数の一覧取得に失敗しました"
}

# 3. DynamoDBテーブルの削除
Write-Info "DynamoDBテーブルを確認中..."

$tableNames = @(
    "$ProjectName-characters",
    "$ProjectName-saves"
)

foreach ($tableName in $tableNames) {
    try {
        $table = aws dynamodb describe-table `
            --table-name $tableName `
            --region $AWSRegion `
            --output json 2>$null | ConvertFrom-Json
        
        if ($table) {
            Write-Info "DynamoDBテーブルを削除中: $tableName"
            aws dynamodb delete-table `
                --table-name $tableName `
                --region $AWSRegion 2>&1 | Out-Null
            
            Write-Success "削除完了: $tableName"
            $deletedResources += "DynamoDBテーブル: $tableName"
        }
    } catch {
        Write-Info "テーブルが存在しません: $tableName"
    }
}

# 4. API Gatewayの削除
Write-Info "API Gatewayを確認中..."

try {
    $apis = aws apigateway get-rest-apis `
        --query "items[?contains(name, '$ProjectName')].{id:id,name:name}" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($apis -and $apis.Count -gt 0) {
        foreach ($api in $apis) {
            try {
                Write-Info "API Gatewayを削除中: $($api.name) (ID: $($api.id))"
                aws apigateway delete-rest-api `
                    --rest-api-id $api.id `
                    --region $AWSRegion 2>&1 | Out-Null
                
                Write-Success "削除完了: $($api.name)"
                $deletedResources += "API Gateway: $($api.name)"
            } catch {
                Write-Error-Custom "削除失敗: $($api.name)"
                $failedResources += "API Gateway: $($api.name)"
            }
        }
    } else {
        Write-Info "API Gatewayが見つかりません"
    }
} catch {
    Write-Warn "API Gatewayの一覧取得に失敗しました"
}

# 5. Cognito User Poolの削除
Write-Info "Cognito User Poolを確認中..."

try {
    $userPools = aws cognito-idp list-user-pools `
        --max-results 60 `
        --query "UserPools[?contains(Name, '$ProjectName')].{Id:Id,Name:Name}" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($userPools -and $userPools.Count -gt 0) {
        foreach ($pool in $userPools) {
            try {
                # User Pool内のドメインを先に削除
                $domains = aws cognito-idp describe-user-pool `
                    --user-pool-id $pool.Id `
                    --query 'UserPool.Domain' `
                    --region $AWSRegion `
                    --output text 2>$null
                
                if ($domains -and $domains -ne "None") {
                    Write-Info "Cognitoドメインを削除中: $domains"
                    aws cognito-idp delete-user-pool-domain `
                        --domain $domains `
                        --region $AWSRegion 2>&1 | Out-Null
                }
                
                Write-Info "User Poolを削除中: $($pool.Name)"
                aws cognito-idp delete-user-pool `
                    --user-pool-id $pool.Id `
                    --region $AWSRegion 2>&1 | Out-Null
                
                Write-Success "削除完了: $($pool.Name)"
                $deletedResources += "Cognito User Pool: $($pool.Name)"
            } catch {
                Write-Error-Custom "削除失敗: $($pool.Name)"
                $failedResources += "Cognito User Pool: $($pool.Name)"
            }
        }
    } else {
        Write-Info "Cognito User Poolが見つかりません"
    }
} catch {
    Write-Warn "Cognito User Poolの一覧取得に失敗しました"
}

# 6. Cognito Identity Poolの削除
Write-Info "Cognito Identity Poolを確認中..."

try {
    $identityPools = aws cognito-identity list-identity-pools `
        --max-results 60 `
        --query "IdentityPools[?contains(IdentityPoolName, '$ProjectName')].{Id:IdentityPoolId,Name:IdentityPoolName}" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($identityPools -and $identityPools.Count -gt 0) {
        foreach ($pool in $identityPools) {
            try {
                Write-Info "Identity Poolを削除中: $($pool.Name)"
                aws cognito-identity delete-identity-pool `
                    --identity-pool-id $pool.Id `
                    --region $AWSRegion 2>&1 | Out-Null
                
                Write-Success "削除完了: $($pool.Name)"
                $deletedResources += "Cognito Identity Pool: $($pool.Name)"
            } catch {
                Write-Error-Custom "削除失敗: $($pool.Name)"
                $failedResources += "Cognito Identity Pool: $($pool.Name)"
            }
        }
    } else {
        Write-Info "Cognito Identity Poolが見つかりません"
    }
} catch {
    Write-Warn "Cognito Identity Poolの一覧取得に失敗しました"
}

# 7. IAMロールの削除
Write-Info "IAMロールを確認中..."

$roleNames = @(
    "$ProjectName-lambda-role",
    "$ProjectName-cognito-authenticated-role",
    "$ProjectName-cognito-unauthenticated-role"
)

foreach ($roleName in $roleNames) {
    try {
        $role = aws iam get-role `
            --role-name $roleName `
            --output json 2>$null | ConvertFrom-Json
        
        if ($role) {
            # ロールにアタッチされたポリシーを削除
            $attachedPolicies = aws iam list-attached-role-policies `
                --role-name $roleName `
                --query 'AttachedPolicies[].PolicyArn' `
                --output json | ConvertFrom-Json
            
            foreach ($policyArn in $attachedPolicies) {
                Write-Info "ポリシーをデタッチ中: $policyArn"
                aws iam detach-role-policy `
                    --role-name $roleName `
                    --policy-arn $policyArn 2>&1 | Out-Null
            }
            
            # インラインポリシーを削除
            $inlinePolicies = aws iam list-role-policies `
                --role-name $roleName `
                --query 'PolicyNames' `
                --output json | ConvertFrom-Json
            
            foreach ($policyName in $inlinePolicies) {
                Write-Info "インラインポリシーを削除中: $policyName"
                aws iam delete-role-policy `
                    --role-name $roleName `
                    --policy-name $policyName 2>&1 | Out-Null
            }
            
            Write-Info "IAMロールを削除中: $roleName"
            aws iam delete-role `
                --role-name $roleName 2>&1 | Out-Null
            
            Write-Success "削除完了: $roleName"
            $deletedResources += "IAMロール: $roleName"
        }
    } catch {
        Write-Info "IAMロールが存在しません: $roleName"
    }
}

# 8. S3バケットの削除（もし存在すれば）
Write-Info "S3バケットを確認中..."

try {
    $buckets = aws s3api list-buckets `
        --query "Buckets[?contains(Name, '$ProjectName')].Name" `
        --output json | ConvertFrom-Json
    
    if ($buckets -and $buckets.Count -gt 0) {
        foreach ($bucketName in $buckets) {
            try {
                Write-Info "S3バケットを空にしています: $bucketName"
                aws s3 rm "s3://$bucketName" --recursive 2>&1 | Out-Null
                
                Write-Info "S3バケットを削除中: $bucketName"
                aws s3api delete-bucket `
                    --bucket $bucketName `
                    --region $AWSRegion 2>&1 | Out-Null
                
                Write-Success "削除完了: $bucketName"
                $deletedResources += "S3バケット: $bucketName"
            } catch {
                Write-Error-Custom "削除失敗: $bucketName"
                $failedResources += "S3バケット: $bucketName"
            }
        }
    } else {
        Write-Info "S3バケットが見つかりません"
    }
} catch {
    Write-Warn "S3バケットの一覧取得に失敗しました"
}

# 9. CloudWatch Log Groupsの削除
Write-Info "CloudWatch Log Groupsを確認中..."

try {
    $logGroups = aws logs describe-log-groups `
        --log-group-name-prefix "/aws/lambda/$ProjectName" `
        --query 'logGroups[].logGroupName' `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($logGroups -and $logGroups.Count -gt 0) {
        foreach ($logGroupName in $logGroups) {
            try {
                Write-Info "Log Groupを削除中: $logGroupName"
                aws logs delete-log-group `
                    --log-group-name $logGroupName `
                    --region $AWSRegion 2>&1 | Out-Null
                
                Write-Success "削除完了: $logGroupName"
                $deletedResources += "CloudWatch Log Group: $logGroupName"
            } catch {
                Write-Error-Custom "削除失敗: $logGroupName"
                $failedResources += "CloudWatch Log Group: $logGroupName"
            }
        }
    } else {
        Write-Info "CloudWatch Log Groupsが見つかりません"
    }
} catch {
    Write-Warn "CloudWatch Log Groupsの一覧取得に失敗しました"
}

# 10. ローカルファイルのクリーンアップ
Write-Host ""
Write-Info "ローカルファイルのクリーンアップ..."

$localFiles = @(
    ".env",
    "node_modules",
    "dist",
    "build",
    "*.zip"
)

foreach ($file in $localFiles) {
    if (Test-Path $file) {
        try {
            if ((Get-Item $file).PSIsContainer) {
                Remove-Item $file -Recurse -Force
                Write-Success "フォルダ削除: $file"
            } else {
                Remove-Item $file -Force
                Write-Success "ファイル削除: $file"
            }
        } catch {
            Write-Error-Custom "削除失敗: $file"
        }
    }
}

# ローカルストレージのクリア（ブラウザ）
Write-Info "ブラウザのローカルストレージをクリアしてください:"
Write-Info "1. ブラウザで http://localhost:5173 を開く"
Write-Info "2. F12でデベロッパーツールを開く"
Write-Info "3. Application/Storage → Local Storage → Clear"

# 結果サマリー
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "           クリーンアップ完了サマリー" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

if ($deletedResources.Count -gt 0) {
    Write-Host ""
    Write-Host "削除されたリソース:" -ForegroundColor Green
    foreach ($resource in $deletedResources) {
        Write-Host "  ? $resource" -ForegroundColor Green
    }
}

if ($failedResources.Count -gt 0) {
    Write-Host ""
    Write-Host "削除に失敗したリソース:" -ForegroundColor Red
    foreach ($resource in $failedResources) {
        Write-Host "  ? $resource" -ForegroundColor Red
    }
    Write-Host ""
    Write-Warn "一部のリソースの削除に失敗しました。"
    Write-Warn "AWS コンソールで手動削除が必要な場合があります。"
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan

# 課金確認のアドバイス
Write-Host ""
Write-Info "? 重要な確認事項:"
Write-Info "1. AWS Cost Explorerで課金状況を確認してください"
Write-Info "2. 数時間後にもう一度AWSコンソールでリソースを確認してください"
Write-Info "3. 請求書を定期的に確認してください"

Write-Host ""
Write-Success "クリーンアップ処理が完了しました！"

# 再構築の案内
Write-Host ""
Write-Info "プロジェクトを再構築する場合:"
Write-Info "1. git clean -fdx でローカルを完全クリーン"
Write-Info "2. .\scripts\install-dependencies.ps1 で依存関係インストール"
Write-Info "3. .\scripts\setup.ps1 でAWS環境構築"
Write-Info "4. .\scripts\deploy-lambda.ps1 でLambda関数デプロイ"

Write-Host ""