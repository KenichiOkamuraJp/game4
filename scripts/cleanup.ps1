#Requires -Version 5.1
# AWS Dungeon RPG Complete Cleanup Script - Improved Version
# ���̃X�N���v�g�̓v���W�F�N�g�Ɋ֘A���邷�ׂĂ�AWS���\�[�X���폜���܂�

[CmdletBinding()]
param(
    [string]$ProjectName = "dungeon-rpg",
    [string]$AWSRegion = "ap-northeast-1",
    [switch]$SkipConfirmation = $false,
    [switch]$Force = $false,
    [switch]$DryRun = $false
)

# �G���R�[�f�B���O�ݒ�
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

$ErrorActionPreference = "Continue"

Write-Host "================================================" -ForegroundColor Red
Write-Host "    AWS Dungeon RPG �N���[���A�b�v�X�N���v�g" -ForegroundColor Red
Write-Host "================================================" -ForegroundColor Red
Write-Host ""

# ���O�֐�
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
            Write-Error-Custom "$Description ���s: $ResourceName"
            return $false
        }
    } catch {
        Write-Error-Custom "$Description �G���[: $ResourceName - $($_.Exception.Message)"
        return $false
    }
}

# AWS CLI�m�F
try {
    $awsVersion = aws --version 2>$null
    if (-not $awsVersion) {
        throw "AWS CLI not found"
    }
    Write-Info "AWS CLI found: $($awsVersion.Split()[0])"
} catch {
    Write-Error-Custom "AWS CLI���C���X�g�[������Ă��܂���"
    exit 1
}

# AWS�F�؊m�F
try {
    $callerIdentity = aws sts get-caller-identity --output json 2>$null | ConvertFrom-Json
    if (-not $callerIdentity) {
        throw "Authentication failed"
    }
    Write-Info "AWS Account: $($callerIdentity.Account)"
    Write-Info "User/Role: $($callerIdentity.Arn)"
} catch {
    Write-Error-Custom "AWS�F�؂Ɏ��s���܂���"
    Write-Info "aws configure �����s���Ă�������"
    exit 1
}

Write-Host ""
if ($DryRun) {
    Write-Warn "==================== DRY RUN ���[�h ===================="
    Write-Warn "���ۂ̍폜�͍s���܂���B�폜�Ώۂ̂ݕ\�����܂��B"
} else {
    Write-Warn "==================== �x�� ===================="
    Write-Warn "���̃X�N���v�g�͈ȉ��̃��\�[�X���폜���܂�:"
}

Write-Warn "- CloudFormation�X�^�b�N: $ProjectName-*"
Write-Warn "- ���ׂĂ�Lambda�֐� (�v���t�B�b�N�X: $ProjectName-)"
Write-Warn "- DynamoDB�e�[�u��"
Write-Warn "- API Gateway"
Write-Warn "- Cognito User Pool & Identity Pool"
Write-Warn "- IAM���[���E�|���V�["
Write-Warn "- S3�o�P�b�g (���������)"
Write-Warn "- CloudWatch Logs"
Write-Warn "- CloudWatch Alarms"
Write-Warn "- Lambda ���C���["
Write-Warn "=============================================="
Write-Host ""

if (-not $SkipConfirmation -and -not $DryRun) {
    Write-Host "�{���ɍ폜���܂����H �S�f�[�^�������܂��I" -ForegroundColor Red
    $confirmation = Read-Host "�폜�����s����ɂ� 'DELETE' �Ɠ��͂��Ă�������"
    
    if ($confirmation -ne "DELETE") {
        Write-Info "�N���[���A�b�v���L�����Z������܂����B"
        exit 0
    }
}

Write-Host ""
Write-Info "�N���[���A�b�v���J�n���܂�..."
Write-Host ""

$deletedResources = @()
$failedResources = @()

# 1. CloudFormation�X�^�b�N�폜
Write-Info "CloudFormation�X�^�b�N�폜���m�F��..."

