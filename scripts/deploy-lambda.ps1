#Requires -Version 5.1
# Enhanced Python Lambda Functions Deployment Script with Test Events
# This script deploys Python Lambda function implementations and creates test events

[CmdletBinding()]
param(
    [string]$ProjectName = "dungeon-rpg",
    [string]$AWSRegion = "ap-northeast-1",
    [string]$UserPoolId = "",
    [string]$ClientId = "",
    [switch]$CreateTestEvents = $true,
    [switch]$RunTests = $false
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

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
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

function Get-StackOutputs {
    param([string]$StackName)
    
    try {
        $outputs = aws cloudformation describe-stacks `
            --stack-name $StackName `
            --query "Stacks[0].Outputs" `
            --output json `
            --region $AWSRegion 2>$null
            
        if ($LASTEXITCODE -eq 0) {
            return $outputs | ConvertFrom-Json
        }
    } catch {
        Write-Warning-Custom "Could not retrieve stack outputs for $StackName"
    }
    return $null
}

function Create-TestEventFiles {
    param(
        [string]$OutputDir,
        [string]$UserPoolId,
        [string]$ClientId
    )
    
    Write-Info "Creating test event files..."
    
    if (!(Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    
    # Test user data
    $testUserId = "test-user-12345678-1234-1234-1234-123456789012"
    $testEmail = "test@example.com"
    
    # Base event template
    $baseEvent = @{
        resource = "/characters"
        path = "/characters"
        httpMethod = "GET"
        headers = @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer test-jwt-token"
        }
        multiValueHeaders = @{}
        queryStringParameters = $null
        multiValueQueryStringParameters = $null
        pathParameters = $null
        stageVariables = $null
        requestContext = @{
            resourceId = "test123"
            resourcePath = "/characters"
            httpMethod = "GET"
            extendedRequestId = "test-request-id"
            requestTime = "11/Aug/2025:12:00:00 +0000"
            path = "/prod/characters"
            accountId = "123456789012"
            protocol = "HTTP/1.1"
            stage = "prod"
            domainPrefix = "api"
            requestTimeEpoch = 1723377600000
            requestId = "test-request-id-123"
            identity = @{
                sourceIp = "127.0.0.1"
                userAgent = "TestAgent/1.0"
            }
            domainName = "api.example.com"
            apiId = "testapi123"
            authorizer = @{
                claims = @{
                    sub = $testUserId
                    email = $testEmail
                    email_verified = "true"
                    aud = $ClientId
                    "cognito:username" = $testUserId
                    token_use = "id"
                    auth_time = "1723377000"
                    exp = "1723380600"
                    iat = "1723377000"
                }
            }
        }
        body = $null
        isBase64Encoded = $false
    }
    
    # Characters test events
    $charactersEvents = @{
        "characters-list-auth" = @{
            description = "Get characters list with authentication"
            event = $baseEvent.Clone()
        }
        "characters-list-no-auth" = @{
            description = "Get characters list without authentication (should fail)"
            event = @{
                resource = "/characters"
                path = "/characters"
                httpMethod = "GET"
                headers = @{}
                requestContext = @{
                    httpMethod = "GET"
                    resourcePath = "/characters"
                }
                body = $null
                isBase64Encoded = $false
            }
        }
        "characters-create" = @{
            description = "Create new character"
            event = ($baseEvent.Clone())
        }
        "characters-update" = @{
            description = "Update character"
            event = ($baseEvent.Clone())
        }
        "characters-delete" = @{
            description = "Delete character"
            event = ($baseEvent.Clone())
        }
        "cors-preflight" = @{
            description = "CORS preflight request"
            event = @{
                resource = "/characters"
                path = "/characters"
                httpMethod = "OPTIONS"
                headers = @{
                    "Origin" = "http://localhost:3000"
                    "Access-Control-Request-Method" = "GET"
                    "Access-Control-Request-Headers" = "authorization,content-type"
                }
                requestContext = @{
                    httpMethod = "OPTIONS"
                    resourcePath = "/characters"
                }
                body = $null
                isBase64Encoded = $false
            }
        }
    }
    
    # Modify events for different methods
    $charactersEvents["characters-create"].event.httpMethod = "POST"
    $charactersEvents["characters-create"].event.requestContext.httpMethod = "POST"
    $charactersEvents["characters-create"].event.body = '{"name":"Test Character","class":"warrior","level":1}'
    
    $charactersEvents["characters-update"].event.httpMethod = "PUT"
    $charactersEvents["characters-update"].event.requestContext.httpMethod = "PUT"
    $charactersEvents["characters-update"].event.pathParameters = @{ id = "char-123" }
    $charactersEvents["characters-update"].event.body = '{"name":"Updated Character","level":5}'
    
    $charactersEvents["characters-delete"].event.httpMethod = "DELETE"
    $charactersEvents["characters-delete"].event.requestContext.httpMethod = "DELETE"
    $charactersEvents["characters-delete"].event.pathParameters = @{ id = "char-123" }
    
    # Save test events with UTF-8 (no BOM)
    foreach ($eventName in $charactersEvents.Keys) {
        $eventData = $charactersEvents[$eventName]
        $filePath = Join-Path $OutputDir "$eventName.json"
        
        $eventJson = @{
            description = $eventData.description
            event = $eventData.event
        } | ConvertTo-Json -Depth 10
        
        # Write UTF-8 without BOM
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($filePath, $eventJson, $utf8NoBom)
        Write-Info "Created test event: $filePath"
    }
    
    # Create test runner script
    $testRunnerPath = Join-Path $OutputDir "run-tests.ps1"
    $testRunnerContent = @"
# Lambda Function Test Runner
# Generated automatically by deploy-lambda-enhanced.ps1

param(
    [string]`$FunctionName = "",
    [string]`$ProjectName = "$ProjectName",
    [string]`$AWSRegion = "$AWSRegion",
    [switch]`$AllFunctions = `$false
)

Write-Host "🧪 Lambda Function Test Runner" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green

`$testDir = Split-Path `$MyInvocation.MyCommand.Path
`$testFiles = Get-ChildItem -Path `$testDir -Filter "*.json"

if (`$AllFunctions) {
    Write-Host "Testing all functions..." -ForegroundColor Yellow
    
    `$functions = @("characters-list", "characters-create", "characters-update", "characters-delete")
    
    foreach (`$func in `$functions) {
        Write-Host "`nTesting function: `$ProjectName-`$func" -ForegroundColor Cyan
        
        # Find appropriate test file
        `$testFile = `$testFiles | Where-Object { `$_.BaseName -like "*`$func*" -or `$_.BaseName -eq "characters-list-auth" } | Select-Object -First 1
        
        if (`$testFile) {
            Write-Host "Using test file: `$(`$testFile.Name)" -ForegroundColor Gray
            
            `$result = aws lambda invoke ``
                --function-name "`$ProjectName-`$func" ``
                --payload "file://`$(`$testFile.FullName)" ``
                --output json ``
                --region `$AWSRegion ``
                "output-`$func.json" 2>&1
                
            if (`$LASTEXITCODE -eq 0) {
                Write-Host "✅ `$func: Success" -ForegroundColor Green
                if (Test-Path "output-`$func.json") {
                    `$output = Get-Content "output-`$func.json" | ConvertFrom-Json
                    Write-Host "   Status: `$(`$output.statusCode)" -ForegroundColor Gray
                }
            } else {
                Write-Host "❌ `$func: Failed" -ForegroundColor Red
                Write-Host "   Error: `$result" -ForegroundColor Red
            }
        } else {
            Write-Host "⚠️  No test file found for `$func" -ForegroundColor Yellow
        }
    }
} elseif (`$FunctionName) {
    Write-Host "Testing function: `$ProjectName-`$FunctionName" -ForegroundColor Cyan
    
    # Find test file
    `$testFile = `$testFiles | Where-Object { `$_.BaseName -like "*`$FunctionName*" } | Select-Object -First 1
    
    if (!`$testFile) {
        `$testFile = `$testFiles | Where-Object { `$_.BaseName -eq "characters-list-auth" } | Select-Object -First 1
    }
    
    if (`$testFile) {
        Write-Host "Using test file: `$(`$testFile.Name)" -ForegroundColor Gray
        
        `$result = aws lambda invoke ``
            --function-name "`$ProjectName-`$FunctionName" ``
            --payload "file://`$(`$testFile.FullName)" ``
            --output json ``
            --region `$AWSRegion ``
            "output-`$FunctionName.json" 2>&1
            
        if (`$LASTEXITCODE -eq 0) {
            Write-Host "✅ Test successful!" -ForegroundColor Green
            if (Test-Path "output-`$FunctionName.json") {
                `$output = Get-Content "output-`$FunctionName.json" | ConvertFrom-Json
                Write-Host "Response:" -ForegroundColor Yellow
                `$output | ConvertTo-Json -Depth 5 | Write-Host
            }
        } else {
            Write-Host "❌ Test failed!" -ForegroundColor Red
            Write-Host "Error: `$result" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ No test file found for function: `$FunctionName" -ForegroundColor Red
    }
} else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\run-tests.ps1 -FunctionName characters-list"
    Write-Host "  .\run-tests.ps1 -AllFunctions"
    Write-Host ""
    Write-Host "Available test files:" -ForegroundColor Yellow
    `$testFiles | ForEach-Object { Write-Host "  - `$(`$_.BaseName)" -ForegroundColor Gray }
}

Write-Host "`n🏁 Test run completed." -ForegroundColor Green
"@
    
    # Write UTF-8 without BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($testRunnerPath, $testRunnerContent, $utf8NoBom)
    Write-Info "Created test runner: $testRunnerPath"
    
    return $OutputDir
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
Write-Info "Starting Enhanced Python Lambda function deployment..."
Write-Info "Project: $ProjectName, Region: $AWSRegion"

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

# Try to get stack outputs if UserPoolId and ClientId are not provided
if ([string]::IsNullOrEmpty($UserPoolId) -or [string]::IsNullOrEmpty($ClientId)) {
    Write-Info "Attempting to retrieve Cognito information from CloudFormation stack..."
    $stackOutputs = Get-StackOutputs -StackName $ProjectName
    
    if ($stackOutputs) {
        foreach ($output in $stackOutputs) {
            switch ($output.OutputKey) {
                "UserPoolId" { 
                    if ([string]::IsNullOrEmpty($UserPoolId)) { 
                        $UserPoolId = $output.OutputValue 
                        Write-Info "Found UserPoolId: $UserPoolId"
                    }
                }
                "UserPoolClientId" { 
                    if ([string]::IsNullOrEmpty($ClientId)) { 
                        $ClientId = $output.OutputValue 
                        Write-Info "Found ClientId: $ClientId"
                    }
                }
            }
        }
    }
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

# Create test events
if ($CreateTestEvents) {
    Write-Info "Creating test events and test runner..."
    
    $testDir = "tests/lambda-events"
    $testEventsDir = Create-TestEventFiles -OutputDir $testDir -UserPoolId $UserPoolId -ClientId $ClientId
    
    Write-Info "Test events created in: $testEventsDir"
}

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
    
    if ($CreateTestEvents) {
        Write-Info ""
        Write-Info "🧪 Test Events & Runner Created:"
        Write-Info "Test files location: tests/lambda-events/"
        Write-Info "Run tests with: .\tests\lambda-events\run-tests.ps1 -AllFunctions"
        Write-Info "Or test single function: .\tests\lambda-events\run-tests.ps1 -FunctionName characters-list"
    }
    
    if ($RunTests) {
        Write-Info ""
        Write-Info "🚀 Running automated tests..."
        if (Test-Path "tests/lambda-events/run-tests.ps1") {
            & "tests/lambda-events/run-tests.ps1" -AllFunctions
        }
    }
        
    Write-Info ""
    Write-Info "✅ Deployment completed successfully!"
    Write-Info ""
    Write-Info "📋 Next steps:"
    Write-Info "1. Test functions: .\tests\lambda-events\run-tests.ps1 -AllFunctions"
    Write-Info "2. Start frontend: npm run dev"
    Write-Info "3. Open browser to http://localhost:5173"
    Write-Info "4. Register/login and start the game"
} else {
    Write-Error-Custom "Some Lambda function deployments failed."
    Write-Info "Check error logs and Lambda function logs:"
    Write-Info "aws logs describe-log-groups --log-group-name-prefix /aws/lambda/$ProjectName --region $AWSRegion"
    exit 1
}