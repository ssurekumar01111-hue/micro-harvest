import os
from dotenv import load_dotenv
import vertexai
from vertexai.preview import reasoning_engines

load_dotenv("functions/.env")

PROJECT = os.getenv("AGENT_PROJECT", "micro-harvest")
REGION = os.getenv("AGENT_REGION", "us-west1")
AGENT_ID = os.getenv("AGENT_ID", "")
STAGING_BUCKET = f"gs://{PROJECT}-vertex-staging-{os.getenv('AGENT_PROJECT_NUMBER', '')}"

vertexai.init(project=PROJECT, location=REGION, staging_bucket=STAGING_BUCKET)

class MicroHarvestEngine:
    """Micro-Harvest agent — lazy ADK init to avoid set_up() failures."""

    def set_up(self):
        """Minimal setup — just store config. No ADK imports here."""
        import os
        os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "1"
        os.environ["GOOGLE_CLOUD_PROJECT"] = os.getenv("AGENT_PROJECT_NUMBER", "micro-harvest")
        os.environ["GOOGLE_CLOUD_LOCATION"] = os.getenv("AGENT_REGION", "us-west1")
        self._initialized = False
        self._runner = None
        self._session_service = None
        print("[MicroHarvest] set_up complete")

    def _initialize(self):
        """Lazy init — called on first query only."""
        if self._initialized:
            return

        import os
        os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "1"
        os.environ["GOOGLE_CLOUD_PROJECT"] = os.getenv("AGENT_PROJECT_NUMBER", "micro-harvest")
        os.environ["GOOGLE_CLOUD_LOCATION"] = os.getenv("AGENT_REGION", "us-west1")

        from google.adk.agents import LlmAgent
        from google.adk.tools.mcp_tool.mcp_toolset import McpToolset
        from google.adk.tools.mcp_tool.mcp_session_manager import StreamableHTTPConnectionParams
        from google.adk.runners import Runner
        from google.adk.sessions import InMemorySessionService

        mcp_toolset = McpToolset(
            connection_params=StreamableHTTPConnectionParams(
                url="https://asia-south1-micro-harvest.cloudfunctions.net/mcpProxy",
            )
        )

        agent = LlmAgent(
            name="micro_harvest",
            model="gemini-2.5-flash",
            description="Micro-Harvest agricultural logistics agent",
            instruction="""You are the Micro-Harvest logistics intelligence agent.
When given a crop listing return JSON with:
- weatherRisk (LOW/MEDIUM/HIGH)
- perishabilityRisk (LOW/MEDIUM/HIGH)
- recommendedVehicle (REFRIGERATED/FLATBED/STANDARD)
- urgencyBoost (0-20)
- matchedTransporterIds": [],
- reasoning (2 sentences)
Use find_nearby_transporters tool to locate transporters.""",
            tools=[mcp_toolset],
        )

        self._session_service = InMemorySessionService()
        self._runner = Runner(
            agent=agent,
            app_name="micro_harvest",
            session_service=self._session_service,
        )
        self._initialized = True
        print("[MicroHarvest] ADK initialized on first query")

    def query(self, message: str, user_id: str = "user1", session_id: str = None) -> dict:
        """Handle logistics query."""
        import asyncio
        import uuid

        self._initialize()
        session_id = session_id or str(uuid.uuid4())

        async def _run():
            session = await self._session_service.create_session(
                app_name="micro_harvest",
                user_id=user_id,
                session_id=session_id,
            )
            from google.genai.types import Part, Content
            response_text = ""
            tool_calls = 0

            async for event in self._runner.run_async(
                user_id=user_id,
                session_id=session.id,
                new_message=Content(
                    role="user",
                    parts=[Part(text=message)]
                ),
            ):
                if event.is_final_response():
                    if event.content and event.content.parts:
                        response_text = event.content.parts[0].text or ""
                if hasattr(event, 'get_function_calls') and event.get_function_calls():
                    tool_calls += len(event.get_function_calls())

            return {
                "response": response_text,
                "tool_calls": float(tool_calls),
                "session_id": session_id,
            }

        try:
            return asyncio.run(_run())
        except RuntimeError:
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                future = pool.submit(asyncio.run, _run())
                return future.result(timeout=60)
        except Exception as e:
            return {
                "response": f"Error: {str(e)}",
                "tool_calls": 0.0,
                "session_id": session_id,
            }

def deploy_agent():
    """Deploy agent only if AGENT_ID is not already set in .env"""
    
    if AGENT_ID:
        print(f"[agent.py] Agent already deployed: {AGENT_ID}")
        print(f"[agent.py] Skipping deployment. Delete AGENT_ID from .env to force redeploy.")
        return AGENT_ID

    print("[agent.py] No AGENT_ID found. Creating new agent runtime...")
    
    remote_app = reasoning_engines.ReasoningEngine.create(
        MicroHarvestEngine(),
        requirements=[
            "google-adk>=1.0.0",
            "google-cloud-aiplatform",
            "mcp",
        ],
        display_name="Micro-Harvest Agent",
        description="Agricultural surplus marketplace logistics agent",
    )
    
    new_id = remote_app.resource_name.split("/")[-1]
    print(f"[agent.py] New agent created: {new_id}")
    print(f"[agent.py] Add this to functions/.env: AGENT_ID={new_id}")
    
    # Auto-update .env with new ID
    env_path = "functions/.env"
    with open(env_path, "r") as f:
        content = f.read()
    if "AGENT_ID=" in content:
        import re
        content = re.sub(r"AGENT_ID=.*", f"AGENT_ID={new_id}", content)
    else:
        content += f"\nAGENT_ID={new_id}"
    with open(env_path, "w") as f:
        f.write(content)
    print(f"[agent.py] Updated functions/.env with new AGENT_ID")
    
    return new_id

if __name__ == "__main__":
    deploy_agent()
