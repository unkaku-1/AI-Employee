import requests
import json
import sys

def send_teams_message(webhook_url, message):
    """
    Sends a message to a Microsoft Teams channel using an Incoming Webhook.
    :param webhook_url: The Teams Incoming Webhook URL.
    :param message: The message content to send.
    :return: The HTTP response status code, or None if an error occurs.
    """
    payload = {
        "text": message
    }
    headers = {
        "Content-Type": "application/json"
    }
    try:
        response = requests.post(webhook_url, data=json.dumps(payload), headers=headers)
        response.raise_for_status()  # Raises an HTTPError for bad responses (4xx or 5xx)
        print(f"Message sent successfully. Status code: {response.status_code}")
        return response.status_code
    except requests.exceptions.RequestException as e:
        print(f"Failed to send message: {e}")
        return None

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python send_teams_message.py <webhook_url> <message>")
        sys.exit(1)

    webhook_url_arg = sys.argv[1]
    message_arg = sys.argv[2]

    status_code = send_teams_message(webhook_url_arg, message_arg)
    if status_code:
        print("Teams notification sent successfully.")
    else:
        print("Failed to send Teams notification.")