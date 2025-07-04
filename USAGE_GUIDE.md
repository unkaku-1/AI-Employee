# AI Employee - Usage Guide

This document provides a step-by-step guide to using the deployed FastGPT and Dify platforms. It is structured according to the phases outlined in the `AI_AGENT_ROADMAP.md` to help you progressively build and enhance your AI agent's capabilities.

---

## Prerequisites

Before you begin, ensure that you have successfully run the `deploy_all_in_one.ps1` script.
- **FastGPT** should be running and accessible at `http://localhost:3001`.
- **Dify** should be running and accessible at `http://localhost:8080`.
- You have completed the Dify installation wizard at `http://localhost:8080/install` and have your admin credentials.

---

## Phase 1: Foundational Setup - Your First AI Application

This phase focuses on connecting both platforms to a local Large Language Model (LLM) using Ollama and creating a basic chat application.

### 1.1. Prepare the Language Model with Ollama

First, we need a model for our platforms to use. We'll use Ollama to download and serve a lightweight, powerful model.

1.  **Open PowerShell or another terminal.**
2.  Pull the `llama3` model (this is a good starting model):
    ```bash
    ollama run llama3
    ```
3.  Once the download is complete, Ollama will be serving the model. By default, it's accessible at `http://localhost:11434` from your host machine.

    **Important for Docker:** Inside a Docker container, `localhost` refers to the container itself, not the host machine. To allow Docker containers (like FastGPT and Dify) to connect to Ollama running on the host, we must use the special address `http://host.docker.internal:11434`.

### 1.2. Configure FastGPT with Ollama

1.  **Log in to FastGPT**:
    -   Go to `http://localhost:3001`.
    -   Username: `root`
    -   Password: `1234`

2.  **Navigate to LLM Models**:
    -   On the left-hand menu, click on `System Config`.
    -   Select the `LLM Models` tab.

3.  **Add the Ollama Model**:
    -   Click the `+ Add Model` button.
    -   Fill in the form:
        -   **Model Name**: `Ollama Llama3` (You can name it anything).
        -   **Model Type**: `Ollama`
        -   **Base URL**: `http://host.docker.internal:11434` (This is crucial for connecting from Docker).
        -   **Model**: `llama3:latest`
        -   **Max Tokens**: `8192` (This is the context window for Llama3).
    -   Click `Save`.

4.  **Create and Test a Simple Application**:
    -   Go to the `Apps` section from the left menu.
    -   Click `+ Create New App`.
    -   Give it a name, like `My First Chatbot`.
    -   In the app's workflow editor, ensure the AI node is configured to use your new `Ollama Llama3` model.
    -   Click `Publish` and test the chat functionality in the right-hand debug panel.

### 1.3. Configure Dify with Ollama

1.  **Log in to Dify**:
    -   Go to `http://localhost:8080` and log in with the admin account you created.

2.  **Navigate to Model Providers**:
    -   Click on `Settings` in the bottom-left corner.
    -   Go to `Model Providers`.

