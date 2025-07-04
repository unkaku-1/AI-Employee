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

This completes the foundational step of creating and integrating a custom tool, paving the way for the more advanced agent capabilities outlined in the roadmap.