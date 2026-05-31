import { GoogleAuth } from "google-auth-library";
import { geminiWithFallback, INTELLIGENCE_MODEL_CHAIN } from "./geminiWithFallback";

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
  growerId: string;
}): Promise<{
  responseText: string;
  toolCallsExecuted: number;
  mcpTransportersFound: number;
  matchedTransporterIds: string[];
}> {
  const agentId = process.env.AGENT_ID || "";
  if (!agentId) {
    throw new Error("AGENT_ID not set in environment. Cannot call Reasoning Engine.");
  }
  const project = process.env.AGENT_PROJECT || "micro-harvest";

  // STEP 1 — Build clean prompt (agent calls MCP itself)
  const message = `You are processing a crop listing for the Micro-Harvest agricultural marketplace.

Listing details:
- Crop: ${listingData.cropType}
- Weight: ${listingData.weightKg}kg
- Perishability: ${listingData.perishTier}
- Location: latitude ${listingData.latitude} longitude ${listingData.longitude}
- Grower: ${listingData.growerId}

REQUIRED: Call find_nearby_transporters with this exact nlQuery: "Find available transporters within 100km of latitude ${listingData.latitude} longitude ${listingData.longitude}". Do NOT filter by crop type.

Then return ONLY this JSON:
{
  "weatherRisk": "LOW|MEDIUM|HIGH",
  "perishabilityRisk": "LOW|MEDIUM|HIGH", 
  "recommendedVehicle": "REFRIGERATED|FLATBED|STANDARD",
  "urgencyBoost": 0-20,
  "matchedTransporterIds": ["id1","id2"],
  "reasoning": "2-3 sentences"
}`;

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

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`Agent API error ${response.status}: ${errText}`);
    }

    console.log(`[Agent Builder] Status: ${response.status} — reading SSE stream...`);

    let finalText = "";
    let toolCallCount = 0;
    let buffer = "";

    const reader = (response.body as any).getReader();
    const decoder = new TextDecoder();
    const deadline = Date.now() + 90000;

    try {
      while (Date.now() < deadline) {
        const { done, value } = await reader.read();
        if (done) {
          console.log(`[Agent Builder] Stream ended naturally`);
          break;
        }

        buffer += decoder.decode(value, { stream: true });

        // Split on newlines — each line may be a complete JSON object
        const lines = buffer.split("\n");
        buffer = lines.pop() || "";

        for (const line of lines) {
          const trimmed = line.trim();
          if (!trimmed) continue;

          // Strip "data: " prefix if present (handle both formats)
          const jsonStr = trimmed.startsWith("data: ")
            ? trimmed.slice(6)
            : trimmed;

          if (jsonStr === "[DONE]") continue;

          try {
            const chunk = JSON.parse(jsonStr);

            // Extract parts from all known locations
            const parts = chunk?.content?.parts
              || chunk?.parts
              || chunk?.candidates?.[0]?.content?.parts
              || [];

            for (const part of parts) {
              if (part.functionCall || part.function_call) {
                toolCallCount++;
                const name = part.functionCall?.name || part.function_call?.name;
                console.log(`[Agent Builder] Tool call: ${name}`);
              }
              if (part.text && part.text.trim()) {
                finalText = part.text;
                console.log(`[Agent Builder] Text: ${part.text.substring(0, 150)}`);
              }
            }

            // Check finish signal
            const finishReason = chunk?.candidates?.[0]?.finishReason
              || chunk?.finish_reason;
            if (finishReason === "STOP") {
              console.log(`[Agent Builder] STOP signal received`);
            }

          } catch {
            // Chunk split across packets — keep in buffer and wait for more
            buffer = trimmed + "\n" + buffer;
            break;
          }
        }
      }
    } catch (streamErr: any) {
      console.warn(`[Agent Builder] Stream error: ${streamErr.message}`);
    } finally {
      try { reader.releaseLock(); } catch {}
    }

    console.log(`[Agent Builder] Tool calls detected: ${toolCallCount}`);

    let responseText = finalText
      .replace(/^```json\n?/, "")
      .replace(/\n?```$/, "")
      .trim();

    console.log(`[Agent Builder] Final responseText: ${responseText.substring(0, 500)}`);

    let mcpTransportersFound = 0;
    let parsedMatchedIds: string[] = [];
    try {
      const parsed = JSON.parse(responseText);
      parsedMatchedIds = parsed?.matchedTransporterIds || [];
      mcpTransportersFound = parsedMatchedIds.length;
    } catch {
      mcpTransportersFound = 0;
    }

    return {
      responseText,
      toolCallsExecuted: toolCallCount,
      mcpTransportersFound,
      matchedTransporterIds: parsedMatchedIds,
    };

  } catch (agentError) {
    console.error("[Agent Builder] Query failed:", agentError);

    // Fallback — use Gemini directly if Agent Platform fails
    try {
      const { result: fallbackResult, modelUsed } = await geminiWithFallback(message, {
        systemInstruction: "You are a logistics intelligence agent. Return JSON only.",
        generationConfig: { temperature: 0.1 },
        modelChain: INTELLIGENCE_MODEL_CHAIN,
      });
      const text = fallbackResult.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
      console.log(`[Agent Builder] Fallback model used: ${modelUsed}`);

      // Strip markdown code fences if present
      const cleanText = text.replace(/^```json\n?/, "").replace(/\n?```$/, "").trim();
      let mcpFound = 0;
      let matchedIds: string[] = [];
      try {
        const parsed = JSON.parse(cleanText);
        matchedIds = parsed?.matchedTransporterIds || [];
        mcpFound = matchedIds.length;
      } catch {
        mcpFound = 0;
      }

      return {
        responseText: cleanText,
        toolCallsExecuted: mcpFound > 0 ? 1 : 0,
        mcpTransportersFound: mcpFound,
        matchedTransporterIds: matchedIds,
      };
    } catch (fallbackError) {
      console.error("[Agent Builder] Fallback also failed:", fallbackError);
      return {
        responseText: "",
        toolCallsExecuted: 0,
        mcpTransportersFound: 0,
        matchedTransporterIds: [],
      };
    }
  }
}