try {
    $stacks = aws cloudformation list-stacks `
        --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE `
        --query "StackSummaries[?contains(StackName, '$ProjectName')].{Name:StackName,Status:StackStatus}" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($stacks -and $stacks.Count -gt 0) {
        foreach ($stack in $stacks) {
            $success = Invoke-SafeCommand `
                -Description "CloudFormation�X�^�b�N�폜" `
                -ResourceName $stack.Name `
                -Command {
                    aws cloudformation delete-stack `
                        --stack-name $stack.Name `
                        --region $AWSRegion 2>&1 | Out-Null
                    return $true
                }
            
            if ($success) {
                $deletedResources += "CloudFormation�X�^�b�N: $($stack.Name)"
                
                if (-not $DryRun) {
                    Write-Info "�X�^�b�N�폜�ҋ@��... (�ő�10��)"
                    aws cloudformation wait stack-delete-complete `
                        --stack-name $stack.Name `
                        --region $AWSRegion 2>&1 | Out-Null
                }
            } else {
                $failedResources += "CloudFormation�X�^�b�N: $($stack.Name)"
            }
        }
    } else {
        Write-Info "CloudFormation�X�^�b�N��������܂���"
    }
} catch {
    Write-Info "CloudFormation�X�^�b�N�̊m�F���X�L�b�v"
}

# 2. Lambda�֐��폜
Write-Info "Lambda�֐��폜���m�F��..."

try {
    $lambdaFunctions = aws lambda list-functions `
        --query "Functions[?starts_with(FunctionName, '$ProjectName-')].FunctionName" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($lambdaFunctions -and $lambdaFunctions.Count -gt 0) {
        foreach ($functionName in $lambdaFunctions) {
            $success = Invoke-SafeCommand `
                -Description "Lambda�֐��폜" `
                -ResourceName $functionName `
                -Command {
                    aws lambda delete-function `
                        --function-name $functionName `
                        --region $AWSRegion 2>&1 | Out-Null
                    return $true
                }
            
            if ($success) {
                $deletedResources += "Lambda�֐�: $functionName"
            } else {
                $failedResources += "Lambda�֐�: $functionName"
            }
        }
    } else {
        Write-Info "Lambda�֐���������܂���"
    }
} catch {
    Write-Warn "Lambda�֐��̊m�F�Ɏ��s���܂���"
}

# 3. Lambda ���C���[�폜
Write-Info "Lambda ���C���[�폜���m�F��..."

try {
    $layers = aws lambda list-layers `
        --query "Layers[?contains(LayerName, '$ProjectName')].LayerName" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($layers -and $layers.Count -gt 0) {
        foreach ($layerName in $layers) {
            # ���C���[�̂��ׂẴo�[�W�������擾
            $versions = aws lambda list-layer-versions `
                --layer-name $layerName `
                --query 'LayerVersions[].Version' `
                --region $AWSRegion `
                --output json | ConvertFrom-Json
            
            foreach ($version in $versions) {
                $layerVersionName = "${layerName}:${version}"
                $success = Invoke-SafeCommand `
                    -Description "Lambda ���C���[�폜" `
                    -ResourceName $layerVersionName `
                    -Command {
                        aws lambda delete-layer-version `
                            --layer-name $layerName `
                            --version-number $version `
                            --region $AWSRegion 2>&1 | Out-Null
                        return $true
                    }
                
                if ($success) {
                    $deletedResources += "Lambda ���C���[: $layerVersionName"
                } else {
                    $failedResources += "Lambda ���C���[: $layerVersionName"
                }
            }
        }
    } else {
        Write-Info "Lambda ���C���[��������܂���"
    }
} catch {
    Write-Warn "Lambda ���C���[�̊m�F�Ɏ��s���܂���"
}

# 4. DynamoDB�e�[�u���폜
Write-Info "DynamoDB�e�[�u���폜���m�F��..."

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
                -Description "DynamoDB�e�[�u���폜" `
                -ResourceName $tableName `
                -Command {
                    aws dynamodb delete-table `
                        --table-name $tableName `
                        --region $AWSRegion 2>&1 | Out-Null
                    return $true
                }
            
            if ($success) {
                $deletedResources += "DynamoDB�e�[�u��: $tableName"
            } else {
                $failedResources += "DynamoDB�e�[�u��: $tableName"
            }
        }
    } catch {
        Write-Info "�e�[�u����������܂���: $tableName"
    }
}

