#Requires -Version 5.1
# Vue.js Dungeon RPG AWS Setup Script (PowerShell) - English Version
# This script sets up AWS environment

[CmdletBinding()]
param(
    [string]$ProjectName = "dungeon-rpg",
    [string]$AWSRegion = "ap-northeast-1",
    [string]$AdminEmail = "kenichi.okamura.jp@gmail.com"
)

# Encoding setup
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# Error handling
$ErrorActionPreference = "Stop"

# Remove Pester module conflicts
if (Get-Module -Name Pester -ListAvailable) {
    Remove-Module -Name Pester -Force -ErrorAction SilentlyContinue
}

Write-Host "Vue.js Dungeon RPG AWS Setup Started" -ForegroundColor Yellow
Write-Host "====================================" -ForegroundColor Yellow

# Logging functions
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

# Check AWS CLI
try {
    $awsVersion = aws --version 2>$null
    if (-not $awsVersion) {
        throw "AWS CLI not found"
    }
    Write-Info "AWS CLI found: $($awsVersion.Split()[0])"
} catch {
    Write-Error-Custom "AWS CLI not installed"
    Write-Info "Download from: https://awscli.amazonaws.com/AWSCLIV2.msi"
    exit 1
}

# Check AWS credentials
try {
    $callerIdentity = aws sts get-caller-identity --output json 2>$null | ConvertFrom-Json
    if (-not $callerIdentity) {
        throw "Authentication failed"
    }
    Write-Info "AWS credentials verified: $($callerIdentity.Arn)"
} catch {
    Write-Error-Custom "AWS credentials not configured"
    Write-Info "Configure with: aws configure"
    exit 1
}

# Parameter input
if (-not $ProjectName) {
    $ProjectName = Read-Host "Enter project name (default: dungeon-rpg)"
    if (-not $ProjectName) { $ProjectName = "dungeon-rpg" }
}

if (-not $AWSRegion) {
    $AWSRegion = Read-Host "Enter AWS region (default: ap-northeast-1)"
    if (-not $AWSRegion) { $AWSRegion = "ap-northeast-1" }
}

if (-not $AdminEmail) {
    do {
        $AdminEmail = Read-Host "Enter administrator email address"
    } while (-not $AdminEmail)
}

$StackName = "$ProjectName-stack"

Write-Info "Configuration:"
Write-Info "  Project Name: $ProjectName"
Write-Info "  Region: $AWSRegion"
Write-Info "  Admin Email: $AdminEmail"
Write-Info "  Stack Name: $StackName"

$confirm = Read-Host "Start setup with this configuration? (y/N)"
if ($confirm -notmatch "^[Yy]$") {
    Write-Info "Setup canceled"
    exit 0
}

# Check existing stack
Write-Info "Checking existing stack..."
try {
    $existingStack = aws cloudformation describe-stacks --stack-name $StackName --region $AWSRegion --output json 2>$null | ConvertFrom-Json
    if ($existingStack -and $existingStack.Stacks) {
        $stackStatus = $existingStack.Stacks[0].StackStatus
        Write-Warn "Existing stack found (Status: $stackStatus)"
        
        if ($stackStatus -eq "ROLLBACK_COMPLETE" -or $stackStatus -eq "CREATE_FAILED" -or $stackStatus -eq "DELETE_FAILED") {
            Write-Info "Deleting failed stack..."
            aws cloudformation delete-stack --stack-name $StackName --region $AWSRegion
            Write-Info "Waiting for stack deletion completion..."
            aws cloudformation wait stack-delete-complete --stack-name $StackName --region $AWSRegion
            Write-Info "Existing stack deleted"
        } else {
            Write-Error-Custom "Active stack exists. Please delete manually."
            exit 1
        }
    }
} catch {
    Write-Info "No existing stack found"
}

# Deploy CloudFormation stack
Write-Info "Deploying CloudFormation stack..."
try {
    $deployResult = aws cloudformation deploy `
        --template-file "scripts/cloudformation.yaml" `
        --stack-name $StackName `
        --parameter-overrides ProjectName=$ProjectName AdminEmail=$AdminEmail `
        --capabilities CAPABILITY_NAMED_IAM `
        --region $AWSRegion `
        --no-fail-on-empty-changeset 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "CloudFormation deployment failed: $deployResult"
        Write-Info "Check details with:"
        Write-Info "aws cloudformation describe-stack-events --stack-name $StackName --region $AWSRegion"
        exit 1
    }
    Write-Info "CloudFormation stack deployment completed"
} catch {
    Write-Error-Custom "CloudFormation stack deployment failed: $_"
    Write-Info "Check details with:"
    Write-Info "aws cloudformation describe-stack-events --stack-name $StackName --region $AWSRegion"
    exit 1
}

# Get stack outputs
Write-Info "Retrieving stack outputs..."
try {
    $outputs = aws cloudformation describe-stacks `
        --stack-name $StackName `
        --region $AWSRegion `
        --query 'Stacks[0].Outputs' `
        --output json | ConvertFrom-Json

    $UserPoolId = ($outputs | Where-Object { $_.OutputKey -eq "UserPoolId" }).OutputValue
    $UserPoolClientId = ($outputs | Where-Object { $_.OutputKey -eq "UserPoolClientId" }).OutputValue
    $IdentityPoolId = ($outputs | Where-Object { $_.OutputKey -eq "IdentityPoolId" }).OutputValue
    $ApiEndpoint = ($outputs | Where-Object { $_.OutputKey -eq "ApiEndpoint" }).OutputValue

    Write-Info "Stack outputs retrieved"
} catch {
    Write-Error-Custom "Failed to retrieve stack outputs: $_"
    exit 1
}

# Generate .env file
Write-Info "Generating .env file..."
try {
    $envContent = @"
# AWS Cognito Configuration
VITE_AWS_USER_POOL_ID=$UserPoolId
VITE_AWS_USER_POOL_CLIENT_ID=$UserPoolClientId
VITE_AWS_IDENTITY_POOL_ID=$IdentityPoolId

# AWS API Gateway Configuration
VITE_AWS_API_ENDPOINT=$ApiEndpoint
VITE_AWS_REGION=$AWSRegion
"@

    # Write file with UTF-8 encoding (no BOM)
    [System.IO.File]::WriteAllText(".env", $envContent, [System.Text.Encoding]::UTF8)
    Write-Info ".env file generated"
} catch {
    Write-Error-Custom "Failed to generate .env file: $_"
    exit 1
}

Write-Info "Setup completed successfully!" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Yellow
Write-Info "Configuration Details:"
Write-Info "  User Pool ID: $UserPoolId"
Write-Info "  User Pool Client ID: $UserPoolClientId"
Write-Info "  Identity Pool ID: $IdentityPoolId"
Write-Info "  API Endpoint: $ApiEndpoint"
Write-Host ""
Write-Info "Next Steps:"
Write-Info "1. npm install - Install packages"
Write-Info "2. .\scripts\deploy-lambda.ps1 - Deploy Python Lambda functions"
Write-Info "3. npm run dev - Start application"
Write-Info "4. Open browser to http://localhost:5173"
Write-Host ""
Write-Warn "Note: Email verification required for first user registration"