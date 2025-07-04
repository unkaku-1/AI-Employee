# FastGPT Deployment Script
# This script automates the deployment process of FastGPT, including cloning the repository,
# configuring the .env file, starting the services, and verifying the database connection.

# --- Configuration ---
$scriptDir = $PSScriptRoot
$fastGptRepoUrl = "https://github.com/labring/FastGPT.git"
$fastGptDir = Join-Path $scriptDir "FastGPT"
$fastGptEnvExampleFile = Join-Path $fastGptDir ".env.example"
$fastGptEnvFile = Join-Path $fastGptDir ".env"

# --- Prerequisite Checks ---

# Checks if Git is installed and attempts to install it via winget if not found.
function Ensure-GitInstalled {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Git is not installed. Attempting to install via winget..."
        try {
            winget install --id Git.Git -e --source winget
            if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
                Write-Host "Failed to install Git using winget. Please install Git manually and ensure it's in your PATH." -ForegroundColor Red
                Write-Host "Download from: https://git-scm.com/download/win" -ForegroundColor Yellow
                exit 1
            }
        } catch {
            Write-Host "winget command is unavailable or the installation failed. Please install Git manually and ensure it's in your PATH." -ForegroundColor Red
            Write-Host "Download from: https://git-scm.com/download/win" -ForegroundColor Yellow
            exit 1
        }
    }
}

