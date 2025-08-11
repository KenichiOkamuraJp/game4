# Lambda Function Test Runner
# Generated automatically by deploy-lambda-enhanced.ps1

param(
    [string]$FunctionName = "",
    [string]$ProjectName = "dungeon-rpg",
    [string]$AWSRegion = "ap-northeast-1",
    [switch]$AllFunctions = $false
)

Write-Host "ｧｪ Lambda Function Test Runner" -ForegroundColor Green
Write-Host "=============================" -ForegroundColor Green

$testDir = Split-Path $MyInvocation.MyCommand.Path
$testFiles = Get-ChildItem -Path $testDir -Filter "*.json"

if ($AllFunctions) {
    Write-Host "Testing all functions..." -ForegroundColor Yellow
    
    $functions = @("characters-list", "characters-create", "characters-update", "characters-delete")
    
    foreach ($func in $functions) {
        Write-Host "
Testing function: $ProjectName-$func" -ForegroundColor Cyan
        
        # Find appropriate test file
        $testFile = $testFiles | Where-Object { $_.BaseName -like "*$func*" -or $_.BaseName -eq "characters-list-auth" } | Select-Object -First 1
        
        if ($testFile) {
            Write-Host "Using test file: $($testFile.Name)" -ForegroundColor Gray
            
            $result = aws lambda invoke `
                --function-name "$ProjectName-$func" `
                --payload "file://$($testFile.FullName)" `
                --output json `
                --region $AWSRegion `
                "output-$func.json" 2>&1
                
            if ($LASTEXITCODE -eq 0) {
                Write-Host "笨・$func: Success" -ForegroundColor Green
                if (Test-Path "output-$func.json") {
                    $output = Get-Content "output-$func.json" | ConvertFrom-Json
                    Write-Host "   Status: $($output.statusCode)" -ForegroundColor Gray
                }
            } else {
                Write-Host "笶・$func: Failed" -ForegroundColor Red
                Write-Host "   Error: $result" -ForegroundColor Red
            }
        } else {
            Write-Host "笞・・ No test file found for $func" -ForegroundColor Yellow
        }
    }
} elseif ($FunctionName) {
    Write-Host "Testing function: $ProjectName-$FunctionName" -ForegroundColor Cyan
    
    # Find test file
    $testFile = $testFiles | Where-Object { $_.BaseName -like "*$FunctionName*" } | Select-Object -First 1
    
    if (!$testFile) {
        $testFile = $testFiles | Where-Object { $_.BaseName -eq "characters-list-auth" } | Select-Object -First 1
    }
    
    if ($testFile) {
        Write-Host "Using test file: $($testFile.Name)" -ForegroundColor Gray
        
        $result = aws lambda invoke `
            --function-name "$ProjectName-$FunctionName" `
            --payload "file://$($testFile.FullName)" `
            --output json `
            --region $AWSRegion `
            "output-$FunctionName.json" 2>&1
            
        if ($LASTEXITCODE -eq 0) {
            Write-Host "笨・Test successful!" -ForegroundColor Green
            if (Test-Path "output-$FunctionName.json") {
                $output = Get-Content "output-$FunctionName.json" | ConvertFrom-Json
                Write-Host "Response:" -ForegroundColor Yellow
                $output | ConvertTo-Json -Depth 5 | Write-Host
            }
        } else {
            Write-Host "笶・Test failed!" -ForegroundColor Red
            Write-Host "Error: $result" -ForegroundColor Red
        }
    } else {
        Write-Host "笶・No test file found for function: $FunctionName" -ForegroundColor Red
    }
} else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\run-tests.ps1 -FunctionName characters-list"
    Write-Host "  .\run-tests.ps1 -AllFunctions"
    Write-Host ""
    Write-Host "Available test files:" -ForegroundColor Yellow
    $testFiles | ForEach-Object { Write-Host "  - $($_.BaseName)" -ForegroundColor Gray }
}

Write-Host "
潤 Test run completed." -ForegroundColor Green