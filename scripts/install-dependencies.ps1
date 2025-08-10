#Requires -Version 5.1
# Vue.js Dungeon RPG Dependencies Installer

[CmdletBinding()]
param(
    [switch]$SkipNpm = $false,
    [switch]$SkipAWS = $false,
    [switch]$SkipPython = $false,
    [switch]$Force = $false
)

# Encoding setup
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

$ErrorActionPreference = "Stop"

# Remove Pester module conflicts
if (Get-Module -Name Pester -ListAvailable) {
    Remove-Module -Name Pester -Force -ErrorAction SilentlyContinue
}

Write-Host "Vue.js Dungeon RPG Dependencies Installation Started" -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Yellow

# Helper functions
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

function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Install-Winget {
    Write-Info "Checking winget..."
    if (!(Test-Command "winget")) {
        Write-Warn "winget not found"
        Write-Info "Install 'App Installer' from Microsoft Store or"
        Write-Info "Download from: https://github.com/microsoft/winget-cli/releases"
        return $false
    }
    return $true
}

# Check Python
if (-not $SkipPython) {
    Write-Info "Checking Python..."
    if (Test-Command "python") {
        $pythonVersion = python --version 2>&1
        Write-Info "Python found: $pythonVersion"
        
        if ($pythonVersion -match "Python (\d+)\.(\d+)") {
            $majorVersion = [int]$Matches[1]
            $minorVersion = [int]$Matches[2]
            if ($majorVersion -lt 3 -or ($majorVersion -eq 3 -and $minorVersion -lt 8)) {
                Write-Warn "Python 3.8+ recommended. Current: $pythonVersion"
                
                if (Install-Winget) {
                    $upgrade = Read-Host "Upgrade to Python 3.11? (y/N)"
                    if ($upgrade -match "^[Yy]$") {
                        Write-Info "Installing Python 3.11..."
                        winget install Python.Python.3.11
                    }
                }
            }
        }
    } else {
        Write-Error-Custom "Python not found"
        
        if (Install-Winget) {
            $install = Read-Host "Install Python 3.11? (y/N)"
            if ($install -match "^[Yy]$") {
                Write-Info "Installing Python 3.11..."
                winget install Python.Python.3.11
                Write-Info "Python installed. Please restart PowerShell."
            } else {
                Write-Info "Manual installation:"
                Write-Info "1. winget install Python.Python.3.11"
                Write-Info "2. Download from https://www.python.org/downloads/"
                exit 1
            }
        } else {
            exit 1
        }
    }

    if (Test-Command "pip") {
        $pipVersion = pip --version 2>&1
        Write-Info "pip found: $($pipVersion.Split(' ')[1])"
    } else {
        Write-Error-Custom "pip not found"
        Write-Info "pip usually comes with Python. Consider reinstalling Python."
        exit 1
    }
}

# Check Node.js
if (-not $SkipNpm) {
    Write-Info "Checking Node.js..."
    if (Test-Command "node") {
        $nodeVersion = node --version
        Write-Info "Node.js found: $nodeVersion"
        
        $versionNumber = $nodeVersion -replace 'v', ''
        $majorVersion = [int]($versionNumber.Split('.')[0])
        if ($majorVersion -lt 16) {
            Write-Warn "Node.js 16+ recommended. Current: $nodeVersion"
            
            if (Install-Winget) {
                $upgrade = Read-Host "Upgrade Node.js? (y/N)"
                if ($upgrade -match "^[Yy]$") {
                    Write-Info "Upgrading Node.js..."
                    winget upgrade OpenJS.NodeJS
                }
            }
        }
    } else {
        Write-Error-Custom "Node.js not found"
        
        if (Install-Winget) {
            $install = Read-Host "Install Node.js? (y/N)"
            if ($install -match "^[Yy]$") {
                Write-Info "Installing Node.js..."
                winget install OpenJS.NodeJS
                Write-Info "Node.js installed. Please restart PowerShell."
            } else {
                Write-Info "Manual installation:"
                Write-Info "1. winget install OpenJS.NodeJS"
                Write-Info "2. Download from https://nodejs.org/"
                exit 1
            }
        } else {
            exit 1
        }
    }

    if (Test-Command "npm") {
        $npmVersion = npm --version
        Write-Info "npm found: v$npmVersion"
    } else {
        Write-Error-Custom "npm not found"
        exit 1
    }
}

