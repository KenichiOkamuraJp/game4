#Requires -Version 5.1
# AWS Dungeon RPG Complete Cleanup Script - Improved Version
# このスクリプトはプロジェクトに関連するすべてのAWSリソースを削除します

[CmdletBinding()]
param(
    [string]$ProjectName = "dungeon-rpg",
    [string]$AWSRegion = "ap-northeast-1",
    [switch]$SkipConfirmation = $false,
    [switch]$Force = $false,
    [switch]$DryRun = $false
)

# エンコーディング設定
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

$ErrorActionPreference = "Continue"

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

function Write-DryRun {
    param([string]$Message)
    Write-Host "[DRY-RUN] $Message" -ForegroundColor Magenta
}

function Invoke-SafeCommand {
    param(
        [string]$Description,
        [scriptblock]$Command,
        [string]$ResourceName = ""
    )
    
    if ($DryRun) {
        Write-DryRun "$Description : $ResourceName"
        return $true
    }
    
    try {
        $result = & $Command
        if ($LASTEXITCODE -eq 0 -or $result) {
            Write-Success "$Description : $ResourceName"
            return $true
        } else {
            Write-Error-Custom "$Description 失敗: $ResourceName"
            return $false
        }
    } catch {
        Write-Error-Custom "$Description エラー: $ResourceName - $($_.Exception.Message)"
        return $false
    }
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
    Write-Error-Custom "AWS認証に失敗しました"
    Write-Info "aws configure を実行してください"
    exit 1
}

Write-Host ""
if ($DryRun) {
    Write-Warn "==================== DRY RUN モード ===================="
    Write-Warn "実際の削除は行われません。削除対象のみ表示します。"
} else {
    Write-Warn "==================== 警告 ===================="
    Write-Warn "このスクリプトは以下のリソースを削除します:"
}

Write-Warn "- CloudFormationスタック: $ProjectName-*"
Write-Warn "- すべてのLambda関数 (プレフィックス: $ProjectName-)"
Write-Warn "- DynamoDBテーブル"
Write-Warn "- API Gateway"
Write-Warn "- Cognito User Pool & Identity Pool"
Write-Warn "- IAMロール・ポリシー"
Write-Warn "- S3バケット (もしあれば)"
Write-Warn "- CloudWatch Logs"
Write-Warn "- CloudWatch Alarms"
Write-Warn "- Lambda レイヤー"
Write-Warn "=============================================="
Write-Host ""

if (-not $SkipConfirmation -and -not $DryRun) {
    Write-Host "本当に削除しますか？ 全データが失われます！" -ForegroundColor Red
    $confirmation = Read-Host "削除を実行するには 'DELETE' と入力してください"
    
    if ($confirmation -ne "DELETE") {
        Write-Info "クリーンアップがキャンセルされました。"
        exit 0
    }
}

Write-Host ""
Write-Info "クリーンアップを開始します..."
Write-Host ""

$deletedResources = @()
$failedResources = @()

# 1. CloudFormationスタック削除
Write-Info "CloudFormationスタック削除を確認中..."

