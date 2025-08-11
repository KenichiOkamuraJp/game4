#Requires -Version 5.1
# AWS Dungeon RPG Complete Cleanup Script
# ���̃X�N���v�g�̓v���W�F�N�g�Ɋ֘A����S�Ă�AWS���\�[�X���폜���܂�

[CmdletBinding()]
param(
    [string]$ProjectName = "dungeon-rpg",
    [string]$AWSRegion = "ap-northeast-1",
    [switch]$SkipConfirmation = $false,
    [switch]$Force = $false
)

# �G���R�[�f�B���O�ݒ�
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

$ErrorActionPreference = "Continue"  # �G���[���������Ă����s

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
    Write-Error-Custom "AWS�F�؏�񂪐ݒ肳��Ă��܂���"
    Write-Info "aws configure �Őݒ肵�Ă�������"
    exit 1
}

Write-Host ""
Write-Warn "==================== �x�� ===================="
Write-Warn "���̃X�N���v�g�͈ȉ��̃��\�[�X���폜���܂�:"
Write-Warn "- CloudFormation�X�^�b�N: $ProjectName-stack"
Write-Warn "- ���ׂĂ�Lambda�֐� (�v���t�B�b�N�X: $ProjectName-)"
Write-Warn "- DynamoDB�e�[�u��"
Write-Warn "- API Gateway"
Write-Warn "- Cognito User Pool & Identity Pool"
Write-Warn "- IAM���[���ƃ|���V�["
Write-Warn "- S3�o�P�b�g�i���݂���ꍇ�j"
Write-Warn "=============================================="
Write-Host ""

if (-not $SkipConfirmation) {
    Write-Host "�{���ɍ폜���܂����H ���̑���͎������܂���I" -ForegroundColor Red
    $confirmation = Read-Host "�폜�����s����ꍇ�� 'DELETE' �Ɠ��͂��Ă�������"
    
    if ($confirmation -ne "DELETE") {
        Write-Info "�N���[���A�b�v���L�����Z�����܂���"
        exit 0
    }
}

Write-Host ""
Write-Info "�N���[���A�b�v���J�n���܂�..."
Write-Host ""

$deletedResources = @()
$failedResources = @()

# 1. CloudFormation�X�^�b�N�̍폜
Write-Info "CloudFormation�X�^�b�N���m�F��..."
$stackName = "$ProjectName-stack"