3.  **Add Ollama**:
    -   Find `Ollama` in the list and click `Add`.
    -   In the modal, fill in the details:
        -   **Model Name**: `llama3` (It's best to use the actual model ID).
        -   **Base URL**: `http://host.docker.internal:11434`
    -   Click `Save`. Dify will validate the connection.

4.  **Create and Test a Simple Application**:
    -   From the `Studio` section, click `Create New App`.
    -   Choose `Chat App`.
    -   In the app's `Prompt Eng.` section, select `llama3` as the model.
    -   You can now test the chat on the right side.

---

## Phase 2: Building and Using the First Tool

In this phase, we will bring the `send_teams_message.py` script to life by exposing it as an API and then integrating it into Dify as a usable tool.

### 2.1. Understanding the Tool API

The project now includes a `tools` directory containing:
- `tool_api.py`: A FastAPI server that exposes our Python scripts as API endpoints.
- `Dockerfile`: Instructions to build a Docker container for our Tool API.
- `requirements.txt`: Python dependencies for the API server.
- `manifest.json`: A Dify-compatible manifest describing the tools.

The `docker-compose-pgvector.yml` file has been updated to include this `tool-api` as a service, which will be built and run alongside FastGPT.

### 2.2. Building and Running the Tool Container

The one-click deployment script `deploy_all_in_one.ps1` already handles this. When you run it, it will automatically:
1.  Build the Docker image for the `tool-api` service using the `tools/Dockerfile`.
2.  Run the container, making the API available at `http://localhost:8001`.

Let's restart our services to build and launch the new tool API.
1.  Open PowerShell.
2.  Navigate to `C:\projects\AI-Employee\FastGPT\deploy\docker`.
3.  Run the command: `docker compose -f docker-compose-pgvector.yml up -d --build`
    - The `--build` flag is important; it tells Docker Compose to build the new `tool-api` image.

### 2.3. Integrating the Tool into Dify

Once the services are running, you can add the entire tool collection to Dify with a single step.

1.  **Log in to Dify** at `http://localhost:8080`.
2.  Navigate to **Tools**.
3.  Click **Import from URL**.
4.  Paste the URL to the manifest file. Since the Tool API container is running within the Docker network, Dify can access it directly via its service name and port.
    - **URL**: `http://tool-api:8001/manifest.json`
5.  Click **Import**. Dify will fetch the manifest, parse the OpenAPI spec (`openapi.json`), and automatically create a tool for the `send-teams-message` endpoint.

### 2.4. Using the Tool in a Dify Agent

Now you can create a new Dify application and use your custom tool.

1.  In Dify Studio, create a new **Agent App**.
2.  In the **Prompt** section, add the `send-teams-message` tool to your agent.
3.  Start a chat with your agent and give it a command like:
    > "Send a message to the project channel. The webhook URL is <your_teams_webhook_url> and the message is 'Hello from your new AI Employee!'"
4.  The agent will recognize the task, populate the parameters for your tool, and ask for your confirmation before running it. Upon approval, the FastAPI server will execute the Python script, and the message will appear in your Teams channel.

---

## Phase 3: The "Self-Growing" Agent - Creating a Code Generator

This phase is a major step towards the vision outlined in the roadmap. We will create a "meta-tool" - an AI agent whose sole purpose is to write new tools for itself.

### 3.1. Create the "Coder Agent" in Dify

1.  In Dify Studio, click **Create New App**.
2.  Choose **Agent App** and give it a name, for example, `Tool Coder Agent`.
3.  Go to the **Prompt** section for this new agent.

### 3.2. Design the Master Prompt

This is the most critical part. Copy and paste the following text into the prompt editor. This prompt defines the agent's identity, its goal, its constraints, and the exact format for its output.

```text
# Role: Python Tool Developer

## Profile
You are an expert Python developer specializing in creating simple, single-purpose, and secure server-side tools. You are a component of a larger AI system. Your primary function is to write Python code for new tools that will be executed by other agents.

## Goal
Your goal is to generate a single, complete Python script based on a user's request. This script must be runnable and self-contained.

## Constraints
1.  **Security First**: You MUST NOT use any libraries that access the local file system (`os`, `pathlib`), execute arbitrary system commands (`subprocess`, `os.system`), or make network requests to local addresses. Only use standard libraries and approved third-party packages like `requests`.
2.  **Simplicity**: The generated code must be for a single, well-defined task. Do not create complex, multi-functional scripts.
3.  **Stateless**: The tool must be stateless. It should not save any information or state between executions.
4.  **Dependencies**: If the script requires third-party libraries (e.g., `requests`, `beautifulsoup4`), you must explicitly list them.
5.  **Output Format**: You MUST wrap your final output in a single JSON object. The JSON object must contain two keys: `python_code` (a string containing the full Python script) and `requirements` (a list of strings, where each string is a required package for pip install).

## Example
### User Request:
Create a tool to get the current price of Bitcoin in USD.

### Your Output:
```json
{
  "python_code": "import requests\n\ndef get_bitcoin_price():\n    \"\"\"Fetches the current price of Bitcoin in USD from the CoinGecko API.\"\"\"\n    try:\n        url = 'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd'\n        response = requests.get(url, timeout=10)\n        response.raise_for_status()\n        price_data = response.json()\n        price = price_data.get('bitcoin', {}).get('usd')\n        if price:\n            return f\"The current price of Bitcoin is ${price} USD.\"\n        else:\n            return \"Could not find the price in the API response.\"\n    except requests.exceptions.RequestException as e:\n        return f\"Error fetching Bitcoin price: {e}\"
\n# To test, you can run:\n# if __name__ == '__main__':\n#     print(get_bitcoin_price())",
  "requirements": [
    "requests"
  ]
}
```

## Your Task
Now, based on the user's request, generate the Python script and its dependencies in the specified JSON format.
```

### 3.3. Configure and Test the Coder Agent

1.  **Set the Model**: For this task, a more powerful model is recommended. If you have access to a GPT-4 level model via an API key, configure it in Dify and select it for this agent. If not, `llama3` can still perform well but may require more precise instructions.
2.  **Save and Chat**: Save the prompt. Now, open the chat panel for your `Tool Coder Agent`.
3.  **Give it a Task**: Give it a simple task that requires a new tool. For example:
    > "I need a tool that takes a text string as input and returns the number of words in it."
4.  **Review the Output**: The agent should respond with a JSON object containing the Python code for a word-counting function and an empty list for requirements, just like you instructed in the prompt.

You have now created an agent that can write new tools. The next step in the roadmap is to build the approval service that can take this generated code, get it approved, and automatically add it to your tool library.