try {
    $stacks = aws cloudformation list-stacks `
        --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE `
        --query "StackSummaries[?contains(StackName, '$ProjectName')].{Name:StackName,Status:StackStatus}" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($stacks -and $stacks.Count -gt 0) {
        foreach ($stack in $stacks) {
            $success = Invoke-SafeCommand `
                -Description "CloudFormationスタック削除" `
                -ResourceName $stack.Name `
                -Command {
                    aws cloudformation delete-stack `
                        --stack-name $stack.Name `
                        --region $AWSRegion 2>&1 | Out-Null
                    return $true
                }
            
            if ($success) {
                $deletedResources += "CloudFormationスタック: $($stack.Name)"
                
                if (-not $DryRun) {
                    Write-Info "スタック削除待機中... (最大10分)"
                    aws cloudformation wait stack-delete-complete `
                        --stack-name $stack.Name `
                        --region $AWSRegion 2>&1 | Out-Null
                }
            } else {
                $failedResources += "CloudFormationスタック: $($stack.Name)"
            }
        }
    } else {
        Write-Info "CloudFormationスタックが見つかりません"
    }
} catch {
    Write-Info "CloudFormationスタックの確認をスキップ"
}

# 2. Lambda関数削除
Write-Info "Lambda関数削除を確認中..."

try {
    $lambdaFunctions = aws lambda list-functions `
        --query "Functions[?starts_with(FunctionName, '$ProjectName-')].FunctionName" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($lambdaFunctions -and $lambdaFunctions.Count -gt 0) {
        foreach ($functionName in $lambdaFunctions) {
            $success = Invoke-SafeCommand `
                -Description "Lambda関数削除" `
                -ResourceName $functionName `
                -Command {
                    aws lambda delete-function `
                        --function-name $functionName `
                        --region $AWSRegion 2>&1 | Out-Null
                    return $true
                }
            
            if ($success) {
                $deletedResources += "Lambda関数: $functionName"
            } else {
                $failedResources += "Lambda関数: $functionName"
            }
        }
    } else {
        Write-Info "Lambda関数が見つかりません"
    }
} catch {
    Write-Warn "Lambda関数の確認に失敗しました"
}

# 3. Lambda レイヤー削除
Write-Info "Lambda レイヤー削除を確認中..."

try {
    $layers = aws lambda list-layers `
        --query "Layers[?contains(LayerName, '$ProjectName')].LayerName" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($layers -and $layers.Count -gt 0) {
        foreach ($layerName in $layers) {
            # レイヤーのすべてのバージョンを取得
            $versions = aws lambda list-layer-versions `
                --layer-name $layerName `
                --query 'LayerVersions[].Version' `
                --region $AWSRegion `
                --output json | ConvertFrom-Json
            
            foreach ($version in $versions) {
                $layerVersionName = "${layerName}:${version}"
                $success = Invoke-SafeCommand `
                    -Description "Lambda レイヤー削除" `
                    -ResourceName $layerVersionName `
                    -Command {
                        aws lambda delete-layer-version `
                            --layer-name $layerName `
                            --version-number $version `
                            --region $AWSRegion 2>&1 | Out-Null
                        return $true
                    }
                
                if ($success) {
                    $deletedResources += "Lambda レイヤー: $layerVersionName"
                } else {
                    $failedResources += "Lambda レイヤー: $layerVersionName"
                }
            }
        }
    } else {
        Write-Info "Lambda レイヤーが見つかりません"
    }
} catch {
    Write-Warn "Lambda レイヤーの確認に失敗しました"
}

# 4. DynamoDBテーブル削除
Write-Info "DynamoDBテーブル削除を確認中..."

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
            $success = Invoke-SafeCommand `
                -Description "DynamoDBテーブル削除" `
                -ResourceName $tableName `
                -Command {
                    aws dynamodb delete-table `
                        --table-name $tableName `
                        --region $AWSRegion 2>&1 | Out-Null
                    return $true
                }
            
            if ($success) {
                $deletedResources += "DynamoDBテーブル: $tableName"
            } else {
                $failedResources += "DynamoDBテーブル: $tableName"
            }
        }
    } catch {
        Write-Info "テーブルが見つかりません: $tableName"
    }
}

# 5. API Gateway削除
Write-Info "API Gateway削除を確認中..."

try {
    $apis = aws apigateway get-rest-apis `
        --query "items[?contains(name, '$ProjectName')].{id:id,name:name}" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($apis -and $apis.Count -gt 0) {
        foreach ($api in $apis) {
            $apiDisplayName = "$($api.name) (ID: $($api.id))"
            $success = Invoke-SafeCommand `
                -Description "API Gateway削除" `
                -ResourceName $apiDisplayName `
                -Command {
                    aws apigateway delete-rest-api `
                        --rest-api-id $api.id `
                        --region $AWSRegion 2>&1 | Out-Null
                    return $true
                }
            
            if ($success) {
                $deletedResources += "API Gateway: $($api.name)"
            } else {
                $failedResources += "API Gateway: $($api.name)"
            }
        }
    } else {
        Write-Info "API Gatewayが見つかりません"
    }
} catch {
    Write-Warn "API Gatewayの確認に失敗しました"
}

# 6. Cognito User Pool削除
Write-Info "Cognito User Pool削除を確認中..."

try {
    $userPools = aws cognito-idp list-user-pools `
        --max-results 60 `
        --query "UserPools[?contains(Name, '$ProjectName')].{Id:Id,Name:Name}" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($userPools -and $userPools.Count -gt 0) {
        foreach ($pool in $userPools) {
            # User Pool Client削除
            try {
                $clients = aws cognito-idp list-user-pool-clients `
                    --user-pool-id $pool.Id `
                    --query 'UserPoolClients[].ClientId' `
                    --region $AWSRegion `
                    --output json | ConvertFrom-Json
                
                foreach ($clientId in $clients) {
                    Invoke-SafeCommand `
                        -Description "User Pool Client削除" `
                        -ResourceName $clientId `
                        -Command {
                            aws cognito-idp delete-user-pool-client `
                                --user-pool-id $pool.Id `
                                --client-id $clientId `
                                --region $AWSRegion 2>&1 | Out-Null
                            return $true
                        } | Out-Null
                }
            } catch {
                Write-Warn "User Pool Client削除をスキップ: $($pool.Name)"
            }
            
            # User Pool Domain削除
            try {
                $domain = aws cognito-idp describe-user-pool `
                    --user-pool-id $pool.Id `
                    --query 'UserPool.CustomDomain' `
                    --region $AWSRegion `
                    --output text 2>$null
                
                if ($domain -and $domain -ne "None" -and $domain -ne "") {
                    Invoke-SafeCommand `
                        -Description "Cognitoドメイン削除" `
                        -ResourceName $domain `
                        -Command {
                            aws cognito-idp delete-user-pool-domain `
                                --domain $domain `
                                --region $AWSRegion 2>&1 | Out-Null
                            return $true
                        } | Out-Null
                }
            } catch {
                Write-Warn "User Pool Domain削除をスキップ"
            }
            
            # User Pool削除
            $poolDisplayName = "$($pool.Name) (ID: $($pool.Id))"
            $success = Invoke-SafeCommand `
                -Description "User Pool削除" `
                -ResourceName $poolDisplayName `
                -Command {
                    aws cognito-idp delete-user-pool `
                        --user-pool-id $pool.Id `
                        --region $AWSRegion 2>&1 | Out-Null
                    return $true
                }
            
            if ($success) {
                $deletedResources += "Cognito User Pool: $($pool.Name)"
            } else {
                $failedResources += "Cognito User Pool: $($pool.Name)"
            }
        }
    } else {
        Write-Info "Cognito User Poolが見つかりません"
    }
} catch {
    Write-Warn "Cognito User Poolの確認に失敗しました"
}

# 7. Cognito Identity Pool削除
Write-Info "Cognito Identity Pool削除を確認中..."

try {
    $identityPools = aws cognito-identity list-identity-pools `
        --max-results 60 `
        --query "IdentityPools[?contains(IdentityPoolName, '$ProjectName')].{Id:IdentityPoolId,Name:IdentityPoolName}" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($identityPools -and $identityPools.Count -gt 0) {
        foreach ($pool in $identityPools) {
            $poolDisplayName = "$($pool.Name) (ID: $($pool.Id))"
            $success = Invoke-SafeCommand `
                -Description "Identity Pool削除" `
                -ResourceName $poolDisplayName `
                -Command {
                    aws cognito-identity delete-identity-pool `
                        --identity-pool-id $pool.Id `
                        --region $AWSRegion 2>&1 | Out-Null
                    return $true
                }
            
            if ($success) {
                $deletedResources += "Cognito Identity Pool: $($pool.Name)"
            } else {
                $failedResources += "Cognito Identity Pool: $($pool.Name)"
            }
        }
    } else {
        Write-Info "Cognito Identity Poolが見つかりません"
    }
} catch {
    Write-Warn "Cognito Identity Poolの確認に失敗しました"
}

# 8. IAMロール・ポリシー削除
Write-Info "IAMリソース削除を確認中..."

# IAMロール削除
$roleNames = @(
    "$ProjectName-lambda-execution-role",
    "$ProjectName-cognito-auth-role", 
    "$ProjectName-cognito-unauth-role"
)

foreach ($roleName in $roleNames) {
    try {
        $role = aws iam get-role `
            --role-name $roleName `
            --output json 2>$null | ConvertFrom-Json
        
        if ($role) {
            # アタッチされたポリシーをデタッチ
            $attachedPolicies = aws iam list-attached-role-policies `
                --role-name $roleName `
                --query 'AttachedPolicies[].PolicyArn' `
                --output json | ConvertFrom-Json
            
            foreach ($policyArn in $attachedPolicies) {
                $policyDisplayName = "$policyArn from $roleName"
                Invoke-SafeCommand `
                    -Description "ポリシーデタッチ" `
                    -ResourceName $policyDisplayName `
                    -Command {
                        aws iam detach-role-policy `
                            --role-name $roleName `
                            --policy-arn $policyArn 2>&1 | Out-Null
                        return $true
                    } | Out-Null
            }
            
            # インラインポリシー削除
            $inlinePolicies = aws iam list-role-policies `
                --role-name $roleName `
                --query 'PolicyNames' `
                --output json | ConvertFrom-Json
            
            foreach ($policyName in $inlinePolicies) {
                $inlinePolicyDisplayName = "$policyName from $roleName"
                Invoke-SafeCommand `
                    -Description "インラインポリシー削除" `
                    -ResourceName $inlinePolicyDisplayName `
                    -Command {
                        aws iam delete-role-policy `
                            --role-name $roleName `
                            --policy-name $policyName 2>&1 | Out-Null
                        return $true
                    } | Out-Null
            }
            
            # ロール削除
            $success = Invoke-SafeCommand `
                -Description "IAMロール削除" `
                -ResourceName $roleName `
                -Command {
                    aws iam delete-role `
                        --role-name $roleName 2>&1 | Out-Null
                    return $true
                }
            
            if ($success) {
                $deletedResources += "IAMロール: $roleName"
            } else {
                $failedResources += "IAMロール: $roleName"
            }
        }
    } catch {
        Write-Info "IAMロールが見つかりません: $roleName"
    }
}

