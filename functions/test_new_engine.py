import requests
import subprocess
import json

def get_token():
    return subprocess.check_output(["gcloud", "auth", "print-access-token"], shell=True).decode("utf-8").strip()

import os
from dotenv import load_dotenv
load_dotenv("functions/.env")

PROJECT_NUMBER = os.getenv("AGENT_PROJECT_NUMBER")
url = f"https://us-west1-aiplatform.googleapis.com/v1/projects/{PROJECT_NUMBER}/locations/us-west1/reasoningEngines/7750563017309290496:query"
token = get_token()

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

# Try without input wrapper first
payload = {
    "message": "I have 20 crates of tomatoes near Banda",
    "user_id": "test",
    "session_id": "test"
}

print(f"Testing URL: {url}")
print(f"Payload: {json.dumps(payload)}")

response = requests.post(url, headers=headers, json=payload)
print(f"Status Code: {response.status_code}")
print(f"Response Body: {response.text}")

if response.status_code == 400:
    print("\nRetrying with 'input' wrapper...")
    payload = {"input": payload}
    response = requests.post(url, headers=headers, json=payload)
    print(f"Status Code: {response.status_code}")
    print(f"Response Body: {response.text}")
