import vertexai
from vertexai.preview import reasoning_engines
import subprocess

def get_token():
    return subprocess.check_output(["gcloud", "auth", "print-access-token"], shell=True).decode("utf-8").strip()

vertexai.init(project="168460245545", location="us-west1")

engine_id = "7750563017309290496"
resource_name = f"projects/168460245545/locations/us-west1/reasoningEngines/{engine_id}"

print(f"Testing engine: {resource_name}")

engine = reasoning_engines.ReasoningEngine(resource_name)
print(f"GCA Resource: {engine.gca_resource}")
print(f"Available methods: {[m for m in dir(engine) if not m.startswith('_')]}")

try:
    print("Attempting .query()...")
    # Standard AdkApp might use .run() or .query()
    # If it's a custom class, it uses the method name.
    result = engine.query(
        message="I have 20 crates of tomatoes near Banda",
        user_id="test",
        session_id="test"
    )
    print("Query success!")
    print(result)
except Exception as e:
    print(f"Query failed: {e}")
    try:
        print("Attempting .run()...")
        result = engine.run(
            message="I have 20 crates of tomatoes near Banda",
            user_id="test",
            session_id="test"
        )
        print("Run success!")
        print(result)
    except Exception as e2:
        print(f"Run failed: {e2}")
