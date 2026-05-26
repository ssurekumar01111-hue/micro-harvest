import vertexai
from vertexai.preview import reasoning_engines

vertexai.init(project="168460245545", location="us-west1")

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