# カスタムマネージドポリシー削除
try {
    $customPolicies = aws iam list-policies `
        --scope Local `
        --query "Policies[?contains(PolicyName, '$ProjectName')].{Arn:Arn,Name:PolicyName}" `
        --output json | ConvertFrom-Json
    
    foreach ($policy in $customPolicies) {
        # ポリシーのすべてのバージョンを削除
        $versions = aws iam list-policy-versions `
            --policy-arn $policy.Arn `
            --query 'Versions[?!IsDefaultVersion].VersionId' `
            --output json | ConvertFrom-Json
        
        foreach ($version in $versions) {
            $policyVersionName = "${policyName}:${version}"
            Invoke-SafeCommand `
                -Description "ポリシーバージョン削除" `
                -ResourceName $policyVersionName `
                -Command {
                    aws iam delete-policy-version `
                        --policy-arn $policy.Arn `
                        --version-id $version 2>&1 | Out-Null
                    return $true
                } | Out-Null
        }
        
        $success = Invoke-SafeCommand `
            -Description "カスタムポリシー削除" `
            -ResourceName $policy.Name `
            -Command {
                aws iam delete-policy `
                    --policy-arn $policy.Arn 2>&1 | Out-Null
                return $true
            }
        
        if ($success) {
            $deletedResources += "IAMポリシー: $($policy.Name)"
        } else {
            $failedResources += "IAMポリシー: $($policy.Name)"
        }
    }
} catch {
    Write-Warn "カスタムポリシーの確認に失敗しました"
}

# 9. S3バケット削除
Write-Info "S3バケット削除を確認中..."

try {
    $buckets = aws s3api list-buckets `
        --query "Buckets[?contains(Name, '$ProjectName')].Name" `
        --output json | ConvertFrom-Json
    
    if ($buckets -and $buckets.Count -gt 0) {
        foreach ($bucketName in $buckets) {
            $success = Invoke-SafeCommand `
                -Description "S3バケット削除" `
                -ResourceName $bucketName `
                -Command {
                    # バケット内容を削除
                    aws s3 rm "s3://$bucketName" --recursive 2>&1 | Out-Null
                    # バケット削除
                    aws s3api delete-bucket `
                        --bucket $bucketName `
                        --region $AWSRegion 2>&1 | Out-Null
                    return $true
                }
            
            if ($success) {
                $deletedResources += "S3バケット: $bucketName"
            } else {
                $failedResources += "S3バケット: $bucketName"
            }
        }
    } else {
        Write-Info "S3バケットが見つかりません"
    }
} catch {
    Write-Warn "S3バケットの確認に失敗しました"
}

