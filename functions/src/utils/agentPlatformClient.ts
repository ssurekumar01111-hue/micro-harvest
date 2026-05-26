import { GoogleAuth } from "google-auth-library";

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
  const endpoint = process.env.AGENT_ENDPOINT || "";
  if (!endpoint) {
    throw new Error("AGENT_ENDPOINT not configured");
  }

  const message = `Analyze this agricultural listing and find nearby transporters:
Listing ID: ${listingData.listingId}
Crop: ${listingData.cropType}
Weight: ${listingData.weightKg}kg
Perishability Tier: ${listingData.perishTier}
Location: ${listingData.latitude}, ${listingData.longitude}
Radius: 100km
Find available transporters and return logistics recommendation.`;

  try {
    // Use Application Default Credentials (works automatically in Cloud Functions)
    const client = await auth.getClient();
    const token = await client.getAccessToken();

    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        input: {
          message,
          user_id: listingData.listingId,
          session_id: listingData.listingId,
        }
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Reasoning Engine error ${response.status}: ${errorText}`);
    }

    const result = await response.json() as any;
    console.log("[Agent Builder] Response received:", 
      JSON.stringify(result).substring(0, 200));

    // Reasoning Engine with custom class returns { output: { response, tool_calls, ... } }
    const output = result.output || {};
    const responseText = output.response || "";
    const toolCalls = output.tool_calls || 0;

    // Count transporters mentioned in response
    let mcpTransportersFound = 0;
    try {
      const parsed = JSON.parse(
        responseText.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim()
      );
      mcpTransportersFound = parsed.matchedTransporterIds?.length || 0;
    } catch {
      mcpTransportersFound = 0;
    }

    console.log(`[Agent Builder] Tool calls: ${toolCalls}`);
    console.log(`[Agent Builder] Transporters found: ${mcpTransportersFound}`);

    return {
      responseText,
      toolCallsExecuted: Number(toolCalls),
      mcpTransportersFound,
    };
  } catch (error) {
    console.error("[Agent Builder] Query failed:", error);
    throw error;
  }
}
