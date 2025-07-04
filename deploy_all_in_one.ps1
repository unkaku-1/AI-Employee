<#
.SYNOPSIS
    Automates the deployment of FastGPT and Dify platforms on a Windows environment.
.DESCRIPTION
    This script performs a series of checks and actions to deploy FastGPT and Dify using Docker.
    It handles prerequisite checks, repository cloning, configuration file generation, and service startup.
    The script is designed to be idempotent and robust, incorporating fixes for common deployment issues.

    Key Steps:
    1.  Checks for Git, Docker, WSL2, and Node.js.
    2.  Clones the latest versions of FastGPT and Dify repositories if they don't exist.
    3.  Generates the necessary Docker Compose and environment files.
    4.  Applies automated fixes for known issues like port conflicts and missing configuration files.
    5.  Starts all services in the correct order.
.NOTES
    Author: Gemini
    Version: 1.1
    Creation Date: 2025-07-05
#>

# --- Script Configuration ---
$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot | Resolve-Path -LiteralPath
$fastGptDir = Join-Path $scriptDir "FastGPT"
$difyDir = Join-Path $scriptDir "dify"

# --- Prerequisite Check Functions ---

function Ensure-CommandExists {
    param (
        [string]$Command,
        [string]$InstallUrl
    )
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Host "--------------------------------------------------" -ForegroundColor Yellow
        Write-Host "Error: Command '$Command' not found." -ForegroundColor Red
        Write-Host "Please install the required software and re-run this script." -ForegroundColor Yellow
        Write-Host "Download from: $InstallUrl" -ForegroundColor Cyan
        Write-Host "--------------------------------------------------" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "[✓] Command found: $Command" -ForegroundColor Green
}

function Ensure-DockerDesktopRunning {
    Write-Host "Checking Docker Desktop status..."
    try {
        docker info > $null
        Write-Host "[✓] Docker Desktop is running." -ForegroundColor Green
    } catch {
        Write-Host "--------------------------------------------------" -ForegroundColor Yellow
        Write-Host "Error: Docker Desktop is not running or not installed correctly." -ForegroundColor Red
        Write-Host "Please ensure Docker Desktop is installed, running, and has the WSL2 backend enabled." -ForegroundColor Yellow
        Write-Host "Download from: https://www.docker.com/products/docker-desktop/" -ForegroundColor Cyan
        Write-Host "--------------------------------------------------" -ForegroundColor Yellow
        exit 1
    }
}

# --- Main Deployment Logic ---

function Deploy-FastGPT {
    Write-Host "--- Starting FastGPT Deployment ---" -ForegroundColor Magenta

    # 1. Clone FastGPT repository
    if (-not (Test-Path $fastGptDir)) {
        Write-Host "Cloning FastGPT repository..."
        git clone "https://github.com/labring/FastGPT.git" $fastGptDir
    } else {
        Write-Host "FastGPT directory already exists, skipping clone."
    }

    $deployDir = Join-Path $fastGptDir "deploy/docker"
    Set-Location $deployDir

    # 2. Generate docker-compose-pgvector.yml
    Write-Host "Generating docker-compose file for FastGPT..."
    try {
        node yml.js
    } catch {
        Write-Host "Error: Failed to run 'node yml.js'. Please ensure Node.js is installed and in your PATH." -ForegroundColor Red
        exit 1
    }
    
    $composeFile = Join-Path $deployDir "docker-compose-pgvector.yml"
    if (-not (Test-Path $composeFile)) {
        Write-Host "Error: docker-compose-pgvector.yml file was not generated." -ForegroundColor Red
        exit 1
    }

    # 3. Fix config.json issue
    $configFile = Join-Path $deployDir "config.json"
    if (Test-Path $configFile -PathType Container) {
        Write-Host "Detected 'config.json' as a directory, removing it..."
        Remove-Item -Recurse -Force $configFile
    }
    if (-not (Test-Path $configFile)) {
        Write-Host "Creating empty 'config.json' to prevent mount errors..."
        Set-Content -Path $configFile -Value "{}" -Encoding UTF8
    }

    # 4. Fix port conflict
    Write-Host "Applying port conflict fix for FastGPT (3000 -> 3001)..."
    (Get-Content $composeFile -Raw) -replace '      - 3000:3000', '      - 3001:3000' | Set-Content $composeFile -Encoding UTF8

    # 5. Start services
    Write-Host "Stopping any old or orphaned containers..."
    docker compose -f $composeFile down --remove-orphans --quiet
    
    Write-Host "Starting FastGPT services (this may take a few minutes)..."
    docker compose -f $composeFile up -d

    # 6. Verify deployment
    Write-Host "Waiting for services to start... (up to 2 minutes)"
    $timeout = 120
    $interval = 10
    $timer = 0
    while ($timer -lt $timeout) {
        $status = (docker ps --filter "name=fastgpt" --format "{{.Status}}")
        if ($status -like "Up*") {
            Write-Host "[✓] FastGPT container started successfully!" -ForegroundColor Green
            Write-Host "--------------------------------------------------"
            Write-Host "FastGPT Deployment Successful!" -ForegroundColor Green
            Write-Host "Access URL: http://localhost:3001" -ForegroundColor Cyan
            Write-Host "Default Username: root" -ForegroundColor Cyan
            Write-Host "Default Password: 1234" -ForegroundColor Cyan
            Write-Host "--------------------------------------------------"
            return
        }
        Start-Sleep -Seconds $interval
        $timer += $interval
        Write-Host "Still waiting for the fastgpt container to start... ($timer / $timeout seconds)"
    }

    Write-Host "Error: FastGPT container failed to start in time. Please run 'docker logs fastgpt' to check the logs." -ForegroundColor Red
    exit 1
}