try {
    $stack = aws cloudformation describe-stacks `
        --stack-name $stackName `
        --region $AWSRegion `
        --output json 2>$null | ConvertFrom-Json
    
    if ($stack) {
        Write-Info "CloudFormation�X�^�b�N '$stackName' ���폜��..."
        
        # �X�^�b�N�폜���J�n
        aws cloudformation delete-stack `
            --stack-name $stackName `
            --region $AWSRegion 2>&1 | Out-Null
        
        Write-Info "�X�^�b�N�폜��ҋ@��... (����ɂ͐���������ꍇ������܂�)"
        
        # �폜������ҋ@�i�^�C���A�E�g10���j
        $timeout = 600
        $elapsed = 0
        $checkInterval = 10
        
        while ($elapsed -lt $timeout) {
            Start-Sleep -Seconds $checkInterval
            $elapsed += $checkInterval
            
            # �X�^�b�N�̏�Ԃ��m�F
            $stackStatus = aws cloudformation describe-stacks `
                --stack-name $stackName `
                --region $AWSRegion `
                --query 'Stacks[0].StackStatus' `
                --output text 2>$null
            
            if (-not $stackStatus) {
                Write-Success "CloudFormation�X�^�b�N���폜����܂���"
                $deletedResources += "CloudFormation�X�^�b�N: $stackName"
                break
            }
            
            Write-Info "�X�^�b�N�X�e�[�^�X: $stackStatus (�o�ߎ���: ${elapsed}�b)"
        }
        
        if ($elapsed -ge $timeout) {
            Write-Warn "�X�^�b�N�폜���^�C���A�E�g���܂����BAWS �R���\�[���Ŋm�F���Ă��������B"
            $failedResources += "CloudFormation�X�^�b�N: $stackName (�^�C���A�E�g)"
        }
    } else {
        Write-Info "CloudFormation�X�^�b�N��������܂���"
    }
} catch {
    Write-Info "CloudFormation�X�^�b�N�����݂��܂���"
}

# 2. �c������Lambda�֐��̍폜
Write-Info "Lambda�֐����m�F��..."

try {
    $lambdaFunctions = aws lambda list-functions `
        --query "Functions[?starts_with(FunctionName, '$ProjectName-')].FunctionName" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($lambdaFunctions -and $lambdaFunctions.Count -gt 0) {
        Write-Info "$($lambdaFunctions.Count)��Lambda�֐���������܂���"
        
        foreach ($functionName in $lambdaFunctions) {
            try {
                Write-Info "Lambda�֐����폜��: $functionName"
                aws lambda delete-function `
                    --function-name $functionName `
                    --region $AWSRegion 2>&1 | Out-Null
                
                Write-Success "�폜����: $functionName"
                $deletedResources += "Lambda�֐�: $functionName"
            } catch {
                Write-Error-Custom "�폜���s: $functionName"
                $failedResources += "Lambda�֐�: $functionName"
            }
        }
    } else {
        Write-Info "Lambda�֐���������܂���"
    }
} catch {
    Write-Warn "Lambda�֐��̈ꗗ�擾�Ɏ��s���܂���"
}

# 3. DynamoDB�e�[�u���̍폜
Write-Info "DynamoDB�e�[�u�����m�F��..."

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
            Write-Info "DynamoDB�e�[�u�����폜��: $tableName"
            aws dynamodb delete-table `
                --table-name $tableName `
                --region $AWSRegion 2>&1 | Out-Null
            
            Write-Success "�폜����: $tableName"
            $deletedResources += "DynamoDB�e�[�u��: $tableName"
        }
    } catch {
        Write-Info "�e�[�u�������݂��܂���: $tableName"
    }
}

# 4. API Gateway�̍폜
Write-Info "API Gateway���m�F��..."

