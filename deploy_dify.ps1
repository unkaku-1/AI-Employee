



# Dify 部署脚本
# 本脚本旨在自动化Dify的部署过程，包括克隆仓库、配置.env文件、启动服务和访问安装页面。

# 定义变量
$DifyRepo = "https://github.com/langgenius/dify.git"
$DifyDir = "dify"
$DifyDockerDir = "dify/docker"
$DifyEnvExample = ".env.example"
$DifyEnv = ".env"

# 检查并安装Git (如果未安装)
function Install-Git {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Git 未安装，正在尝试安装..."
        try {
            winget install --id Git.Git -e --source winget
            if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
                Write-Host "winget 安装 Git 失败，请手动安装 Git 并确保其在 PATH 中。" -ForegroundColor Red
                Write-Host "下载地址: https://git-scm.com/download/win" -ForegroundColor Yellow
                exit 1
            }
        } catch {
            Write-Host "winget 命令不可用或安装失败，请手动安装 Git 并确保其在 PATH 中。" -ForegroundColor Red
            Write-Host "下载地址: https://git-scm.com/download/win" -ForegroundColor Yellow
            exit 1
        }
    }
}

# 检查并安装Docker Desktop (如果未运行)
function Check-DockerDesktop {
    Write-Host "检查 Docker Desktop 状态..."
    $dockerRunning = (docker info -f '{{.ServerStatus}}' 2>$null) -eq 'running'
    if (-not $dockerRunning) {
        Write-Host "Docker Desktop 未运行或未正确安装。请确保 Docker Desktop 已安装并正在运行，且 WSL2 已启用。" -ForegroundColor Red
        Write-Host "下载地址: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "Docker Desktop 正在运行。"
}

# 检查并配置WSL2
function Check-WSL2 {
    Write-Host "检查 WSL2 配置..."
    try {
        $wslVersion = wsl --version 2>$null
        if (-not $wslVersion) {
            Write-Host "WSL 未安装。正在尝试安装 WSL..." -ForegroundColor Yellow
            wsl --install
            Write-Host "请重启计算机以完成 WSL 安装，然后重新运行此脚本。" -ForegroundColor Green
            exit 0
        }
        $wslDefaultVersion = (wsl --set-default-version 2 2>$null)
        if ($LASTEXITCODE -ne 0) {
            Write-Host "WSL2 设置为默认版本失败。请确保您的系统支持 WSL2。" -ForegroundColor Red
            exit 1
        }
        Write-Host "WSL2 已配置为默认版本。"
    } catch {
        Write-Host "检查 WSL2 配置时发生错误: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# 主部署流程
function Deploy-Dify {
    param (
        [string]$OllamaHost = "http://192.168.1.100:11434", # 建议使用WSL2虚拟机的实际IP
        [string]$AppKey = (New-Guid).ToString(),
        [string]$SecretKey = (New-Guid).ToString()
    )

    Write-Host "开始部署 Dify..." -ForegroundColor Green

    # 1. 检查并安装Git
    Install-Git

    # 2. 检查并配置WSL2
    Check-WSL2

    # 3. 检查Docker Desktop状态
    Check-DockerDesktop

    # 4. 克隆 Dify 仓库
    if (Test-Path $DifyDir) {
        Write-Host "Dify 目录已存在，跳过克隆。" -ForegroundColor Yellow
        Set-Location $DifyDir
        git pull
    } else {
        Write-Host "克隆 Dify 仓库..." -ForegroundColor Green
        git clone $DifyRepo
        if (-not (Test-Path $DifyDir)) {
            Write-Host "Dify 仓库克隆失败。" -ForegroundColor Red
            exit 1
        }
        Set-Location $DifyDir
    }

    # 5. 进入 Dify Docker 目录
    Write-Host "进入 Dify Docker 目录..." -ForegroundColor Green
    Set-Location $DifyDockerDir

    # 6. 创建并编辑 .env 文件
    Write-Host "创建并配置 .env 文件..." -ForegroundColor Green
    Copy-Item $DifyEnvExample $DifyEnv -Force

    # 读取 .env 文件内容
    $envContent = Get-Content $DifyEnv | Out-String

    # 替换关键配置项
    $envContent = $envContent -replace "^OLLAMA_HOST=.*$", "OLLAMA_HOST=$OllamaHost"
    $envContent = $envContent -replace "^APP_KEY=.*$", "APP_KEY=$AppKey"
    $envContent = $envContent -replace "^SECRET_KEY=.*$", "SECRET_KEY=$SecretKey"

    # 写入修改后的内容
    Set-Content -Path $DifyEnv -Value $envContent
    Write-Host ".env 文件配置完成。" -ForegroundColor Green

    # 7. 拉取 Docker 镜像并启动服务
    Write-Host "拉取 Docker 镜像并启动 Dify 服务..." -ForegroundColor Green
    docker-compose pull
    docker-compose up -d

    # 8. 访问安装页面
    Write-Host "Dify 服务已启动。请访问安装页面完成初始化配置。" -ForegroundColor Green
    Write-Host "访问地址: http://localhost/install" -ForegroundColor Cyan
    Start-Process http://localhost/install

    Write-Host "Dify 部署流程完成。" -ForegroundColor Green
    Write-Host "请在浏览器中完成 Dify 的初始化设置，并根据需求文档配置 Ollama 模型。" -ForegroundColor Yellow
}

# 脚本入口
$ollamaHostInput = Read-Host -Prompt "请输入 Ollama 服务地址 (例如: http://192.168.1.100:11434, 留空则使用默认值)"
$appKeyInput = Read-Host -Prompt "请输入 Dify APP_KEY (建议使用随机字符串，留空则自动生成)"
$secretKeyInput = Read-Host -Prompt "请输入 Dify SECRET_KEY (建议使用随机字符串，留空则自动生成)"

# 调用部署函数
if ([string]::IsNullOrWhiteSpace($ollamaHostInput)) {
    if ([string]::IsNullOrWhiteSpace($appKeyInput)) {
        if ([string]::IsNullOrWhiteSpace($secretKeyInput)) {
            Deploy-Dify
        } else {
            Deploy-Dify -SecretKey $secretKeyInput
        }
    } else {
        if ([string]::IsNullOrWhiteSpace($secretKeyInput)) {
            Deploy-Dify -AppKey $appKeyInput
        } else {
            Deploy-Dify -AppKey $appKeyInput -SecretKey $secretKeyInput
        }
    }
} else {
    if ([string]::IsNullOrWhiteSpace($appKeyInput)) {
        if ([string]::IsNullOrWhiteSpace($secretKeyInput)) {
            Deploy-Dify -OllamaHost $ollamaHostInput
        } else {
            Deploy-Dify -OllamaHost $ollamaHostInput -SecretKey $secretKeyInput
        }
    } else {
        if ([string]::IsNullOrWhiteSpace($secretKeyInput)) {
            Deploy-Dify -OllamaHost $ollamaHostInput -AppKey $appKeyInput
        } else {
            Deploy-Dify -OllamaHost $ollamaHostInput -AppKey $appKeyInput -SecretKey $secretKeyInput
        }
    }
}

# 恢复到脚本执行前的目录
Set-Location (Split-Path $MyInvocation.MyCommand.Path -Parent)

Write-Host "脚本执行完毕。" -ForegroundColor Green