# Checks if Docker Desktop is running.
function Ensure-DockerDesktopRunning {
    Write-Host "Checking Docker Desktop status..."
    $dockerRunning = (docker info 2>$null | Select-String -Pattern "Server Version" -Quiet)
    if (-not $dockerRunning) {
        Write-Host "Docker Desktop is not running or not installed correctly. Please ensure Docker Desktop is installed, running, and WSL2 is enabled." -ForegroundColor Red
        Write-Host "Download from: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "Docker Desktop is running."
}

# Checks if WSL2 is installed and set as the default version.
function Ensure-WSL2Configured {
    Write-Host "Checking WSL2 configuration..."
    try {
        $wslVersion = wsl --version 2>$null
        if (-not $wslVersion) {
            Write-Host "WSL is not installed. Attempting to install WSL..." -ForegroundColor Yellow
            wsl --install
            Write-Host "Please restart your computer to complete the WSL installation, then re-run this script." -ForegroundColor Green
            exit 0
        }
        wsl --set-default-version 2 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to set WSL2 as the default version. Please ensure your system supports WSL2." -ForegroundColor Red
            exit 1
        }
        Write-Host "WSL2 has been configured as the default version."
    } catch {
        Write-Host "An error occurred while checking WSL2 configuration: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# --- Main Deployment Logic ---

# Main function to deploy FastGPT.
function Start-FastGptDeployment {
    param (
        [string]$PostgresPassword,
        [string]$MongoRootPassword,
        [string]$OllamaHost,
        [string]$JwtSecret
    )

    Write-Host "Starting FastGPT deployment..." -ForegroundColor Green

    # 1. Prerequisite checks
    Ensure-GitInstalled
    Ensure-WSL2Configured
    Ensure-DockerDesktopRunning

    # 2. Clone FastGPT repository
    if (Test-Path $fastGptDir) {
        Write-Host "FastGPT directory already exists. Pulling latest changes..." -ForegroundColor Yellow
        Push-Location $fastGptDir
        git pull
        Pop-Location
    } else {
        Write-Host "Cloning FastGPT repository..." -ForegroundColor Green
        git clone $fastGptRepoUrl $fastGptDir
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to clone FastGPT repository." -ForegroundColor Red
            exit 1
        }
    }

    # Change to FastGPT directory for subsequent commands
    Set-Location $fastGptDir

    # 3. Create and configure .env file
    Write-Host "Creating and configuring .env file..." -ForegroundColor Green
    Copy-Item $fastGptEnvExampleFile $fastGptEnvFile -Force

    $envFileContent = Get-Content $fastGptEnvFile | Out-String
    $envFileContent = $envFileContent -replace "^POSTGRES_PASSWORD=.*$", "POSTGRES_PASSWORD=$PostgresPassword"
    $envFileContent = $envFileContent -replace "^MONGO_INITDB_ROOT_PASSWORD=.*$", "MONGO_INITDB_ROOT_PASSWORD=$MongoRootPassword"
    $envFileContent = $envFileContent -replace "^OLLAMA_HOST=.*$", "OLLAMA_HOST=$OllamaHost"
    $envFileContent = $envFileContent -replace "^JWT_SECRET=.*$", "JWT_SECRET=$JwtSecret"
    Set-Content -LiteralPath $fastGptEnvFile -Value $envFileContent -Encoding UTF8
    Write-Host ".env file configured successfully." -ForegroundColor Green

    # 4. Pull Docker images and start services
    Write-Host "Pulling Docker images and starting FastGPT services (this may take a while)..." -ForegroundColor Green
    docker compose pull
    Write-Host "Starting containers in foreground to view logs..." -ForegroundColor Yellow
    docker compose up

    # 5. Verify FastGPT service status (Commented out for debugging)
    # Write-Host "Verifying FastGPT service status... (waiting 30 seconds for services to initialize)" -ForegroundColor Green
    # Start-Sleep -Seconds 30
    # $healthCheckUrl = "http://localhost/health"
    # try {
    #     $response = Invoke-WebRequest -Uri $healthCheckUrl -UseBasicParsing -ErrorAction Stop
    #     if ($response.StatusCode -eq 200 -and $response.Content -like '*"healthy"*') {
    #         Write-Host "FastGPT service is running properly!" -ForegroundColor Green
    #     } else {
    #         Write-Host "FastGPT service health check failed. Status Code: $($response.StatusCode), Content: $($response.Content)" -ForegroundColor Red
    #     }
    # } catch {
    #     Write-Host "Could not connect to the FastGPT health check endpoint. Please check if the service has started or if the port is open. Error: $($_.Exception.Message)" -ForegroundColor Red
    # }

    # 6. Verify database container status (Commented out for debugging)
    # Write-Host "Verifying database container status..." -ForegroundColor Green
    # try {
    #     # PostgreSQL
    #     docker exec -i fastgpt_postgres_1 psql -U postgres -c "\l" 2>&1 | Out-Null
    #     if ($LASTEXITCODE -eq 0) {
    #         Write-Host "PostgreSQL container is running properly." -ForegroundColor Green
    #     } else {
    #         Write-Host "PostgreSQL container verification failed." -ForegroundColor Red
    #     }

    #     # MongoDB
    #     docker exec -i fastgpt_mongo_1 mongosh --eval "db.adminCommand('ping')" 2>&1 | Out-Null
    #     if ($LASTEXITCODE -eq 0) {
    #         Write-Host "MongoDB container is running properly." -ForegroundColor Green
    #     } else {
    #         Write-Host "MongoDB container verification failed." -ForegroundColor Red
    #     }
    # } catch {
    #     Write-Host "An error occurred while verifying database status: $($_.Exception.Message)" -ForegroundColor Red
    # }

    Write-Host "FastGPT deployment process completed." -ForegroundColor Green
}

# --- Script Entry Point ---

# Store original location
$originalLocation = Get-Location

try {
    # Get user input for required passwords
    Write-Host "WARNING: Passwords entered here will be temporarily stored in memory as plain text." -ForegroundColor Yellow
    $postgresPassSecure = Read-Host -Prompt "Enter the PostgreSQL database password (e.g., your_postgres_password)" -AsSecureString
    $mongoPassSecure = Read-Host -Prompt "Enter the MongoDB root password (e.g., your_mongo_password)" -AsSecureString

    # Get user input for optional values
    $ollamaHostInput = Read-Host -Prompt "Enter the Ollama service address (e.g., http://localhost:11434, leave blank for default)"
    $jwtSecretInput = Read-Host -Prompt "Enter the JWT Secret (a random string is recommended, leave blank to auto-generate)"

    # Convert SecureString to PlainText for use in .env file
    $postgresPassPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($postgresPassSecure))
    $mongoPassPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($mongoPassSecure))

    # Set default values if input is empty
    $ollamaHost = if ([string]::IsNullOrWhiteSpace($ollamaHostInput)) { "http://localhost:11434" } else { $ollamaHostInput }
    $jwtSecret = if ([string]::IsNullOrWhiteSpace($jwtSecretInput)) { (New-Guid).ToString() } else { $jwtSecretInput }

    # Call the deployment function
    Start-FastGptDeployment -PostgresPassword $postgresPassPlain -MongoRootPassword $mongoPassPlain -OllamaHost $ollamaHost -JwtSecret $jwtSecret
}
finally {
    # Restore the original location
    Set-Location $originalLocation
    Write-Host "Script execution finished." -ForegroundColor Green
}