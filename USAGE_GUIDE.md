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

## Phase 2: Knowledge Base Integration

Now, let's give our AI a memory by creating a knowledge base in FastGPT.

1.  **Create a Dataset in FastGPT**:
    -   In FastGPT, go to the `Datasets` section.
    -   Click `+ Create New Dataset`.
    -   Name it `Project Documents`.

2.  **Upload a Document**:
    -   Click on the newly created dataset.
    -   Choose the `File` import method.
    -   Upload a simple `.txt` or `.md` file containing some project information. For example, create a `project_A_status.txt` with the content: "Project A is currently in the final testing phase. The project manager is Alice. The expected delivery date is next Friday."
    -   FastGPT will automatically process and vectorize the document.

3.  **Link Dataset to Your Application**:
    -   Go back to your `My First Chatbot` application.
    -   In the workflow editor, connect the `Dataset Search` node to your `Project Documents` dataset.
    -   Ensure the output of the `Dataset Search` node feeds into the `AI` node's context.
    -   Publish the changes.

4.  **Test the Knowledge Base**:
    -   Open the chat for your application.
    -   Ask a question based on the document you uploaded, such as: "What is the status of Project A?" or "Who is the project manager for Project A?".
    -   The AI should now be able to answer using the information from the document.

---

## Phase 3: Advanced Agent Capabilities (Vision for the Future)

This phase, as outlined in the roadmap, involves evolving the system from a simple Q&A bot to a true agent that can create its own tools.

### 3.1. The Goal: Self-Growing Tools

The vision is to create a "Meta-Tool" in Dify. When the AI needs to perform a task for which no tool exists (e.g., "check the current price of Bitcoin"), it won't fail. Instead, it will call this Meta-Tool with a clear objective: "Create a Python tool that calls a public API to get the current price of Bitcoin."

### 3.2. Implementation Sketch (As per Roadmap)

1.  **Code Generation Tool**: This will be an advanced Dify workflow that takes a natural language goal and uses a powerful LLM (like GPT-4 or a fine-tuned local model) with a carefully crafted prompt to write Python or PowerShell script code.
2.  **Approval Workflow**: The generated code is not run immediately. It is sent to an approval service. This service:
    -   Runs a security scan (e.g., `Bandit` for Python).
    -   Sends a message to a Teams channel with the code and "Approve" / "Deny" buttons.
3.  **Dynamic Tool Library**: Upon approval, the new script is saved to a designated `tools` directory, and a `manifest.json` file is updated with the tool's name, description, and parameters. Dify is configured to dynamically read from this manifest, making the new tool instantly available.

---

## Phase 4: Enterprise Integration & Automation

This phase focuses on connecting the AI agent to real-world enterprise tools.

### 4.1. Using the Teams Notification Tool

The project already includes a `send_teams_message.py` script. Here’s how it would be integrated into a Dify workflow:

1.  **Expose the Script as an API**: Wrap the Python script in a simple web framework like FastAPI or Flask. This API should accept a `message` and a `webhook_url` as input.
2.  **Create a Tool in Dify**: In Dify, go to `Tools` -> `Create New Tool`.
3.  **Configure the Tool**:
    -   Point it to the API endpoint you created (e.g., `http://my-api-server/send-teams-message`).
    -   Define the input parameters (`message`, `webhook_url`).
    -   Provide a clear description so the AI knows when to use it (e.g., "Use this tool to send a notification message to a Microsoft Teams channel").
4.  **Use in an Agent**: Now, when building an agent in Dify, you can simply add this tool. When a user asks to "notify the project manager," the agent will know to use this tool, ask for the message content, and execute the action.

This guide provides the foundational steps to get started and a clear vision for evolving your AI Employee. The next steps involve implementing the advanced concepts from Phases 3 and 4.