# Check AWS CLI
if (-not $SkipAWS) {
    Write-Info "Checking AWS CLI..."
    if (Test-Command "aws") {
        $awsVersion = aws --version 2>$null
        Write-Info "AWS CLI found: $($awsVersion.Split()[0])"
    } else {
        Write-Error-Custom "AWS CLI not found"
        
        if (Install-Winget) {
            $install = Read-Host "Install AWS CLI? (y/N)"
            if ($install -match "^[Yy]$") {
                Write-Info "Installing AWS CLI..."
                winget install Amazon.AWSCLI
                Write-Info "AWS CLI installed. Please restart PowerShell."
            } else {
                Write-Info "Manual installation:"
                Write-Info "1. winget install Amazon.AWSCLI"
                Write-Info "2. Download from https://awscli.amazonaws.com/AWSCLIV2.msi"
                exit 1
            }
        } else {
            exit 1
        }
    }

    # Check AWS credentials
    Write-Info "Checking AWS credentials..."
    try {
        $callerIdentity = aws sts get-caller-identity --output json 2>$null | ConvertFrom-Json
        if ($callerIdentity) {
            Write-Info "AWS credentials configured: $($callerIdentity.Arn)"
        } else {
            Write-Warn "AWS credentials not configured"
            $configure = Read-Host "Configure AWS credentials? (y/N)"
            if ($configure -match "^[Yy]$") {
                Write-Info "Run: aws configure"
                Write-Info "You need:"
                Write-Info "- AWS Access Key ID"
                Write-Info "- AWS Secret Access Key"
                Write-Info "- Default region (recommend: ap-northeast-1)"
                Write-Info "- Default output format (recommend: json)"
            }
        }
    } catch {
        Write-Warn "Failed to check AWS credentials"
        Write-Info "Configure later with: aws configure"
    }
}

# Check Git
Write-Info "Checking Git..."
if (Test-Command "git") {
    $gitVersion = git --version
    Write-Info "Git found: $gitVersion"
} else {
    Write-Warn "Git not found"
    
    if (Install-Winget) {
        $install = Read-Host "Install Git? (y/N)"
        if ($install -match "^[Yy]$") {
            Write-Info "Installing Git..."
            winget install Git.Git
            Write-Info "Git installed. Please restart PowerShell."
        }
    }
}

# Create project directories
Write-Info "Creating project structure..."

$directories = @(
    "lambda",
    "lambda/characters", 
    "lambda/saves",
    "scripts"
)

foreach ($dir in $directories) {
    if (!(Test-Path $dir)) {
        Write-Info "Creating directory: $dir"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    } else {
        Write-Info "Directory exists: $dir"
    }
}

# Create Python requirements.txt files
if (-not $SkipPython) {
    Write-Info "Creating Python requirements files..."

    $lambdaDirs = @("lambda/characters", "lambda/saves")

    foreach ($lambdaDir in $lambdaDirs) {
        $requirementsPath = Join-Path $lambdaDir "requirements.txt"
        
        if (!(Test-Path $requirementsPath)) {
            Write-Info "Creating $lambdaDir/requirements.txt..."
            "boto3==1.34.0" | Out-File -FilePath $requirementsPath -Encoding UTF8
            Write-Info "Created $lambdaDir/requirements.txt"
        } else {
            Write-Info "$lambdaDir/requirements.txt exists"
        }
        
        # Check Python files
        $pythonFiles = Get-ChildItem -Path $lambdaDir -Filter "*.py" -ErrorAction SilentlyContinue
        if ($pythonFiles.Count -eq 0) {
            Write-Warn "No Python files found in $lambdaDir"
            Write-Info "Please add Lambda function Python files:"
            if ($lambdaDir -like "*characters*") {
                Write-Info "  - create.py, list.py, update.py, delete.py"
            } else {
                Write-Info "  - create.py, get.py, update.py, delete.py"
            }
        } else {
            Write-Info "$lambdaDir has $($pythonFiles.Count) Python files"
        }
    }
}

# Create package.json
if (-not $SkipNpm) {
    Write-Info "Creating frontend configuration..."
    
    if (!(Test-Path "package.json")) {
        Write-Info "Creating package.json..."
        
        # Create package.json content safely
        $packageJson = New-Object PSObject -Property @{
            name = "vue-dungeon-rpg"
            version = "1.0.0"
            description = "Vue.js Dungeon RPG with Python AWS Lambda Backend"
            type = "module"
            scripts = New-Object PSObject -Property @{
                dev = "vite"
                build = "vite build"
                preview = "vite preview"
            }
            dependencies = New-Object PSObject -Property @{
                vue = "^3.3.4"
            }
            devDependencies = New-Object PSObject -Property @{
                "@vitejs/plugin-vue" = "^4.3.4"
                vite = "^4.4.9"
            }
            keywords = @("vue", "rpg", "game", "aws", "lambda", "python")
            author = ""
            license = "MIT"
        }
        
        $packageJson | ConvertTo-Json -Depth 3 | Out-File -FilePath "package.json" -Encoding UTF8
        Write-Info "Created package.json"
    } else {
        Write-Info "package.json exists"
    }
    
    # Create vite.config.js safely by writing directly
    if (!(Test-Path "vite.config.js")) {
        Write-Info "Creating vite.config.js..."
        
        # Create vite config content as byte array to avoid parsing issues
        $viteContent = @"
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5173,
    host: true,
    open: true
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    minify: 'terser',
    sourcemap: false
  }
})
"@
        
        [System.IO.File]::WriteAllText("vite.config.js", $viteContent, [System.Text.Encoding]::UTF8)
        Write-Info "Created vite.config.js"
    } else {
        Write-Info "vite.config.js exists"
    }
    
    # Install node modules
    if (!(Test-Path "node_modules") -or $Force) {
        Write-Info "Installing frontend dependencies..."
        try {
            npm install
            Write-Info "Frontend dependencies installed successfully"
        } catch {
            Write-Error-Custom "Failed to install frontend dependencies: $_"
            Write-Info "Run manually: npm install"
        }
    } else {
        Write-Info "node_modules exists. Use -Force to reinstall"
    }
}

