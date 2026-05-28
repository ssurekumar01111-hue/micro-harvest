import os
import vertexai
from vertexai.preview import reasoning_engines

vertexai.init(project="micro-harvest", location="us-west1", staging_bucket="gs://micro-harvest-vertex-staging-168460245545")

class MicroHarvestEngine:
    def set_up(self):
        print("Set up called")

    def query(self, message: str, user_id: str = "user1", session_id: str = None) -> dict:
        return {
            "response": f"Echo: {message}",
            "tool_calls": 0.0,
            "session_id": session_id or "test",
        }

print("Deploying Minimal MicroHarvestEngine to Vertex AI...")

engine = reasoning_engines.ReasoningEngine.create(
    MicroHarvestEngine(),
    requirements=[
        "google-adk==2.1.0",
        "google-cloud-aiplatform",
    ],
    display_name="Micro-Harvest Agent Test",
    description="Test deployment",
)

print("Deployed! Resource name:", engine.resource_name)
