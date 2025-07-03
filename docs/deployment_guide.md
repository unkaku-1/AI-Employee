# FastGPT + Dify 私有化部署指南

本指南将详细介绍如何在 Windows 11 虚拟机环境中部署 FastGPT 和 Dify，并进行必要的配置。

## 1. 环境准备

在开始部署之前，请确保您的 Windows 11 虚拟机满足以下要求：

### 1.1 操作系统要求

- Windows 11 Pro 或 Windows Server 2022

### 1.2 软件安装

请确保已安装以下软件：

- **Git**: 用于克隆 FastGPT 和 Dify 的代码仓库。
  - 如果未安装，`deploy_fastgpt.ps1` 和 `deploy_dify.ps1` 脚本会尝试使用 `winget` 进行安装。如果 `winget` 不可用或安装失败，请手动下载并安装：[Git for Windows](https://git-scm.com/download/win)
- **Docker Desktop**: 用于运行 FastGPT 和 Dify 的容器化服务。
  - 确保 Docker Desktop 已安装并正在运行，且已启用 WSL2 后端。
  - 下载地址：[Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
- **WSL2 (Windows Subsystem for Linux 2)**: Docker Desktop 依赖 WSL2 运行 Linux 容器。
  - 确保 WSL2 已安装并设置为默认版本。您可以通过在 PowerShell 中运行 `wsl --install` 和 `wsl --set-default-version 2` 来安装和配置。

### 1.3 网络与安全配置

- **静态 IP 地址**: 建议为您的 Windows 11 虚拟机配置静态 IP 地址，例如 `192.168.1.100`。这有助于确保服务的稳定访问。
- **防火墙端口开放**: 确保 Windows 防火墙已开放以下端口，以便外部访问和内部组件通信：
  - `80` (HTTP)
  - `443` (HTTPS)
  - `11434` (Ollama)
  - `5432` (PostgreSQL)
  - `27017` (MongoDB)
  - `6080` (Weaviate)
  - 您可以通过“Windows Defender 防火墙”的“高级设置”中添加“入站规则”来开放这些端口。
- **SSL 证书配置**: 如果您计划使用 HTTPS 访问 FastGPT 和 Dify，请准备好您的 SSL 证书 (`server.crt` 和 `server.key`)，并将其放置在虚拟机内的某个目录（例如 `C:\certs`）。后续在配置 Nginx 反向代理时会用到。

## 2. 部署 FastGPT

我们将使用 `deploy_fastgpt.ps1` 脚本来自动化 FastGPT 的部署过程。

### 2.1 运行部署脚本

1.  **打开 PowerShell**：以管理员身份运行 PowerShell。
2.  **导航到脚本目录**：使用 `cd` 命令导航到您存放 `deploy_fastgpt.ps1` 脚本的目录。
3.  **执行脚本**：运行以下命令启动部署过程：
    ```powershell
    .\deploy_fastgpt.ps1
    ```
4.  **输入配置信息**：脚本会提示您输入以下信息：
    -   **PostgreSQL 数据库密码**: 为 FastGPT 的 PostgreSQL 数据库设置一个强密码。
    -   **MongoDB 数据库密码**: 为 FastGPT 的 MongoDB 数据库设置一个强密码。
    -   **Ollama 服务地址** (可选): 如果 Ollama 运行在非默认地址（`http://localhost:11434`），请在此处输入其完整地址。如果留空，将使用默认值。
    -   **JWT Secret** (可选): 为 FastGPT 设置一个 JWT 密钥。建议留空让脚本自动生成一个随机字符串。

脚本将自动完成以下步骤：
-   检查 Git、WSL2 和 Docker Desktop 的状态。
-   克隆 FastGPT 的 GitHub 仓库到当前目录下的 `FastGPT` 文件夹。
-   根据您的输入，配置 `FastGPT/.env` 文件。
-   拉取 FastGPT 及其依赖服务（PostgreSQL, MongoDB）所需的 Docker 镜像。
-   启动所有 FastGPT 服务。
-   尝试验证 FastGPT 服务的健康状态和数据库连接。

### 2.2 验证部署

-   脚本执行完成后，您可以通过浏览器访问 `http://localhost` (如果未配置 HTTPS 和域名) 来尝试访问 FastGPT 的 Web 界面。
-   您也可以在 PowerShell 中运行 `docker ps` 命令，查看 FastGPT 相关的容器是否都在运行中。

## 3. 部署 Dify

我们将使用 `deploy_dify.ps1` 脚本来自动化 Dify 的部署过程。

### 3.1 运行部署脚本

1.  **打开 PowerShell**：以管理员身份运行 PowerShell。
2.  **导航到脚本目录**：使用 `cd` 命令导航到您存放 `deploy_dify.ps1` 脚本的目录。
3.  **执行脚本**：运行以下命令启动部署过程：
    ```powershell
    .\deploy_dify.ps1
    ```
4.  **输入配置信息**：脚本会提示您输入以下信息：
    -   **Ollama 服务地址** (可选): 如果 Ollama 运行在非默认地址（`http://192.168.1.100:11434`），请在此处输入其完整地址。建议使用 WSL2 虚拟机的实际 IP 地址。
    -   **Dify APP_KEY** (可选): 为 Dify 设置一个 APP 密钥。建议留空让脚本自动生成一个随机字符串。
    -   **Dify SECRET_KEY** (可选): 为 Dify 设置一个 SECRET 密钥。建议留空让脚本自动生成一个随机字符串。

脚本将自动完成以下步骤：
-   检查 Git、WSL2 和 Docker Desktop 的状态。
-   克隆 Dify 的 GitHub 仓库到当前目录下的 `dify` 文件夹。
-   进入 `dify/docker` 目录。
-   根据您的输入，配置 `dify/docker/.env` 文件。
-   拉取 Dify 及其依赖服务（Weaviate）所需的 Docker 镜像。
-   启动所有 Dify 服务。
-   自动打开浏览器导航到 Dify 的安装页面。

### 3.2 Dify 初始化配置

脚本会自动打开 Dify 的安装页面（通常是 `http://localhost/install`）。请按照页面提示完成以下操作：

1.  **创建管理员账户**：设置您的管理员邮箱和密码。
2.  **基本设置**：完成 Dify 的基本配置。

### 3.3 配置 Ollama 模型

Dify 启动并完成初始化后，您需要在 Dify 的管理界面中配置 Ollama 模型，以便 Dify 能够调用本地部署的大模型。

1.  **登录 Dify 管理界面**：使用您创建的管理员账户登录 Dify。
2.  **导航到“设置 > 模型供应商 > Ollama”**：在 Dify 的左侧菜单栏中找到“设置”或“系统设置”，然后选择“模型供应商”或“模型管理”，点击“Ollama”。
3.  **填写 Ollama 配置信息**：
    -   **模型名称**: 例如 `llava` (或其他您希望在 Dify 中使用的 Ollama 模型名称，请确保该模型已在您的 Ollama 服务中下载并可用)。
    -   **基础 URL**: 填写您在 `deploy_dify.ps1` 脚本中输入的 Ollama 服务地址，例如 `http://192.168.1.100:11434`。
    -   **模型类型**: 根据您使用的模型类型选择，例如 `对话`。
    -   **上下文长度**: 根据模型能力设置，例如 `4096`。
    -   **是否支持 Vision**: 如果您的 Ollama 模型支持多模态能力（如 LLaVA），请勾选此项。
    -   点击“保存”或“添加模型”。

## 4. 域账户集成 (LDAP)

### 4.1 FastGPT 域认证配置

FastGPT 支持通过修改 `config.json` 文件来集成 LDAP。

1.  **找到 `config.json` 文件**：通常位于 FastGPT 项目的根目录下。
2.  **编辑 `config.json`**：添加或修改 `ldap` 配置段，示例如下：
    ```json
    {
      "ldap": {
        "enable": true,
        "url": "ldap://ad.example.com:389",
        "bindDN": "CN=Admin,OU=Users,DC=example,DC=com",
        "bindCredentials": "password",
        "searchBase": "OU=Users,DC=example,DC=com",
        "searchFilter": "(sAMAccountName={{username}})",
        "adminFilter": "(memberOf=CN=FastGPTAdmins,OU=Groups,DC=example,DC=com)"
      }
    }
    ```
    -   请将示例中的 `ad.example.com`、`CN=Admin,OU=Users,DC=example,DC=com`、`password`、`OU=Users,DC=example,DC=com` 和 `CN=FastGPTAdmins,OU=Groups,DC=example,DC=com` 替换为您的实际 Active Directory 配置。
    -   `bindDN` 账户需要有查询 Active Directory 的权限。
3.  **重启 FastGPT 服务**：修改 `config.json` 后，需要重启 FastGPT 的应用程序容器以使配置生效：
    ```powershell
    cd FastGPT
    docker-compose restart app
    ```

### 4.2 Dify 域认证配置 (通过 Nginx 反向代理)

Dify 不直接支持 LDAP。建议通过在 Dify 前端部署 Nginx 反向代理，并结合 Nginx 的 LDAP 认证模块来实现域账户认证。

**此部分需要您自行配置 Nginx 和 LDAP 模块。请参考 `需求文档.md` 中“4.2 Dify 域认证配置”章节的详细说明和示例。**

## 5. Teams 集成

### 5.1 创建 Incoming Webhook

1.  **打开 Microsoft Teams**：登录您的 Teams 账户。
2.  **选择或创建频道**：导航到您希望接收通知的频道。
3.  **添加连接器**：在频道名称旁边点击“更多选项”(`...`)，选择“连接器”。
4.  **搜索并配置“Incoming Webhook”**：搜索并添加“Incoming Webhook”，点击“配置”。
5.  **命名并创建**：为 Webhook 命名（例如“FastGPT Alerts”或“Dify Notifications”），然后点击“创建”。
6.  **复制 Webhook URL**：复制生成的 Webhook URL 并妥善保存。此 URL 将用于发送消息。

### 5.2 配置通知脚本

#### 5.2.1 FastGPT 通知脚本

FastGPT 可以通过调用外部 Python 脚本来发送 Teams 通知。我们已为您提供了 `send_teams_message.py` 脚本。

-   **脚本位置**：`send_teams_message.py` 文件已包含在项目根目录中。
-   **如何使用**：您可以在 FastGPT 的自定义工作流或后端逻辑中调用此脚本。例如，在 PowerShell 或 WSL2 的 Linux 终端中测试：
    ```powershell
    python send_teams_message.py "<YOUR_TEAMS_WEBHOOK_URL>" "FastGPT 任务 [任务ID: 123] 已完成！"
    ```
    请将 `<YOUR_TEAMS_WEBHOOK_URL>` 替换为您实际的 Teams Webhook URL。

#### 5.2.2 Dify 通知配置

Dify 在其工作流中内置了“HTTP Request”节点，可以方便地发送 Teams 通知。

1.  **登录 Dify 管理界面**。
2.  **创建或编辑工作流**。
3.  **添加“HTTP Request”节点**：从工具箱中拖拽一个“HTTP Request”节点到工作流中。
4.  **配置“HTTP Request”节点**：
    -   **URL**: 粘贴您的 Teams Incoming Webhook URL。
    -   **Method**: 选择 `POST`。
    -   **Headers**: 添加 `Content-Type: application/json`。
    -   **Body**: 输入 JSON 内容，例如：
        ```json
        {
          "text": "Dify 工作流通知：{{execution_status}}"
        }
        ```
        您可以使用 `{{variable_name}}` 引用工作流中的变量。
5.  **保存并测试工作流**。

## 6. 后续优化方向

部署完成后，您可以考虑以下优化方向，以进一步提升平台的性能、可用性和管理效率：

-   **自动化部署**：进一步完善 PowerShell 脚本，实现更全面的自动化。
-   **模型管理**：集成 Hugging Face Hub，实现模型版本控制和自动化管理。
-   **高可用架构**：部署负载均衡和数据库主从复制，提高系统可用性。
-   **多租户支持**：为不同部门分配独立工作空间，隔离数据与权限。
-   **监控与告警**：引入 Prometheus + Grafana 等工具进行系统监控和告警。

更多详细信息，请参考 `需求文档.md`。