# Check PowerShell execution policy
Write-Info "Checking PowerShell execution policy..."
$executionPolicy = Get-ExecutionPolicy -Scope CurrentUser

if ($executionPolicy -eq "Restricted") {
    Write-Warn "PowerShell execution policy is restricted"
    $setPolicy = Read-Host "Change execution policy? (y/N)"
    if ($setPolicy -match "^[Yy]$") {
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
            Write-Info "Changed PowerShell execution policy to RemoteSigned"
        } catch {
            Write-Error-Custom "Failed to change execution policy: $_"
            Write-Info "Run manually: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
        }
    }
} else {
    Write-Info "PowerShell execution policy: $executionPolicy"
}

# Create .gitignore
if (!(Test-Path ".gitignore")) {
    Write-Info "Creating .gitignore..."
    
    $gitignoreContent = @"
# Dependencies
node_modules/
lambda/*/venv/
lambda/*/__pycache__/
lambda/*/*.pyc

# Build output
dist/
build/

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# AWS
.aws/

# Lambda deployment ZIP
*.zip

# Python
*.pyc
__pycache__/
*.pyo
*.pyd
.Python
pip-log.txt
pip-delete-this-directory.txt
.tox
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.log
.git
.mypy_cache
.pytest_cache
.hypothesis

# Temporary files
*.tmp
*.temp
"@
    
    [System.IO.File]::WriteAllText(".gitignore", $gitignoreContent, [System.Text.Encoding]::UTF8)
    Write-Info "Created .gitignore"
} else {
    Write-Info ".gitignore exists"
}

# Check PowerShell profile
Write-Info "Checking PowerShell profile..."
if (!(Test-Path $PROFILE)) {
    Write-Info "PowerShell profile not found"
    $createProfile = Read-Host "Create profile with UTF-8 encoding settings? (y/N)"
    if ($createProfile -match "^[Yy]$") {
        $profileDir = Split-Path $PROFILE -Parent
        if (!(Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }
        
        $profileContent = @"
# PowerShell Profile - Vue.js Dungeon RPG
# Encoding settings
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
`$OutputEncoding = [System.Text.Encoding]::UTF8
`$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
`$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'

Write-Host "PowerShell UTF-8 encoding settings applied" -ForegroundColor Green
"@
        
        [System.IO.File]::WriteAllText($PROFILE, $profileContent, [System.Text.Encoding]::UTF8)
        Write-Info "Created PowerShell profile: $PROFILE"
        Write-Info "UTF-8 settings will auto-apply on next PowerShell startup"
    }
} else {
    Write-Info "PowerShell profile exists: $PROFILE"
    
    $profileContent = Get-Content $PROFILE -Raw
    if ($profileContent -notlike "*UTF8*") {
        $addUtf8 = Read-Host "Add UTF-8 encoding settings to profile? (y/N)"
        if ($addUtf8 -match "^[Yy]$") {
            $utf8Settings = @"

# UTF-8 encoding settings (Vue.js Dungeon RPG)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
`$OutputEncoding = [System.Text.Encoding]::UTF8
`$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
"@
            
            Add-Content -Path $PROFILE -Value $utf8Settings -Encoding UTF8
            Write-Info "Added UTF-8 settings to PowerShell profile"
        }
    }
}

Write-Info "Dependencies installation completed!" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Yellow

Write-Info "Installed software:"
if (Test-Command "python") { Write-Info "  Python: $(python --version)" }
if (Test-Command "node") { Write-Info "  Node.js: $(node --version)" }
if (Test-Command "npm") { Write-Info "  npm: v$(npm --version)" }
if (Test-Command "aws") { Write-Info "  AWS CLI: $((aws --version 2>&1).Split()[0])" }
if (Test-Command "git") { Write-Info "  Git: $(git --version)" }

Write-Host ""
Write-Info "Next steps:"
Write-Info "1. Add Lambda function Python files"
Write-Info "2. Configure AWS credentials: aws configure"
Write-Info "3. Deploy infrastructure: .\scripts\setup.ps1"
Write-Info "4. Deploy Python Lambda functions: .\scripts\deploy-lambda.ps1"
Write-Info "5. Start development server: npm run dev"

Write-Host ""
Write-Info "Python Lambda functions:"
Write-Info "- Runtime: Python 3.11"
Write-Info "- Dependencies: boto3 (AWS SDK)"
Write-Info "- Handler: {filename}.lambda_handler"

Write-Host ""
if (!(Test-Path ".env")) {
    Write-Warn "Note: .env file will be auto-generated after infrastructure deployment"
}

Write-Info "See README.md for details"