# 10. CloudWatch Log Groups削除
Write-Info "CloudWatch Log Groups削除を確認中..."

try {
    $logGroups = aws logs describe-log-groups `
        --log-group-name-prefix "/aws/lambda/$ProjectName" `
        --query 'logGroups[].logGroupName' `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($logGroups -and $logGroups.Count -gt 0) {
        foreach ($logGroupName in $logGroups) {
            $success = Invoke-SafeCommand `
                -Description "Log Group削除" `
                -ResourceName $logGroupName `
                -Command {
                    aws logs delete-log-group `
                        --log-group-name $logGroupName `
                        --region $AWSRegion 2>&1 | Out-Null
                    return $true
                }
            
            if ($success) {
                $deletedResources += "CloudWatch Log Group: $logGroupName"
            } else {
                $failedResources += "CloudWatch Log Group: $logGroupName"
            }
        }
    } else {
        Write-Info "CloudWatch Log Groupsが見つかりません"
    }
} catch {
    Write-Warn "CloudWatch Log Groupsの確認に失敗しました"
}

# 11. CloudWatch Alarms削除
Write-Info "CloudWatch Alarms削除を確認中..."

try {
    $alarms = aws cloudwatch describe-alarms `
        --query "MetricAlarms[?contains(AlarmName, '$ProjectName')].AlarmName" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($alarms -and $alarms.Count -gt 0) {
        foreach ($alarmName in $alarms) {
            $success = Invoke-SafeCommand `
                -Description "CloudWatch Alarm削除" `
                -ResourceName $alarmName `
                -Command {
                    aws cloudwatch delete-alarms `
                        --alarm-names $alarmName `
                        --region $AWSRegion 2>&1 | Out-Null
                    return $true
                }
            
            if ($success) {
                $deletedResources += "CloudWatch Alarm: $alarmName"
            } else {
                $failedResources += "CloudWatch Alarm: $alarmName"
            }
        }
    } else {
        Write-Info "CloudWatch Alarmsが見つかりません"
    }
} catch {
    Write-Warn "CloudWatch Alarmsの確認に失敗しました"
}

