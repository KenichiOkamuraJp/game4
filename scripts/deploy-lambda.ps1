#Requires -Version 5.1
# Python Lambda Functions Deployment Script - English Version
# This script deploys Python Lambda function implementations

[CmdletBinding()]
param(
    [string]$ProjectName = "dungeon-rpg",
    [string]$AWSRegion = "ap-northeast-1"
)

# Encoding setup
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Deploy-PythonLambdaFunction {
    param(
        [string]$FunctionName,
        [string]$SourcePath,
        [string]$HandlerFile = "create.py"
    )
    
    Write-Info "Deploying Python Lambda function: $FunctionName"
    
    # Check source directory
    if (!(Test-Path $SourcePath)) {
        Write-Error-Custom "Source directory not found: $SourcePath"
        return $false
    }
    
    # Check Python file exists
    $pythonFile = Join-Path $SourcePath $HandlerFile
    if (!(Test-Path $pythonFile)) {
        Write-Error-Custom "Python file not found: $pythonFile"
        return $false
    }
    
    # Create temporary working directory
    $tempDir = Join-Path $env:TEMP "lambda-deploy-$FunctionName"
    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    
    try {
        # Copy files
                # Copy only specific handler file and requirements.txt
        $handlerPath = Join-Path $SourcePath $HandlerFile
        $requirementsPath = Join-Path $SourcePath "requirements.txt"
        
        if (Test-Path $handlerPath) {
            Copy-Item $handlerPath $tempDir
        }
        if (Test-Path $requirementsPath) {
            Copy-Item $requirementsPath $tempDir
        }
        
        # Check/create requirements.txt
        $requirementsPath = Join-Path $tempDir "requirements.txt"
        if (!(Test-Path $requirementsPath)) {
            Write-Info "Creating requirements.txt..."
            "boto3==1.34.0" | Out-File -FilePath $requirementsPath -Encoding UTF8
        }
        
        # Install dependencies
        Push-Location $tempDir
        try {
            Write-Info "Running pip install..."
            
            # Check Python
            if (!(Test-Command "python")) {
                Write-Error-Custom "Python not installed"
                return $false
            }
            
            # Install dependencies to current directory
            $pipResult = python -m pip install -r requirements.txt -t . --upgrade  2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Error-Custom "pip install failed: $pipResult"
                return $false
            }
            
            # Clean up unnecessary files
            $cleanupPatterns = @("*.dist-info", "__pycache__", "*.pyc", "pip", "pip-*", "setuptools*", "wheel*")
            foreach ($pattern in $cleanupPatterns) {
                $items = Get-ChildItem -Path "." -Name $pattern -Recurse 2>$null
                if ($items) {
                    $items | ForEach-Object { 
                        $fullPath = Join-Path "." $_
                        if (Test-Path $fullPath) {
                            Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
            }
            
            # Create ZIP file
            $zipPath = "${FunctionName}.zip"
            if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
            
            Write-Info "Creating ZIP file..."
            
            # Compress all files (including hidden files)
            $filesToZip = Get-ChildItem -Path "." -Force | Where-Object { $_.Name -ne $zipPath }
            if ($filesToZip) {
                Compress-Archive -Path $filesToZip.FullName -DestinationPath $zipPath -CompressionLevel Optimal
            } else {
                Write-Error-Custom "No files to compress found"
                return $false
            }
            
            # Check ZIP file size
            $zipSize = (Get-Item $zipPath).Length / 1MB
            Write-Info "ZIP file size: $([math]::Round($zipSize, 2)) MB"
            
            if ($zipSize -gt 50) {
                Write-Error-Custom "ZIP file exceeds 50MB. Check Lambda function limits."
                return $false
            }
            
            # Update Lambda function
            Write-Info "Updating Lambda function code..."
            $updateResult = aws lambda update-function-code `
                --function-name "$ProjectName-$FunctionName" `
                --zip-file "fileb://$zipPath" `
                --region $AWSRegion 2>&1
                
            if ($LASTEXITCODE -ne 0) {
                Write-Error-Custom "Lambda function update failed: $updateResult"
                return $false
            }
            
            # Wait for update completion
            Write-Info "Waiting for function update completion..."
            $waitResult = aws lambda wait function-updated `
                --function-name "$ProjectName-$FunctionName" `
                --region $AWSRegion 2>&1
                
            if ($LASTEXITCODE -eq 0) {
                Write-Info "Lambda function updated successfully: $FunctionName"
                return $true
            } else {
                Write-Error-Custom "Function update wait timed out: $waitResult"
                return $false
            }
            
        } finally {
            Pop-Location
        }
        
    } finally {
        # Clean up temporary directory
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Main processing
Write-Info "Starting Python Lambda function deployment..."

# Check Python
if (!(Test-Command "python")) {
    Write-Error-Custom "Python not installed"
    Write-Info "Install with:"
    Write-Info "1. https://www.python.org/downloads/"
    Write-Info "2. winget install Python.Python.3.11"
    exit 1
}

$pythonVersion = python --version 2>&1
Write-Info "Python version: $pythonVersion"

# Check AWS CLI
if (!(Test-Command "aws")) {
    Write-Error-Custom "AWS CLI not installed"
    exit 1
}

# Check project root directory
if (!(Test-Path "lambda")) {
    Write-Error-Custom "lambda directory not found. Run from project root."
    exit 1
}

# Deploy Characters functions
Write-Info "Deploying Characters functions..."
$charactersSuccess = @()
$charactersSuccess += Deploy-PythonLambdaFunction -FunctionName "characters-create" -SourcePath "lambda/characters" -HandlerFile "create.py"
$charactersSuccess += Deploy-PythonLambdaFunction -FunctionName "characters-list" -SourcePath "lambda/characters" -HandlerFile "list.py"
$charactersSuccess += Deploy-PythonLambdaFunction -FunctionName "characters-update" -SourcePath "lambda/characters" -HandlerFile "update.py"
$charactersSuccess += Deploy-PythonLambdaFunction -FunctionName "characters-delete" -SourcePath "lambda/characters" -HandlerFile "delete.py"

# Deploy Saves functions
Write-Info "Deploying Saves functions..."
$savesSuccess = @()
$savesSuccess += Deploy-PythonLambdaFunction -FunctionName "saves-create" -SourcePath "lambda/saves" -HandlerFile "create.py"
$savesSuccess += Deploy-PythonLambdaFunction -FunctionName "saves-get" -SourcePath "lambda/saves" -HandlerFile "get.py"
$savesSuccess += Deploy-PythonLambdaFunction -FunctionName "saves-update" -SourcePath "lambda/saves" -HandlerFile "update.py"
$savesSuccess += Deploy-PythonLambdaFunction -FunctionName "saves-delete" -SourcePath "lambda/saves" -HandlerFile "delete.py"

# Check results
$allSuccess = ($charactersSuccess + $savesSuccess) -notcontains $false

if ($allSuccess) {
    Write-Info "All Python Lambda functions deployed successfully!" -ForegroundColor Green
    
    # Display function list
    Write-Info "Deployed functions:"
    aws lambda list-functions `
        --query "Functions[?starts_with(FunctionName, '$ProjectName')].{Name:FunctionName,Runtime:Runtime,LastModified:LastModified}" `
        --output table `
        --region $AWSRegion
        
    Write-Info ""
    Write-Info "Next steps:"
    Write-Info "1. Start frontend: npm run dev"
    Write-Info "2. Open browser to http://localhost:5173"
    Write-Info "3. Register/login and start the game"
} else {
    Write-Error-Custom "Some Lambda function deployments failed."
    Write-Info "Check error logs and Lambda function logs:"
    Write-Info "aws logs describe-log-groups --log-group-name-prefix /aws/lambda/$ProjectName --region $AWSRegion"
    exit 1
}