# 5. API Gateway�폜
Write-Info "API Gateway�폜���m�F��..."

try {
    $apis = aws apigateway get-rest-apis `
        --query "items[?contains(name, '$ProjectName')].{id:id,name:name}" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($apis -and $apis.Count -gt 0) {
        foreach ($api in $apis) {
            $apiDisplayName = "$($api.name) (ID: $($api.id))"
            $success = Invoke-SafeCommand `
                -Description "API Gateway�폜" `
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
        Write-Info "API Gateway��������܂���"
    }
} catch {
    Write-Warn "API Gateway�̊m�F�Ɏ��s���܂���"
}

# 6. Cognito User Pool�폜
Write-Info "Cognito User Pool�폜���m�F��..."

try {
    $userPools = aws cognito-idp list-user-pools `
        --max-results 60 `
        --query "UserPools[?contains(Name, '$ProjectName')].{Id:Id,Name:Name}" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($userPools -and $userPools.Count -gt 0) {
        foreach ($pool in $userPools) {
            # User Pool Client�폜
            try {
                $clients = aws cognito-idp list-user-pool-clients `
                    --user-pool-id $pool.Id `
                    --query 'UserPoolClients[].ClientId' `
                    --region $AWSRegion `
                    --output json | ConvertFrom-Json
                
                foreach ($clientId in $clients) {
                    Invoke-SafeCommand `
                        -Description "User Pool Client�폜" `
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
                Write-Warn "User Pool Client�폜���X�L�b�v: $($pool.Name)"
            }
            
            # User Pool Domain�폜
            try {
                $domain = aws cognito-idp describe-user-pool `
                    --user-pool-id $pool.Id `
                    --query 'UserPool.CustomDomain' `
                    --region $AWSRegion `
                    --output text 2>$null
                
                if ($domain -and $domain -ne "None" -and $domain -ne "") {
                    Invoke-SafeCommand `
                        -Description "Cognito�h���C���폜" `
                        -ResourceName $domain `
                        -Command {
                            aws cognito-idp delete-user-pool-domain `
                                --domain $domain `
                                --region $AWSRegion 2>&1 | Out-Null
                            return $true
                        } | Out-Null
                }
            } catch {
                Write-Warn "User Pool Domain�폜���X�L�b�v"
            }
            
            # User Pool�폜
            $poolDisplayName = "$($pool.Name) (ID: $($pool.Id))"
            $success = Invoke-SafeCommand `
                -Description "User Pool�폜" `
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
        Write-Info "Cognito User Pool��������܂���"
    }
} catch {
    Write-Warn "Cognito User Pool�̊m�F�Ɏ��s���܂���"
}