# 12. ローカルファイルクリーンアップ
if (-not $DryRun) {
    Write-Host ""
    Write-Info "ローカルファイルクリーンアップ..."
    
    $localFiles = @(
        ".env",
        "node_modules",
        "dist", 
        "build",
        "*.zip",
        "tests/lambda-events"
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
}

# 結果サマリー
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "           クリーンアップ結果サマリー" -ForegroundColor Cyan
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

if (-not $DryRun) {
    # 最終確認とアドバイス
    Write-Host ""
    Write-Info "? 重要な確認事項:"
    Write-Info "1. AWS Cost Explorerで課金状況を確認してください"
    Write-Info "2. 削除漏れがないかAWSコンソールでリソースを確認してください"
    Write-Info "3. 請求アラートの設定を確認してください"
    
    Write-Host ""
    Write-Success "クリーンアップが完了しました！"
    
    # 再構築手順
    Write-Host ""
    Write-Info "プロジェクトを再構築する場合:"
    Write-Info "1. git clean -fdx でローカル環境を完全クリア"
    Write-Info "2. .\scripts\install-dependencies.ps1 で依存関係再インストール"
    Write-Info "3. .\scripts\setup.ps1 でAWS環境構築"
    Write-Info "4. .\scripts\deploy-lambda.ps1 でLambda関数デプロイ"
} else {
    Write-Host ""
    Write-Info "DRY RUN完了 - 実際の削除は行われませんでした"
    Write-Info "実際にクリーンアップを実行するには -DryRun を外してください"
}

Write-Host ""