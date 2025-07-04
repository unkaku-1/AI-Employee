# tool_api.py
import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import requests
import json

# --- Data Models for API ---
class TeamsMessage(BaseModel):
    webhook_url: str
    message: str

# --- FastAPI App Initialization ---
app = FastAPI(
    title="AI Employee Tools API",
    description="An API server to provide tools for AI agents like Dify.",
    version="1.0.0"
)

# --- Core Tool Logic ---
def send_teams_message(webhook_url: str, message: str):
    """
    Sends a message to a Microsoft Teams channel using an incoming webhook.
    """
    headers = {'Content-Type': 'application/json'}
    payload = {'text': message}
    try:
        response = requests.post(webhook_url, data=json.dumps(payload), headers=headers, timeout=10)
        response.raise_for_status()  # Raise an exception for bad status codes (4xx or 5xx)
        return response.status_code
    except requests.exceptions.RequestException as e:
        print(f"Error sending Teams message: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to send message: {e}")

# --- API Endpoints ---
@app.post("/send-teams-message", summary="Send a message to a Teams channel")
def handle_send_teams_message(item: TeamsMessage):
    """
    Receives a webhook URL and a message, and sends it to the specified Teams channel.
    """
    print(f"Received request to send message: '{item.message}' to URL: {item.webhook_url[:30]}...")
    status_code = send_teams_message(webhook_url=item.webhook_url, message=item.message)
    return {"status": "success", "response_code": status_code}

@app.get("/", summary="API Health Check")
def read_root():
    """
    A simple health check endpoint.
    """
    return {"status": "AI Employee Tools API is running"}

# --- Main Execution ---
if __name__ == "__main__":
    # This allows running the API server directly for testing.
    # Use `uvicorn tool_api:app --host 0.0.0.0 --port 8001 --reload` to run.
    uvicorn.run(app, host="0.0.0.0", port=8001)
