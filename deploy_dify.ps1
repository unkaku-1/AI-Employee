# Dify Deployment Script
# This script automates the deployment process of Dify, including cloning the repository,
# configuring the .env file, starting the services, and accessing the installation page.

# --- Configuration ---
$difyRepoUrl = "https://github.com/langgenius/dify.git"
$difyDir = "dify"
$difyDockerDir = "dify/docker"
$difyEnvExampleFile = ".env.example"
$difyEnvFile = ".env"

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

# Main function to deploy Dify.
function Start-DifyDeployment {
    param (
        [string]$OllamaHost,
        [string]$AppKey,
        [string]$SecretKey
    )

    Write-Host "Starting Dify deployment..." -ForegroundColor Green

    # 1. Prerequisite checks
    Ensure-GitInstalled
    Ensure-WSL2Configured
    Ensure-DockerDesktopRunning

    # 2. Clone Dify repository
    if (Test-Path $difyDir) {
        Write-Host "Dify directory already exists, skipping clone. Pulling latest changes..." -ForegroundColor Yellow
        Set-Location $difyDir
        git pull
    } else {
        Write-Host "Cloning Dify repository..." -ForegroundColor Green
        git clone $difyRepoUrl
        if (-not (Test-Path $difyDir)) {
            Write-Host "Failed to clone Dify repository." -ForegroundColor Red
            exit 1
        }
        Set-Location $difyDir
    }

    # 3. Navigate to Dify Docker directory
    Write-Host "Changing to Dify Docker directory..." -ForegroundColor Green
    Set-Location $difyDockerDir

    # 4. Create and configure .env file
    Write-Host "Creating and configuring .env file..." -ForegroundColor Green
    Copy-Item $difyEnvExampleFile $difyEnvFile -Force

    $envFileContent = Get-Content $difyEnvFile | Out-String
    $envFileContent = $envFileContent -replace "^OLLAMA_HOST=.*$", "OLLAMA_HOST=$OllamaHost"
    $envFileContent = $envFileContent -replace "^APP_KEY=.*$", "APP_KEY=$AppKey"
    $envFileContent = $envFileContent -replace "^SECRET_KEY=.*$", "SECRET_KEY=$SecretKey"
    Set-Content -Path $difyEnvFile -Value $envFileContent
    Write-Host ".env file configured successfully." -ForegroundColor Green

    # 5. Pull Docker images and start services
    Write-Host "Pulling Docker images and starting Dify services (this may take a while)..." -ForegroundColor Green
    docker compose pull
    docker compose up -d

    # 6. Final instructions
    Write-Host "Dify services started. Please visit the installation page to complete the initial setup." -ForegroundColor Green
    Write-Host "Access URL: http://localhost/install" -ForegroundColor Cyan
    Start-Process http://localhost/install

    Write-Host "Dify deployment process completed." -ForegroundColor Green
    Write-Host "Please complete the Dify initial setup in your browser and configure the Ollama model as per the requirements document." -ForegroundColor Yellow
}

# --- Script Entry Point ---

# Store original location
$originalLocation = Get-Location

try {
    # Get user input
    $ollamaHostInput = Read-Host -Prompt "Enter the Ollama service address (e.g., http://192.168.1.100:11434, leave blank for default)"
    $appKeyInput = Read-Host -Prompt "Enter the Dify APP_KEY (a random string is recommended, leave blank to auto-generate)"
    $secretKeyInput = Read-Host -Prompt "Enter the Dify SECRET_KEY (a random string is recommended, leave blank to auto-generate)"

    # Set default values if input is empty
    $ollamaHost = if ([string]::IsNullOrWhiteSpace($ollamaHostInput)) { "http://192.168.1.100:11434" } else { $ollamaHostInput }
    $appKey = if ([string]::IsNullOrWhiteSpace($appKeyInput)) { (New-Guid).ToString() } else { $appKeyInput }
    $secretKey = if ([string]::IsNullOrWhiteSpace($secretKeyInput)) { (New-Guid).ToString() } else { $secretKeyInput }

    # Call the deployment function with the parameters
    Start-DifyDeployment -OllamaHost $ollamaHost -AppKey $appKey -SecretKey $secretKey
}
finally {
    # Restore the original location
    Set-Location $originalLocation
    Write-Host "Script execution finished." -ForegroundColor Green
}