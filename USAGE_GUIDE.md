# AI 数字员工 - 使用指南

本文档为已部署的 FastGPT 和 Dify 平台提供了一份分步使用指南。其结构与 `AI_AGENT_ROADMAP.md` 中规划的阶段保持一致，旨在帮助您逐步构建和增强您的 AI 智能体。

---

## 前提条件

在开始之前，请确保您已成功运行 `deploy_all_in_one.ps1` 脚本。
- **FastGPT** 应已成功运行，并可通过 `http://localhost:3001` 访问。
- **Dify** 应已成功运行，并可通过 `http://localhost:8080` 访问。
- 您应已在 `http://localhost:8080/install` 完成了 Dify 的安装向导，并拥有管理员凭据。

---

## 阶段一：夯实基础 - 你的第一个 AI 应用

本阶段专注于将两个平台连接到本地的大语言模型（LLM），并创建一个基础的聊天应用。

### 1.1. 使用 Ollama 准备语言模型

首先，我们需要一个模型供平台使用。我们将使用 Ollama 来下载并运行一个轻量级但功能强大的模型。

1.  **打开 PowerShell 或其他终端。**
2.  拉取 `llama3` 模型（这是一个很好的入门模型）：
    ```bash
    ollama run llama3
    ```
3.  下载完成后，Ollama 将自动在后台提供模型服务。默认情况下，您可以从您的主机（即您的 Windows 电脑）通过 `http://localhost:11434` 访问它。

    **Docker 环境下的重要提示：** 在 Docker 容器内部，`localhost` 指的是容器自身，而不是您的主机。为了让 Docker 容器（如 FastGPT 和 Dify）能够连接到在主机上运行的 Ollama，我们必须使用一个特殊的地址：`http://host.docker.internal:11434`。

### 1.2. 在 FastGPT 中配置 Ollama

1.  **登录 FastGPT**:
    -   访问 `http://localhost:3001`。
    -   用户名: `root`
    -   密码: `1234`

2.  **导航到语言模型设置**:
    -   在左侧菜单中，点击 `系统配置`。
    -   选择 `大模型` 标签页。

3.  **添加 Ollama 模型**:
    -   点击 `+ 新建模型` 按钮。
    -   填写表单：
        -   **模型名称**: `Ollama Llama3` (您可以随意命名)。
        -   **模型类型**: `Ollama`
        -   **Base URL**: `http://host.docker.internal:11434` (这是从 Docker 内部连接的关键)。
        -   **模型**: `llama3:latest`
        -   **最大 Tokens**: `8192` (这是 Llama3 的上下文窗口大小)。
    -   点击 `保存`。

4.  **创建并测试一个简单的应用**:
    -   从左侧菜单进入 `应用` 部分。
    -   点击 `+ 新建应用`。
    -   给它一个名字，例如 `我的第一个聊天机器人`。
    -   在应用的工作流编辑器中，确保 AI 节点配置为使用您刚刚添加的 `Ollama Llama3` 模型。
    -   点击 `发布` 并在右侧的调试面板中测试聊天功能。

### 1.3. 在 Dify 中配置 Ollama

1.  **登录 Dify**:
    -   访问 `http://localhost:8080` 并用您创建的管理员账号登录。

2.  **导航到模型供应商**:
    -   点击左下角的 `设置`。
    -   进入 `模型供应商`。

3.  **添加 Ollama**:
    -   在列表中找到 `Ollama` 并点击 `添加`。
    -   在弹出的窗口中填写信息：
        -   **模型名称**: `llama3` (建议使用实际的模型 ID)。
        -   **Base URL**: `http://host.docker.internal:11434`
    -   点击 `保存`。Dify 会验证连接是否成功。

4.  **创建并测试一个简单的应用**:
    -   从 `工作室` 部分，点击 `创建应用`。
    -   选择 `聊天机器人` 类型。
    -   在应用的 `提示词编排` 部分，选择 `llama3` 作为模型。
    -   现在您可以在右侧与您的应用进行聊天测试。

---

## 阶段二：构建并使用第一个工具

在本阶段，我们将把项目中的 `send_teams_message.py` 脚本通过 API 的方式暴露出来，并将其作为一个可用的工具集成到 Dify 中。

### 2.1. 理解工具 API

现在，项目根目录下的 `tools` 文件夹包含了以下文件：
- `tool_api.py`: 一个 FastAPI 服务，它将我们的 Python 脚本功能暴露为 API 接口。
- `Dockerfile`: 用于为我们的工具 API 构建 Docker 镜像的指令文件。
- `requirements.txt`: API 服务所需的 Python 依赖包。
- `manifest.json`: 一个 Dify 兼容的清单文件，用于描述这些工具。

`FastGPT/deploy/docker/docker-compose-pgvector.yml` 文件也已被更新，将这个 `tool-api` 添加为一个服务，使其可以和 FastGPT 一同被构建和启动。

### 2.2. 构建并运行工具容器

一键部署脚本 `deploy_all_in_one.ps1` 已经处理了此步骤。当您运行它时，它会自动：
1.  使用 `tools/Dockerfile` 为 `tool-api` 服务构建 Docker 镜像。
2.  运行该容器，并通过 `http://localhost:8001` 提供 API 服务。

让我们重启我们的服务来构建并启动这个新的工具 API。
1.  打开 PowerShell。
2.  导航到 `C:\projects\AI-Employee\FastGPT\deploy\docker` 目录。
3.  运行命令: `docker compose -f docker-compose-pgvector.yml up -d --build`
    -   `--build` 参数非常重要，它会告诉 Docker Compose 去构建新的 `tool-api` 镜像。

