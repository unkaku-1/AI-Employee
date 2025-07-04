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
    Version: 1.0
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
        Write-Host "错误: 命令 '$Command' 未找到。" -ForegroundColor Red
        Write-Host "请先安装所需软件，然后重新运行此脚本。" -ForegroundColor Yellow
        Write-Host "下载地址: $InstallUrl" -ForegroundColor Cyan
        Write-Host "--------------------------------------------------" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "[✓] 已找到命令: $Command" -ForegroundColor Green
}

function Ensure-DockerDesktopRunning {
    Write-Host "正在检查 Docker Desktop 状态..."
    try {
        docker info > $null
        Write-Host "[✓] Docker Desktop 正在运行。" -ForegroundColor Green
    } catch {
        Write-Host "--------------------------------------------------" -ForegroundColor Yellow
        Write-Host "错误: Docker Desktop 未运行或未正确安装。" -ForegroundColor Red
        Write-Host "请确保 Docker Desktop 已安装、正在运行，并已启用 WSL2 后端。" -ForegroundColor Yellow
        Write-Host "下载地址: https://www.docker.com/products/docker-desktop/" -ForegroundColor Cyan
        Write-Host "--------------------------------------------------" -ForegroundColor Yellow
        exit 1
    }
}

# --- Main Deployment Logic ---

function Deploy-FastGPT {
    Write-Host "--- 开始部署 FastGPT ---" -ForegroundColor Magenta

    # 1. Clone FastGPT repository
    if (-not (Test-Path $fastGptDir)) {
        Write-Host "正在克隆 FastGPT 仓库..."
        git clone "https://github.com/labring/FastGPT.git" $fastGptDir
    } else {
        Write-Host "FastGPT 目录已存在，跳过克隆。"
    }

    $deployDir = Join-Path $fastGptDir "deploy/docker"
    Set-Location $deployDir

    # 2. Generate docker-compose-pgvector.yml
    Write-Host "正在生成 FastGPT 的 docker-compose 文件..."
    try {
        node yml.js
    } catch {
        Write-Host "错误: 运行 'node yml.js' 失败。请确保 Node.js 已正确安装并位于 PATH 中。" -ForegroundColor Red
        exit 1
    }
    
    $composeFile = Join-Path $deployDir "docker-compose-pgvector.yml"
    if (-not (Test-Path $composeFile)) {
        Write-Host "错误: docker-compose-pgvector.yml 文件生成失败。" -ForegroundColor Red
        exit 1
    }

    # 3. Fix config.json issue
    $configFile = Join-Path $deployDir "config.json"
    if (Test-Path $configFile -PathType Container) {
        Write-Host "检测到 'config.json' 是一个目录，正在删除..."
        Remove-Item -Recurse -Force $configFile
    }
    if (-not (Test-Path $configFile)) {
        Write-Host "正在创建空的 'config.json' 文件以避免挂载错误..."
        Set-Content -Path $configFile -Value "{}" -Encoding UTF8
    }

    # 4. Fix port conflict
    Write-Host "正在修改 FastGPT 端口以避免冲突 (3000 -> 3001)..."
    (Get-Content $composeFile -Raw) -replace '      - 3000:3000', '      - 3001:3000' | Set-Content $composeFile -Encoding UTF8

    # 5. Start services
    Write-Host "正在停止任何可能残留的旧容器..."
    docker compose -f $composeFile down --remove-orphans --quiet
    
    Write-Host "正在启动 FastGPT 服务 (这可能需要几分钟)..."
    docker compose -f $composeFile up -d

    # 6. Verify deployment
    Write-Host "等待服务启动... (最多等待2分钟)"
    $timeout = 120
    $interval = 10
    $timer = 0
    while ($timer -lt $timeout) {
        $status = (docker ps --filter "name=fastgpt" --format "{{.Status}}")
        if ($status -like "Up*") {
            Write-Host "[✓] FastGPT 容器已成功启动！" -ForegroundColor Green
            Write-Host "--------------------------------------------------"
            Write-Host "FastGPT 已部署成功！" -ForegroundColor Green
            Write-Host "访问地址: http://localhost:3001" -ForegroundColor Cyan
            Write-Host "默认用户名: root" -ForegroundColor Cyan
            Write-Host "默认密码: 1234" -ForegroundColor Cyan
            Write-Host "--------------------------------------------------"
            return
        }
        Start-Sleep -Seconds $interval
        $timer += $interval
        Write-Host "仍在等待 fastgpt 容器启动... ($timer / $timeout seconds)"
    }

    Write-Host "错误: FastGPT 容器未能在规定时间内启动。请运行 'docker logs fastgpt' 查看日志。" -ForegroundColor Red
    exit 1
}

