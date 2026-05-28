import { GoogleAuth } from "google-auth-library";
import { callMcpTool } from "./elasticMcpClient";

const auth = new GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/cloud-platform"],
});

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
  mcpTransportersFound: number;
}> {
  const agentId = process.env.AGENT_ID || "";
  if (!agentId) {
    throw new Error("AGENT_ID not set in environment. Cannot call Reasoning Engine.");
  }
  const project = process.env.AGENT_PROJECT || "micro-harvest";

  // STEP 1 — Call Elastic MCP directly first (reliable)
  let mcpResultText = "No transporters found.";
  let mcpTransportersFound = 0;
  try {
    const mcpResult = await callMcpTool(
      "find_nearby_transporters",
      {
        nlQuery: `Find transporters within 100km of latitude ${listingData.latitude} longitude ${listingData.longitude}`
      }
    );
    const content = mcpResult?.content || [];
    const textContent = content.find((c: any) => c.type === "text");
    if (textContent?.text) {
      // Extract transporter IDs explicitly for the agent
      const mcpParsed = JSON.parse(textContent.text);
      const esqlResult = mcpParsed.results?.find((r: any) => r.type === "esql_results");
      const transporterRows = esqlResult?.data?.values || [];
      const uidIndex = esqlResult?.data?.columns?.findIndex((c: any) => c.name === "uid") ?? 0;
      const transporterIds = transporterRows.map((row: any) => row[uidIndex]).filter(Boolean);
      mcpResultText = JSON.stringify({
        transporters_found: transporterRows.length,
        transporter_ids: transporterIds,
        raw: textContent.text.substring(0, 600),
      });
      mcpTransportersFound = transporterRows.length;
    }
    console.log(`[MCP] find_nearby_transporters executed successfully`);
    console.log(`[MCP] Transporters found: ${mcpTransportersFound}`);
  } catch (mcpError) {
    console.warn("[MCP] Tool call failed:", mcpError);
  }

  // STEP 2 — Call Agent Platform Studio agent
  const message = `Crop: ${listingData.cropType}, Weight: ${listingData.weightKg}kg, Perishability: ${listingData.perishTier}, Location: latitude ${listingData.latitude} longitude ${listingData.longitude}, Radius: 100km.

Elastic MCP find_nearby_transporters already executed. Results:
${mcpResultText}

Based on these MCP results, return the logistics recommendation JSON.`;

  try {
    const client = await auth.getClient();
    const token = await client.getAccessToken();

    const region = process.env.AGENT_REGION || "us-west1";
    const endpoint = `https://${region}-aiplatform.googleapis.com/v1/projects/${project}/locations/${region}/reasoningEngines/${agentId}:streamQuery?alt=sse`;

    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token.token}`,
        "Content-Type": "application/json",
        "x-goog-user-project": project,
      },
      body: JSON.stringify({
        class_method: "async_stream_query",
        input: {
          message: message,
          user_id: listingData.listingId,
        },
      }),
    });

    const responseText_raw = await response.text();
    console.log(`[Agent Builder] Status: ${response.status}`);
    console.log(`[Agent Builder] Raw: ${responseText_raw.substring(0, 500)}`);

    if (!response.ok) {
      throw new Error(`Agent API error ${response.status}: ${responseText_raw}`);
    }

    // Try direct JSON response first (non-SSE fallback)
    let responseText = "";
    try {
      const parsed = JSON.parse(responseText_raw);
      // Extract text from content.parts[0].text structure
      responseText = parsed?.content?.parts?.[0]?.text
        || parsed?.output?.message
        || parsed?.output?.text
        || "";
    } catch {
      // Parse as SSE line by line
      const lines = responseText_raw.split("\n");
      for (const line of lines) {
        if (line.startsWith("data: ")) {
          try {
            const chunk = JSON.parse(line.slice(6));
            const text = chunk?.content?.parts?.[0]?.text
              || chunk?.text
              || chunk?.output?.text
              || "";
            if (text) responseText += text;
          } catch {
            // skip unparseable lines
          }
        }
      }
    }

    // Strip markdown code fences if present
    responseText = responseText.replace(/^```json\n?/, "").replace(/\n?```$/, "").trim();

    console.log(`[Agent Builder] Parsed response: ${responseText.substring(0, 300)}`);

    return {
      responseText,
      toolCallsExecuted: mcpTransportersFound > 0 ? 1 : 0,
      mcpTransportersFound,
    };

  } catch (agentError) {
    console.error("[Agent Builder] Query failed:", agentError);

    // Fallback — use Gemini directly if Agent Platform fails
    try {
      const { VertexAI } = await import("@google-cloud/vertexai");
      const vertexAI = new VertexAI({
        project: process.env.AGENT_PROJECT || "micro-harvest",
        location: process.env.AGENT_REGION || "asia-south1"
      });
      const model = vertexAI.getGenerativeModel({
        model: "gemini-2.5-flash"
      });
      const result = await model.generateContent(message);
      const text = result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
      console.log("[Agent Builder] Fallback to Gemini direct succeeded");
      return {
        responseText: text,
        toolCallsExecuted: mcpTransportersFound > 0 ? 1 : 0,
        mcpTransportersFound,
      };
    } catch (fallbackError) {
      console.error("[Agent Builder] Fallback also failed:", fallbackError);
      return {
        responseText: "",
        toolCallsExecuted: 0,
        mcpTransportersFound,
      };
    }
  }
}