### 2.3. 将工具集成到 Dify

当所有服务运行后，您只需一步即可将整个工具集添加到 Dify。

1.  **登录 Dify** (`http://localhost:8080`)。
2.  导航到 **工具**。
3.  点击 **从 URL 导入**。
4.  粘贴指向清单文件的 URL。由于工具 API 容器正在 Docker 网络内部运行，Dify 可以通过其服务名称和端口直接访问它。
    - **URL**: `http://tool-api:8001/manifest.json`
5.  点击 **导入**。Dify 将获取清单文件，解析其 OpenAPI 规范 (`openapi.json`)，并为 `send-teams-message` 接口自动创建一个工具。

### 2.4. 在 Dify 智能体中使用工具

现在，您可以创建一个新的 Dify 应用并使用您的自定义工具了。

1.  在 Dify 工作室中，创建一个新的 **智能体 (Agent) 应用**。
2.  在 **提示词** 部分，将 `send-teams-message` 工具添加到您的智能体中。
3.  与您的智能体开始聊天，并给它一个指令，例如：
    > “给项目频道发送一条消息。webhook URL 是 <你的Teams webhook_url>，消息内容是‘大家好，我是你们的新 AI 数字员工！’”
4.  智能体将识别出这个任务，为您的工具填充好参数，并在运行前请求您的确认。一旦批准，FastAPI 服务将执行 Python 脚本，相应的消息就会出现在您的 Teams 频道中。

---

## 阶段三：“自我成长”的智能体 - 创建代码生成器

这个阶段是实现路线图愿景的关键一步。我们将创建一个“元工具”——一个其唯一目的是为自己编写新工具的 AI 智能体。

### 3.1. 在 Dify 中创建“代码智能体”

1.  在 Dify 工作室中，点击 **创建应用**。
2.  选择 **智能体 (Agent) 应用** 并为其命名，例如 `Tool Coder Agent` (工具代码生成器)。
3.  进入这个新智能体的 **提示词** 编辑区。

### 3.2. 设计核心提示词 (Master Prompt)

这是最关键的部分。复制以下文本并粘贴到提示词编辑器中。这个提示词定义了智能体的身份、目标、约束以及其输出的确切格式。

```text
# 角色: Python 工具开发者

## 个人简介
你是一名专业的 Python 开发者，专注于创建简单的、单一用途的、安全的服务器端工具。你是一个更庞大的 AI 系统的一个组件。你的主要职责是根据用户的请求，为其他智能体编写可执行的 Python 工具代码。

## 目标
你的目标是根据用户的请求，生成一个单一、完整、可运行且自包含的 Python 脚本。

## 约束
1.  **安全第一**: 你绝对不能使用任何访问本地文件系统（如 `os`, `pathlib`）、执行任意系统命令（如 `subprocess`, `os.system`）或向本地地址发出网络请求的库。只允许使用标准库和经过批准的第三方包，如 `requests`。
2.  **简单性**: 生成的代码必须用于一个定义明确的单一任务。不要创建复杂、多功能的脚本。
3.  **无状态**: 工具必须是无状态的。它不应在多次执行之间保存任何信息或状态。
4.  **依赖项**: 如果脚本需要第三方库（例如 `requests`, `beautifulsoup4`），你必须明确地列出它们。
5.  **输出格式**: 你必须将最终输出包裹在一个单一的 JSON 对象中。该 JSON 对象必须包含两个键：`python_code`（一个包含完整 Python 脚本的字符串）和 `requirements`（一个字符串列表，其中每个字符串都是一个需要 pip install 的包）。

## 示例
### 用户请求:
创建一个工具，用于获取比特币的当前美元价格。

### 你的输出:
```json
{
  "python_code": "import requests\n\ndef get_bitcoin_price():\n    \"\"\"Fetches the current price of Bitcoin in USD from the CoinGecko API.\"\"\"\n    try:\n        url = 'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd'\n        response = requests.get(url, timeout=10)\n        response.raise_for_status()\n        price_data = response.json()\n        price = price_data.get('bitcoin', {}).get('usd')\n        if price:\n            return f\"The current price of Bitcoin is ${price} USD.\"\n        else:\n            return \"Could not find the price in the API response.\"\n    except requests.exceptions.RequestException as e:\n        return f\"Error fetching Bitcoin price: {e}\"\n\n# To test, you can run:\n# if __name__ == '__main__':\n#     print(get_bitcoin_price())",
  "requirements": [
    "requests"
  ]
}
```

## 你的任务
现在，请根据用户的请求，按照指定的 JSON 格式生成 Python 脚本及其依赖项。
```

### 3.3. 配置并测试代码智能体

1.  **设置模型**: 对于这个任务，推荐使用更强大的模型。如果您有权访问 GPT-4 级别的模型 API，请在 Dify 中配置并为此智能体选用它。如果没有，`llama3` 也能表现不错，但可能需要更精确的指令。
2.  **保存并聊天**: 保存提示词。现在，打开 `Tool Coder Agent` 的聊天面板。
3.  **分配任务**: 给它一个需要新工具的简单任务。例如：
    > “我需要一个工具，它接收一个文本字符串作为输入，并返回其中的单词数量。”
4.  **审查输出**: 智能体应该会按照您在提示词中的指示，返回一个包含单词计数 Python 函数代码和空依赖列表的 JSON 对象。

您现在已经成功创建了一个可以编写新工具的智能体。路线图的下一步是构建审批服务，该服务可以接收生成的代码，在获得批准后，自动将其添加到您的工具库中。