function Deploy-Dify {
    Write-Host "--- 开始部署 Dify ---" -ForegroundColor Magenta

    # 1. Clone Dify repository
    if (-not (Test-Path $difyDir)) {
        Write-Host "正在克隆 Dify 仓库..."
        git clone "https://github.com/langgenius/dify.git" $difyDir
    } else {
        Write-Host "Dify 目录已存在，跳过克隆。"
    }

    $deployDir = Join-Path $difyDir "docker"
    Set-Location $deployDir

    # 2. Create and configure .env file
    Write-Host "正在创建并配置 Dify 的 .env 文件..."
    $envFile = Join-Path $deployDir ".env"
    $envExampleFile = Join-Path $deployDir ".env.example"
    Copy-Item $envExampleFile $envFile -Force

    $secretKey = "sk-$(New-Guid)"
    (Get-Content $envFile -Raw) -replace 'SECRET_KEY=sk-9f73s3ljTXVcMT3Blb3ljTqtsKiGHXVcMT3BlbkFJLK7U', "SECRET_KEY=$secretKey" | Set-Content $envFile -Encoding UTF8
    (Get-Content $envFile -Raw) -replace 'CONSOLE_API_URL=', "CONSOLE_API_URL=http://localhost:5001" | Set-Content $envFile -Encoding UTF8
    (Get-Content $envFile -Raw) -replace 'APP_API_URL=', "APP_API_URL=http://localhost:5001" | Set-Content $envFile -Encoding UTF8
    (Get-Content $envFile -Raw) -replace 'EXPOSE_NGINX_PORT=80', "EXPOSE_NGINX_PORT=8080" | Set-Content $envFile -Encoding UTF8
    
    # 3. Start services
    Write-Host "正在停止任何可能残留的旧容器..."
    docker compose down --remove-orphans --quiet

    Write-Host "正在启动 Dify 服务 (这可能需要几分钟)..."
    docker compose up -d

    # 4. Verify deployment
    Write-Host "等待服务启动... (最多等待2分钟)"
    $timeout = 120
    $interval = 10
    $timer = 0
    while ($timer -lt $timeout) {
        $status = (docker ps --filter "name=docker-web-1" --format "{{.Status}}")
        if ($status -like "Up*") {
            Write-Host "[✓] Dify 容器已成功启动！" -ForegroundColor Green
            Write-Host "--------------------------------------------------"
            Write-Host "Dify 已部署成功！" -ForegroundColor Green
            Write-Host "请在浏览器中打开以下地址完成初始化设置:" -ForegroundColor Cyan
            Write-Host "http://localhost:8080/install" -ForegroundColor Cyan
            Write-Host "--------------------------------------------------"
            return
        }
        Start-Sleep -Seconds $interval
        $timer += $interval
        Write-Host "仍在等待 dify 容器启动... ($timer / $timeout seconds)"
    }
    
    Write-Host "错误: Dify 容器未能在规定时间内启动。请运行 'docker compose logs' 查看日志。" -ForegroundColor Red
    exit 1
}


# --- Script Entry Point ---

try {
    Write-Host "开始全面部署 AI-Employee 环境..."
    
    # 1. Prerequisite checks
    Write-Host "--- 步骤 1: 环境检查 ---" -ForegroundColor Magenta
    Ensure-CommandExists -Command "git" -InstallUrl "https://git-scm.com/download/win"
    Ensure-CommandExists -Command "node" -InstallUrl "https://nodejs.org/en/download"
    Ensure-DockerDesktopRunning

    # 2. Deploy FastGPT
    Deploy-FastGPT
    
    # 3. Deploy Dify
    Deploy-Dify

    Write-Host "**************************************************" -ForegroundColor Green
    Write-Host "所有平台均已部署完毕！" -ForegroundColor Green
    Write-Host "**************************************************"
}
catch {
    Write-Host "部署过程中发生严重错误: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    # Restore the original location
    Set-Location $scriptDir
    Write-Host "脚本执行完毕。"
}
