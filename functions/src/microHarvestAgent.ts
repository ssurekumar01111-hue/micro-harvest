import { LlmAgent } from "@google/adk";
import { McpToolset, StreamableHTTPConnectionParams } from "@google/adk/tools/mcp_tool";

const mcpToolset = new McpToolset({
  connectionParams: new StreamableHTTPConnectionParams({
    url: "https://asia-south1-micro-harvest.cloudfunctions.net/mcpProxy",
  }),
});

export const rootAgent = new LlmAgent({
  name: "micro_harvest",
  model: "gemini-2.0-flash",
  description: "Micro-Harvest agricultural logistics intelligence agent",
  instruction: `You are the Micro-Harvest logistics intelligence agent. When given a crop listing:
1. Identify crop type, weight, and perishability tier
2. Use find_nearby_transporters to locate transporters within 100km
3. Rank by distance, vehicle type, and reliability score
4. Return structured recommendation with weatherRisk, perishabilityRisk, matchedTransporterIds
5. Prioritize REFRIGERATED for HIGH perishability crops (tomatoes, mangoes, wine grapes)
6. Use FLATBED for SUGARCANE and WHEAT`,
  tools: [mcpToolset],
});