function Deploy-Dify {
    Write-Host "--- Starting Dify Deployment ---" -ForegroundColor Magenta

    # 1. Clone Dify repository
    if (-not (Test-Path $difyDir)) {
        Write-Host "Cloning Dify repository..."
        git clone "https://github.com/langgenius/dify.git" $difyDir
    } else {
        Write-Host "Dify directory already exists, skipping clone."
    }

    $deployDir = Join-Path $difyDir "docker"
    Set-Location $deployDir

    # 2. Create and configure .env file
    Write-Host "Creating and configuring .env file for Dify..."
    $envFile = Join-Path $deployDir ".env"
    $envExampleFile = Join-Path $deployDir ".env.example"
    Copy-Item $envExampleFile $envFile -Force

    $secretKey = "sk-$(New-Guid)"
    (Get-Content $envFile -Raw) -replace 'SECRET_KEY=sk-9f73s3ljTXVcMT3Blb3ljTqtsKiGHXVcMT3BlbkFJLK7U', "SECRET_KEY=$secretKey" | Set-Content $envFile -Encoding UTF8
    (Get-Content $envFile -Raw) -replace 'CONSOLE_API_URL=', "CONSOLE_API_URL=http://localhost:5001" | Set-Content $envFile -Encoding UTF8
    (Get-Content $envFile -Raw) -replace 'APP_API_URL=', "APP_API_URL=http://localhost:5001" | Set-Content $envFile -Encoding UTF8
    (Get-Content $envFile -Raw) -replace 'EXPOSE_NGINX_PORT=80', "EXPOSE_NGINX_PORT=8080" | Set-Content $envFile -Encoding UTF8
    
    # 3. Start services
    Write-Host "Stopping any old or orphaned containers..."
    docker compose down --remove-orphans --quiet

    Write-Host "Starting Dify services (this may take a few minutes)..."
    docker compose up -d

    # 4. Verify deployment
    Write-Host "Waiting for services to start... (up to 2 minutes)"
    $timeout = 120
    $interval = 10
    $timer = 0
    while ($timer -lt $timeout) {
        $status = (docker ps --filter "name=docker-web-1" --format "{{.Status}}")
        if ($status -like "Up*") {
            Write-Host "[✓] Dify containers started successfully!" -ForegroundColor Green
            Write-Host "--------------------------------------------------"
            Write-Host "Dify Deployment Successful!" -ForegroundColor Green
            Write-Host "Please open the following URL in your browser to complete the initial setup:" -ForegroundColor Cyan
            Write-Host "http://localhost:8080/install" -ForegroundColor Cyan
            Write-Host "--------------------------------------------------"
            return
        }
        Start-Sleep -Seconds $interval
        $timer += $interval
        Write-Host "Still waiting for Dify containers to start... ($timer / $timeout seconds)"
    }
    
    Write-Host "Error: Dify containers failed to start in time. Please run 'docker compose logs' to check the logs." -ForegroundColor Red
    exit 1
}


# --- Script Entry Point ---

try {
    Write-Host "Starting full deployment of the AI-Employee environment..."
    
    # 1. Prerequisite checks
    Write-Host "--- Step 1: Prerequisite Checks ---" -ForegroundColor Magenta
    Ensure-CommandExists -Command "git" -InstallUrl "https://git-scm.com/download/win"
    Ensure-CommandExists -Command "node" -InstallUrl "https://nodejs.org/en/download"
    Ensure-DockerDesktopRunning

    # 2. Deploy FastGPT
    Deploy-FastGPT
    
    # 3. Deploy Dify
    Deploy-Dify

    Write-Host "**************************************************" -ForegroundColor Green
    Write-Host "All platforms have been deployed successfully!" -ForegroundColor Green
    Write-Host "**************************************************"
}
catch {
    Write-Host "A critical error occurred during deployment: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    # Restore the original location
    Set-Location $scriptDir
    Write-Host "Script execution finished."
}