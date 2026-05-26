import { callMcpTool } from "./elasticMcpClient";
import { GoogleGenerativeAI } from "@google/generative-ai";

export async function queryMicroHarvestAgent(listingData: {
  cropType: string;
  weightKg: number;
  perishTier: string;
  latitude: number;
  longitude: number;
  listingId: string;
}): Promise<{
  responseText: string;
  toolCallsExecuted: number;
  mcpTransporters: any[];
}> {
  let toolCallsExecuted = 0;
  let mcpTransporters: any[] = [];

  // STEP 1 — Call Elastic MCP tool directly (already working)
  try {
    console.log("[ADK] Calling find_nearby_transporters via Elastic MCP");
    const mcpResult = await callMcpTool(
      "find_nearby_transporters",
      {
        nlQuery: `Find available transporters within 100km of latitude ${listingData.latitude}, longitude ${listingData.longitude} for ${listingData.cropType} delivery`
      }
    );

    const content = mcpResult?.content || [];
    const textContent = content.find((c: any) => c.type === "text");
    if (textContent?.text) {
      try {
        const parsed = JSON.parse(textContent.text);
        mcpTransporters = Array.isArray(parsed) ? parsed : [];
      } catch {
        console.log("[ADK] MCP returned text:", 
          textContent.text.substring(0, 100));
      }
    }
    toolCallsExecuted++;
    console.log(`[ADK] MCP tool executed. Transporters found: ${mcpTransporters.length}`);
  } catch (mcpError) {
    console.warn("[ADK] MCP tool call failed:", mcpError);
  }

  // STEP 2 — Use Gemini to generate logistics recommendation
  try {
    const genAI = new GoogleGenerativeAI(
      process.env.GEMINI_API_KEY || ""
    );
    const model = genAI.getGenerativeModel({ 
      model: "gemini-2.5-flash-lite" 
    });

    const prompt = `You are a logistics intelligence agent for Micro-Harvest agricultural marketplace.

Listing Details:
- Crop: ${listingData.cropType}
- Weight: ${listingData.weightKg}kg  
- Perishability Tier: ${listingData.perishTier}
- Location: ${listingData.latitude}, ${listingData.longitude}

Transporters found via Elastic MCP geo-search: ${mcpTransporters.length}
MCP Results: ${JSON.stringify(mcpTransporters).substring(0, 500)}

Provide a structured logistics recommendation:
1. weatherRisk (LOW/MEDIUM/HIGH)
2. perishabilityRisk (LOW/MEDIUM/HIGH) 
3. recommendedVehicle (REFRIGERATED/FLATBED/STANDARD)
4. urgencyBoost (0-20 points)
5. reasoning (2-3 sentences)

Keep response concise and structured.`;

    const result = await model.generateContent(prompt);
    const responseText = result.response.text();

    console.log(`[ADK] Gemini logistics recommendation generated`);
    console.log(`[ADK] Tool calls executed: ${toolCallsExecuted}`);

    return { responseText, toolCallsExecuted, mcpTransporters };
  } catch (geminiError) {
    console.warn("[ADK] Gemini recommendation failed:", geminiError);
    return { 
      responseText: "", 
      toolCallsExecuted, 
      mcpTransporters 
    };
  }
}
