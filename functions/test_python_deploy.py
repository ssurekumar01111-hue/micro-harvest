import vertexai
from vertexai.preview import reasoning_engines

import os
from dotenv import load_dotenv
load_dotenv("functions/.env")

vertexai.init(project=os.getenv("AGENT_PROJECT_NUMBER"), location="us-west1")

class MicroHarvestAgent:
    def query(self, message: str, **kwargs):
        """Mock agent for testing deployment updates."""
        return f"Received: {message}"

try:
    # Update existing reasoning engine with agent code
    agent = reasoning_engines.ReasoningEngine.create(
        MicroHarvestAgent(),
        display_name="micro-harvest-python-test",
    )
    print("New Engine created:", agent.resource_name)
except Exception as e:
    print(f"Error: {e}")
