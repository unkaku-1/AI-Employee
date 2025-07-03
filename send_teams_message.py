
import requests
import json
import sys

def send_teams_message(webhook_url, message):
    """
    向Microsoft Teams发送消息。
    :param webhook_url: Teams Incoming Webhook URL。
    :param message: 要发送的消息内容。
    :return: HTTP响应状态码。
    """
    payload = {
        "text": message
    }
    headers = {
        "Content-Type": "application/json"
    }
    try:
        response = requests.post(webhook_url, data=json.dumps(payload), headers=headers)
        response.raise_for_status() # 如果请求失败，则抛出HTTPError
        print(f"消息发送成功，状态码: {response.status_code}")
        return response.status_code
    except requests.exceptions.RequestException as e:
        print(f"消息发送失败: {e}")
        return None

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("用法: python send_teams_message.py <webhook_url> <message>")
        sys.exit(1)

    webhook_url = sys.argv[1]
    message = sys.argv[2]

    status = send_teams_message(webhook_url, message)
    if status:
        print(f"Teams通知已发送。")
    else:
        print(f"Teams通知发送失败。")