# 7. Cognito Identity Pool�폜
Write-Info "Cognito Identity Pool�폜���m�F��..."

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
                -Description "Identity Pool�폜" `
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
        Write-Info "Cognito Identity Pool��������܂���"
    }
} catch {
    Write-Warn "Cognito Identity Pool�̊m�F�Ɏ��s���܂���"
}

# 8. IAM���[���E�|���V�[�폜
Write-Info "IAM���\�[�X�폜���m�F��..."

# IAM���[���폜
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
            # �A�^�b�`���ꂽ�|���V�[���f�^�b�`
            $attachedPolicies = aws iam list-attached-role-policies `
                --role-name $roleName `
                --query 'AttachedPolicies[].PolicyArn' `
                --output json | ConvertFrom-Json
            
            foreach ($policyArn in $attachedPolicies) {
                $policyDisplayName = "$policyArn from $roleName"
                Invoke-SafeCommand `
                    -Description "�|���V�[�f�^�b�`" `
                    -ResourceName $policyDisplayName `
                    -Command {
                        aws iam detach-role-policy `
                            --role-name $roleName `
                            --policy-arn $policyArn 2>&1 | Out-Null
                        return $true
                    } | Out-Null
            }
            
            # �C�����C���|���V�[�폜
            $inlinePolicies = aws iam list-role-policies `
                --role-name $roleName `
                --query 'PolicyNames' `
                --output json | ConvertFrom-Json
            
            foreach ($policyName in $inlinePolicies) {
                $inlinePolicyDisplayName = "$policyName from $roleName"
                Invoke-SafeCommand `
                    -Description "�C�����C���|���V�[�폜" `
                    -ResourceName $inlinePolicyDisplayName `
                    -Command {
                        aws iam delete-role-policy `
                            --role-name $roleName `
                            --policy-name $policyName 2>&1 | Out-Null
                        return $true
                    } | Out-Null
            }
            
            # ���[���폜
            $success = Invoke-SafeCommand `
                -Description "IAM���[���폜" `
                -ResourceName $roleName `
                -Command {
                    aws iam delete-role `
                        --role-name $roleName 2>&1 | Out-Null
                    return $true
                }
            
            if ($success) {
                $deletedResources += "IAM���[��: $roleName"
            } else {
                $failedResources += "IAM���[��: $roleName"
            }
        }
    } catch {
        Write-Info "IAM���[����������܂���: $roleName"
    }
}

# �J�X�^���}�l�[�W�h�|���V�[�폜
try {
    $customPolicies = aws iam list-policies `
        --scope Local `
        --query "Policies[?contains(PolicyName, '$ProjectName')].{Arn:Arn,Name:PolicyName}" `
        --output json | ConvertFrom-Json
    
    foreach ($policy in $customPolicies) {
        # �|���V�[�̂��ׂẴo�[�W�������폜
        $versions = aws iam list-policy-versions `
            --policy-arn $policy.Arn `
            --query 'Versions[?!IsDefaultVersion].VersionId' `
            --output json | ConvertFrom-Json
        
        foreach ($version in $versions) {
            $policyVersionName = "${policyName}:${version}"
            Invoke-SafeCommand `
                -Description "�|���V�[�o�[�W�����폜" `
                -ResourceName $policyVersionName `
                -Command {
                    aws iam delete-policy-version `
                        --policy-arn $policy.Arn `
                        --version-id $version 2>&1 | Out-Null
                    return $true
                } | Out-Null
        }
        
        $success = Invoke-SafeCommand `
            -Description "�J�X�^���|���V�[�폜" `
            -ResourceName $policy.Name `
            -Command {
                aws iam delete-policy `
                    --policy-arn $policy.Arn 2>&1 | Out-Null
                return $true
            }
        
        if ($success) {
            $deletedResources += "IAM�|���V�[: $($policy.Name)"
        } else {
            $failedResources += "IAM�|���V�[: $($policy.Name)"
        }
    }
} catch {
    Write-Warn "�J�X�^���|���V�[�̊m�F�Ɏ��s���܂���"
}

# 9. S3�o�P�b�g�폜
Write-Info "S3�o�P�b�g�폜���m�F��..."

try {
    $buckets = aws s3api list-buckets `
        --query "Buckets[?contains(Name, '$ProjectName')].Name" `
        --output json | ConvertFrom-Json
    
    if ($buckets -and $buckets.Count -gt 0) {
        foreach ($bucketName in $buckets) {
            $success = Invoke-SafeCommand `
                -Description "S3�o�P�b�g�폜" `
                -ResourceName $bucketName `
                -Command {
                    # �o�P�b�g���e���폜
                    aws s3 rm "s3://$bucketName" --recursive 2>&1 | Out-Null
                    # �o�P�b�g�폜
                    aws s3api delete-bucket `
                        --bucket $bucketName `
                        --region $AWSRegion 2>&1 | Out-Null
                    return $true
                }
            
            if ($success) {
                $deletedResources += "S3�o�P�b�g: $bucketName"
            } else {
                $failedResources += "S3�o�P�b�g: $bucketName"
            }
        }
    } else {
        Write-Info "S3�o�P�b�g��������܂���"
    }
} catch {
    Write-Warn "S3�o�P�b�g�̊m�F�Ɏ��s���܂���"
}

# 10. CloudWatch Log Groups�폜
Write-Info "CloudWatch Log Groups�폜���m�F��..."

try {
    $logGroups = aws logs describe-log-groups `
        --log-group-name-prefix "/aws/lambda/$ProjectName" `
        --query 'logGroups[].logGroupName' `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($logGroups -and $logGroups.Count -gt 0) {
        foreach ($logGroupName in $logGroups) {
            $success = Invoke-SafeCommand `
                -Description "Log Group�폜" `
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
        Write-Info "CloudWatch Log Groups��������܂���"
    }
} catch {
    Write-Warn "CloudWatch Log Groups�̊m�F�Ɏ��s���܂���"
}

# 11. CloudWatch Alarms�폜
Write-Info "CloudWatch Alarms�폜���m�F��..."

try {
    $alarms = aws cloudwatch describe-alarms `
        --query "MetricAlarms[?contains(AlarmName, '$ProjectName')].AlarmName" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($alarms -and $alarms.Count -gt 0) {
        foreach ($alarmName in $alarms) {
            $success = Invoke-SafeCommand `
                -Description "CloudWatch Alarm�폜" `
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
        Write-Info "CloudWatch Alarms��������܂���"
    }
} catch {
    Write-Warn "CloudWatch Alarms�̊m�F�Ɏ��s���܂���"
}

# 12. ���[�J���t�@�C���N���[���A�b�v
if (-not $DryRun) {
    Write-Host ""
    Write-Info "���[�J���t�@�C���N���[���A�b�v..."
    
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
                    Write-Success "�t�H���_�폜: $file"
                } else {
                    Remove-Item $file -Force
                    Write-Success "�t�@�C���폜: $file"
                }
            } catch {
                Write-Error-Custom "�폜���s: $file"
            }
        }
    }
}

# ���ʃT�}���[
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "           �N���[���A�b�v���ʃT�}���[" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

if ($deletedResources.Count -gt 0) {
    Write-Host ""
    Write-Host "�폜���ꂽ���\�[�X:" -ForegroundColor Green
    foreach ($resource in $deletedResources) {
        Write-Host "  ? $resource" -ForegroundColor Green
    }
}

if ($failedResources.Count -gt 0) {
    Write-Host ""
    Write-Host "�폜�Ɏ��s�������\�[�X:" -ForegroundColor Red
    foreach ($resource in $failedResources) {
        Write-Host "  ? $resource" -ForegroundColor Red
    }
    Write-Host ""
    Write-Warn "�ꕔ�̃��\�[�X�̍폜�Ɏ��s���܂����B"
    Write-Warn "AWS �R���\�[���Ŏ蓮�폜���K�v�ȏꍇ������܂��B"
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan

if (-not $DryRun) {
    # �ŏI�m�F�ƃA�h�o�C�X
    Write-Host ""
    Write-Info "? �d�v�Ȋm�F����:"
    Write-Info "1. AWS Cost Explorer�ŉۋ��󋵂��m�F���Ă�������"
    Write-Info "2. �폜�R�ꂪ�Ȃ���AWS�R���\�[���Ń��\�[�X���m�F���Ă�������"
    Write-Info "3. �����A���[�g�̐ݒ���m�F���Ă�������"
    
    Write-Host ""
    Write-Success "�N���[���A�b�v���������܂����I"
    
    # �č\�z�菇
    Write-Host ""
    Write-Info "�v���W�F�N�g���č\�z����ꍇ:"
    Write-Info "1. git clean -fdx �Ń��[�J���������S�N���A"
    Write-Info "2. .\scripts\install-dependencies.ps1 �ňˑ��֌W�ăC���X�g�[��"
    Write-Info "3. .\scripts\setup.ps1 ��AWS���\�z"
    Write-Info "4. .\scripts\deploy-lambda.ps1 ��Lambda�֐��f�v���C"
} else {
    Write-Host ""
    Write-Info "DRY RUN���� - ���ۂ̍폜�͍s���܂���ł���"
    Write-Info "���ۂɃN���[���A�b�v�����s����ɂ� -DryRun ���O���Ă�������"
}

Write-Host ""