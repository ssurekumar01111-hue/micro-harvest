import vertexai
from vertexai.preview import reasoning_engines

vertexai.init(project="168460245545", location="us-west1", staging_bucket="gs://micro-harvest-vertex-staging-168460245545")

class MicroHarvestEngine:
    """Custom Vertex AI Reasoning Engine bypassing ADK naming validation."""

    def set_up(self):
        """Called by Vertex AI on worker initialization."""
        import os
        os.environ["GOOGLE_API_KEY"] = os.environ.get("GEMINI_API_KEY", "[REMOVED]")
        
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

        self.root_agent = LlmAgent(
            name="micro_harvest",
            model="gemini-2.5-flash-lite",
            description="Micro-Harvest agricultural logistics intelligence agent",
            instruction="""You are the Micro-Harvest logistics intelligence agent. When given a crop listing:
1. Identify crop type, weight, and perishability tier
2. Use find_nearby_transporters to locate transporters within 100km
3. Rank by distance, vehicle type, and reliability score
4. Return structured recommendation with weatherRisk, perishabilityRisk, matchedTransporterIds
5. Prioritize REFRIGERATED for HIGH perishability crops (tomatoes, mangoes, wine grapes)
6. Use FLATBED for SUGARCANE and WHEAT""",
            tools=[mcp_toolset],
        )

        self.session_service = InMemorySessionService()
        self.runner = Runner(
            agent=self.root_agent,
            app_name="micro_harvest",
            session_service=self.session_service,
        )
        print("[MicroHarvest] Agent initialized successfully")

    async def query(self, message: str, user_id: str = "user1", session_id: str = None) -> dict:
        """Handle logistics query."""
        import asyncio
        import uuid

        session_id = session_id or str(uuid.uuid4())

        session = await self.session_service.create_session(
            app_name="micro_harvest",
            user_id=user_id,
            session_id=session_id,
        )

        from google.genai.types import Part, Content
        response_text = ""
        tool_calls = 0

        async for event in self.runner.run_async(
            user_id=user_id,
            session_id=session.id,
            new_message=Content(
                role="user",
                parts=[Part(text=message)]
            ),
        ):
            print(f"[MicroHarvest] Event: {type(event)}")
            if event.is_final_response():
                response_text = event.content.parts[0].text if event.content and event.content.parts else ""
                print(f"[MicroHarvest] Final response: {response_text}")
            if event.get_function_calls():
                f_calls = event.get_function_calls()
                tool_calls += len(f_calls)
                print(f"[MicroHarvest] Function calls: {len(f_calls)}")

        return {
            "response": response_text,
            "tool_calls": tool_calls,
            "session_id": session_id,
        }


# Deploy to Vertex AI
print("Deploying MicroHarvestEngine to Vertex AI Reasoning Engine...")

engine = reasoning_engines.ReasoningEngine.create(
    MicroHarvestEngine(),
    requirements=[
        "google-adk>=2.1.0",
        "google-cloud-aiplatform[agent_engines]",
        "mcp",
        "cloudpickle",
    ],
    display_name="Micro-Harvest Agent",
    description="Agricultural surplus marketplace logistics agent with Elastic MCP",
)

print("✅ Deployed successfully!")
print("Resource name:", engine.resource_name)
print("Test query:")
result = engine.query(
    message="I have 20 crates of tomatoes near Banda, find transporters",
    user_id="test_user"
)
print("Response:", result)