try {
    $apis = aws apigateway get-rest-apis `
        --query "items[?contains(name, '$ProjectName')].{id:id,name:name}" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($apis -and $apis.Count -gt 0) {
        foreach ($api in $apis) {
            try {
                Write-Info "API Gateway���폜��: $($api.name) (ID: $($api.id))"
                aws apigateway delete-rest-api `
                    --rest-api-id $api.id `
                    --region $AWSRegion 2>&1 | Out-Null
                
                Write-Success "�폜����: $($api.name)"
                $deletedResources += "API Gateway: $($api.name)"
            } catch {
                Write-Error-Custom "�폜���s: $($api.name)"
                $failedResources += "API Gateway: $($api.name)"
            }
        }
    } else {
        Write-Info "API Gateway��������܂���"
    }
} catch {
    Write-Warn "API Gateway�̈ꗗ�擾�Ɏ��s���܂���"
}

# 5. Cognito User Pool�̍폜
Write-Info "Cognito User Pool���m�F��..."

try {
    $userPools = aws cognito-idp list-user-pools `
        --max-results 60 `
        --query "UserPools[?contains(Name, '$ProjectName')].{Id:Id,Name:Name}" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($userPools -and $userPools.Count -gt 0) {
        foreach ($pool in $userPools) {
            try {
                # User Pool���̃h���C�����ɍ폜
                $domains = aws cognito-idp describe-user-pool `
                    --user-pool-id $pool.Id `
                    --query 'UserPool.Domain' `
                    --region $AWSRegion `
                    --output text 2>$null
                
                if ($domains -and $domains -ne "None") {
                    Write-Info "Cognito�h���C�����폜��: $domains"
                    aws cognito-idp delete-user-pool-domain `
                        --domain $domains `
                        --region $AWSRegion 2>&1 | Out-Null
                }
                
                Write-Info "User Pool���폜��: $($pool.Name)"
                aws cognito-idp delete-user-pool `
                    --user-pool-id $pool.Id `
                    --region $AWSRegion 2>&1 | Out-Null
                
                Write-Success "�폜����: $($pool.Name)"
                $deletedResources += "Cognito User Pool: $($pool.Name)"
            } catch {
                Write-Error-Custom "�폜���s: $($pool.Name)"
                $failedResources += "Cognito User Pool: $($pool.Name)"
            }
        }
    } else {
        Write-Info "Cognito User Pool��������܂���"
    }
} catch {
    Write-Warn "Cognito User Pool�̈ꗗ�擾�Ɏ��s���܂���"
}

# 6. Cognito Identity Pool�̍폜
Write-Info "Cognito Identity Pool���m�F��..."

try {
    $identityPools = aws cognito-identity list-identity-pools `
        --max-results 60 `
        --query "IdentityPools[?contains(IdentityPoolName, '$ProjectName')].{Id:IdentityPoolId,Name:IdentityPoolName}" `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($identityPools -and $identityPools.Count -gt 0) {
        foreach ($pool in $identityPools) {
            try {
                Write-Info "Identity Pool���폜��: $($pool.Name)"
                aws cognito-identity delete-identity-pool `
                    --identity-pool-id $pool.Id `
                    --region $AWSRegion 2>&1 | Out-Null
                
                Write-Success "�폜����: $($pool.Name)"
                $deletedResources += "Cognito Identity Pool: $($pool.Name)"
            } catch {
                Write-Error-Custom "�폜���s: $($pool.Name)"
                $failedResources += "Cognito Identity Pool: $($pool.Name)"
            }
        }
    } else {
        Write-Info "Cognito Identity Pool��������܂���"
    }
} catch {
    Write-Warn "Cognito Identity Pool�̈ꗗ�擾�Ɏ��s���܂���"
}

# 7. IAM���[���̍폜
Write-Info "IAM���[�����m�F��..."

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
            # ���[���ɃA�^�b�`���ꂽ�|���V�[���폜
            $attachedPolicies = aws iam list-attached-role-policies `
                --role-name $roleName `
                --query 'AttachedPolicies[].PolicyArn' `
                --output json | ConvertFrom-Json
            
            foreach ($policyArn in $attachedPolicies) {
                Write-Info "�|���V�[���f�^�b�`��: $policyArn"
                aws iam detach-role-policy `
                    --role-name $roleName `
                    --policy-arn $policyArn 2>&1 | Out-Null
            }
            
            # �C�����C���|���V�[���폜
            $inlinePolicies = aws iam list-role-policies `
                --role-name $roleName `
                --query 'PolicyNames' `
                --output json | ConvertFrom-Json
            
            foreach ($policyName in $inlinePolicies) {
                Write-Info "�C�����C���|���V�[���폜��: $policyName"
                aws iam delete-role-policy `
                    --role-name $roleName `
                    --policy-name $policyName 2>&1 | Out-Null
            }
            
            Write-Info "IAM���[�����폜��: $roleName"
            aws iam delete-role `
                --role-name $roleName 2>&1 | Out-Null
            
            Write-Success "�폜����: $roleName"
            $deletedResources += "IAM���[��: $roleName"
        }
    } catch {
        Write-Info "IAM���[�������݂��܂���: $roleName"
    }
}

# 8. S3�o�P�b�g�̍폜�i�������݂���΁j
Write-Info "S3�o�P�b�g���m�F��..."

