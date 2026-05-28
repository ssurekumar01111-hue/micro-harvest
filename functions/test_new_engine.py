import requests
import subprocess
import json

def get_token():
    return subprocess.check_output(["gcloud", "auth", "print-access-token"], shell=True).decode("utf-8").strip()

url = "https://us-west1-aiplatform.googleapis.com/v1/projects/168460245545/locations/us-west1/reasoningEngines/7750563017309290496:query"
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
