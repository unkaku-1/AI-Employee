



# FastGPT 部署脚本
# 本脚本旨在自动化FastGPT的部署过程，包括克隆仓库、配置.env文件、启动服务和验证数据库。

# 定义变量
$FastGPTRepo = "https://github.com/labring/FastGPT.git"
$FastGPTDir = "FastGPT"
$FastGPTEnvExample = ".env.example"
$FastGPTEnv = ".env"

# 检查并安装Git (如果未安装)
function Install-Git {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Git 未安装，正在尝试安装..."
        try {
            # 尝试使用 winget 安装 Git
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
function Deploy-FastGPT {
    param (
        [string]$PostgresPassword,
        [string]$MongoRootPassword,
        [string]$OllamaHost = "http://localhost:11434",
        [string]$JwtSecret = (New-Guid).ToString()
    )

    Write-Host "开始部署 FastGPT..." -ForegroundColor Green

    # 1. 检查并安装Git
    Install-Git

    # 2. 检查并配置WSL2
    Check-WSL2

    # 3. 检查Docker Desktop状态
    Check-DockerDesktop

    # 4. 克隆 FastGPT 仓库
    if (Test-Path $FastGPTDir) {
        Write-Host "FastGPT 目录已存在，跳过克隆。" -ForegroundColor Yellow
        Set-Location $FastGPTDir
        git pull
    } else {
        Write-Host "克隆 FastGPT 仓库..." -ForegroundColor Green
        git clone $FastGPTRepo
        if (-not (Test-Path $FastGPTDir)) {
            Write-Host "FastGPT 仓库克隆失败。" -ForegroundColor Red
            exit 1
        }
        Set-Location $FastGPTDir
    }

    # 5. 创建并编辑 .env 文件
    Write-Host "创建并配置 .env 文件..." -ForegroundColor Green
    Copy-Item $FastGPTEnvExample $FastGPTEnv -Force

    # 读取 .env 文件内容
    $envContent = Get-Content $FastGPTEnv | Out-String

    # 替换关键配置项
    $envContent = $envContent -replace "^POSTGRES_PASSWORD=.*$", "POSTGRES_PASSWORD=$PostgresPassword"
    $envContent = $envContent -replace "^MONGO_INITDB_ROOT_PASSWORD=.*$", "MONGO_INITDB_ROOT_PASSWORD=$MongoRootPassword"
    $envContent = $envContent -replace "^OLLAMA_HOST=.*$", "OLLAMA_HOST=$OllamaHost"
    $envContent = $envContent -replace "^JWT_SECRET=.*$", "JWT_SECRET=$JwtSecret"

    # 写入修改后的内容
    Set-Content -Path $FastGPTEnv -Value $envContent
    Write-Host ".env 文件配置完成。" -ForegroundColor Green

    # 6. 拉取 Docker 镜像并启动服务
    Write-Host "拉取 Docker 镜像并启动 FastGPT 服务..." -ForegroundColor Green
    docker-compose pull
    docker-compose up -d

    # 7. 验证 FastGPT 服务状态
    Write-Host "验证 FastGPT 服务状态..." -ForegroundColor Green
    Start-Sleep -Seconds 30 # 等待服务启动
    $healthCheckUrl = "http://localhost/health"
    try {
        $response = Invoke-WebRequest -Uri $healthCheckUrl -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200 -and $response.Content -like '*"healthy"*') {
            Write-Host "FastGPT 服务运行正常！" -ForegroundColor Green
        } else {
            Write-Host "FastGPT 服务健康检查失败。状态码: $($response.StatusCode)，内容: $($response.Content)" -ForegroundColor Red
        }
    } catch {
        Write-Host "无法连接到 FastGPT 健康检查接口。请检查服务是否启动或端口是否开放。错误: $($_.Exception.Message)" -ForegroundColor Red
    }

    # 8. 验证数据库状态 (可选，仅作示例)
    Write-Host "验证数据库状态..." -ForegroundColor Green
    try {
        # PostgreSQL
        docker exec -it fastgpt_postgres_1 psql -U postgres -c "\l" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "PostgreSQL 数据库容器运行正常。" -ForegroundColor Green
        } else {
            Write-Host "PostgreSQL 数据库容器验证失败。" -ForegroundColor Red
        }

        # MongoDB
        docker exec -it fastgpt_mongo_1 mongosh --eval "db.adminCommand('ping')" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "MongoDB 数据库容器运行正常。" -ForegroundColor Green
        } else {
            Write-Host "MongoDB 数据库容器验证失败。" -ForegroundColor Red
        }
    } catch {
        Write-Host "验证数据库时发生错误: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host "FastGPT 部署流程完成。" -ForegroundColor Green
}

# 脚本入口
# 请替换以下密码为您的实际密码
$postgresPass = Read-Host -Prompt "请输入 PostgreSQL 数据库密码 (例如: your_postgres_password)" -AsSecureString
$mongoPass = Read-Host -Prompt "请输入 MongoDB 数据库密码 (例如: your_mongo_password)" -AsSecureString
$ollamaHostInput = Read-Host -Prompt "请输入 Ollama 服务地址 (例如: http://localhost:11434 或 http://192.168.1.100:11434, 留空则使用默认值)"
$jwtSecretInput = Read-Host -Prompt "请输入 JWT Secret (建议使用随机字符串，留空则自动生成)"

# 将 SecureString 转换为 PlainText
$postgresPassPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($postgresPass))
$mongoPassPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($mongoPass))

# 调用部署函数
if ([string]::IsNullOrWhiteSpace($ollamaHostInput)) {
    if ([string]::IsNullOrWhiteSpace($jwtSecretInput)) {
        Deploy-FastGPT -PostgresPassword $postgresPassPlain -MongoRootPassword $mongoPassPlain
    } else {
        Deploy-FastGPT -PostgresPassword $postgresPassPlain -MongoRootPassword $mongoPassPlain -JwtSecret $jwtSecretInput
    }
} else {
    if ([string]::IsNullOrWhiteSpace($jwtSecretInput)) {
        Deploy-FastGPT -PostgresPassword $postgresPassPlain -MongoRootPassword $mongoPassPlain -OllamaHost $ollamaHostInput
    } else {
        Deploy-FastGPT -PostgresPassword $postgresPassPlain -MongoRootPassword $mongoPassPlain -OllamaHost $ollamaHostInput -JwtSecret $jwtSecretInput
    }
}

# 恢复到脚本执行前的目录
Set-Location (Split-Path $MyInvocation.MyCommand.Path -Parent)

Write-Host "脚本执行完毕。" -ForegroundColor Green