try {
    $buckets = aws s3api list-buckets `
        --query "Buckets[?contains(Name, '$ProjectName')].Name" `
        --output json | ConvertFrom-Json
    
    if ($buckets -and $buckets.Count -gt 0) {
        foreach ($bucketName in $buckets) {
            try {
                Write-Info "S3�o�P�b�g����ɂ��Ă��܂�: $bucketName"
                aws s3 rm "s3://$bucketName" --recursive 2>&1 | Out-Null
                
                Write-Info "S3�o�P�b�g���폜��: $bucketName"
                aws s3api delete-bucket `
                    --bucket $bucketName `
                    --region $AWSRegion 2>&1 | Out-Null
                
                Write-Success "�폜����: $bucketName"
                $deletedResources += "S3�o�P�b�g: $bucketName"
            } catch {
                Write-Error-Custom "�폜���s: $bucketName"
                $failedResources += "S3�o�P�b�g: $bucketName"
            }
        }
    } else {
        Write-Info "S3�o�P�b�g��������܂���"
    }
} catch {
    Write-Warn "S3�o�P�b�g�̈ꗗ�擾�Ɏ��s���܂���"
}

# 9. CloudWatch Log Groups�̍폜
Write-Info "CloudWatch Log Groups���m�F��..."

try {
    $logGroups = aws logs describe-log-groups `
        --log-group-name-prefix "/aws/lambda/$ProjectName" `
        --query 'logGroups[].logGroupName' `
        --region $AWSRegion `
        --output json | ConvertFrom-Json
    
    if ($logGroups -and $logGroups.Count -gt 0) {
        foreach ($logGroupName in $logGroups) {
            try {
                Write-Info "Log Group���폜��: $logGroupName"
                aws logs delete-log-group `
                    --log-group-name $logGroupName `
                    --region $AWSRegion 2>&1 | Out-Null
                
                Write-Success "�폜����: $logGroupName"
                $deletedResources += "CloudWatch Log Group: $logGroupName"
            } catch {
                Write-Error-Custom "�폜���s: $logGroupName"
                $failedResources += "CloudWatch Log Group: $logGroupName"
            }
        }
    } else {
        Write-Info "CloudWatch Log Groups��������܂���"
    }
} catch {
    Write-Warn "CloudWatch Log Groups�̈ꗗ�擾�Ɏ��s���܂���"
}

# 10. ���[�J���t�@�C���̃N���[���A�b�v
Write-Host ""
Write-Info "���[�J���t�@�C���̃N���[���A�b�v..."

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

# ���[�J���X�g���[�W�̃N���A�i�u���E�U�j
Write-Info "�u���E�U�̃��[�J���X�g���[�W���N���A���Ă�������:"
Write-Info "1. �u���E�U�� http://localhost:5173 ���J��"
Write-Info "2. F12�Ńf�x���b�p�[�c�[�����J��"
Write-Info "3. Application/Storage �� Local Storage �� Clear"

# ���ʃT�}���[
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "           �N���[���A�b�v�����T�}���[" -ForegroundColor Cyan
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

# �ۋ��m�F�̃A�h�o�C�X
Write-Host ""
Write-Info "? �d�v�Ȋm�F����:"
Write-Info "1. AWS Cost Explorer�ŉۋ��󋵂��m�F���Ă�������"
Write-Info "2. �����Ԍ�ɂ�����xAWS�R���\�[���Ń��\�[�X���m�F���Ă�������"
Write-Info "3. �����������I�Ɋm�F���Ă�������"

Write-Host ""
Write-Success "�N���[���A�b�v�������������܂����I"

# �č\�z�̈ē�
Write-Host ""
Write-Info "�v���W�F�N�g���č\�z����ꍇ:"
Write-Info "1. git clean -fdx �Ń��[�J�������S�N���[��"
Write-Info "2. .\scripts\install-dependencies.ps1 �ňˑ��֌W�C���X�g�[��"
Write-Info "3. .\scripts\setup.ps1 ��AWS���\�z"
Write-Info "4. .\scripts\deploy-lambda.ps1 ��Lambda�֐��f�v���C"

Write-Host ""