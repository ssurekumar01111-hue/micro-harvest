import * as functions from "firebase-functions/v2";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import * as dotenv from "dotenv";
import { IntelligenceService } from "./intelligence";
import { geminiWithFallback, INTELLIGENCE_MODEL_CHAIN } from "../utils/geminiWithFallback";
import { listMcpTools } from "../utils/elasticMcpClient";
import { queryMicroHarvestAgent } from "../utils/agentPlatformClient";

dotenv.config();

/**
 * Triggered automatically when a new listing is created in Firestore.
 * Performs logistics intelligence and manages Agent Platform integration.
 */
export const agentProcessListing = functions.firestore.onDocumentCreated({
  document: "listings/{listingId}",
  region: "asia-south1",
  timeoutSeconds: 120,
  memory: "512MiB"
}, async (event) => {
  const db = admin.firestore();
  const snap = event.data;
  if (!snap) {
    logger.warn("No data snapshot found for listing trigger");
    return;
  }

  const data = snap.data();
  const listingId = event.params.listingId;
  const growerId = data.growerId;
  const plotLocation = data.plotLocation;

  if (!growerId || !plotLocation) {
    logger.warn(`Listing ${listingId} missing growerId or plotLocation, skipping intelligence`);
    return;
  }

  // Log MCP tools available at startup (diagnostic)
  try {
    const mcpTools = await listMcpTools();
    console.log("[MCP] Agent Builder tools available:", 
      mcpTools.tools?.length || 0);
  } catch (e) {
    console.warn("[MCP] Could not list tools:", e);
  }

  try {
    // Phase 1: Data Normalization (Doc fields are already extracted by app/chat)
    const extractedData = {
      cropType: data.cropType,
      containerType: data.containerType,
      containerCount: data.containerCount,
      weightKg: data.weightKg,
      perishTier: data.perishTier,
      askingPricePerTon: data.askingPricePerTon,
      harvestWindowHours: 24 // Default or from doc if added later
    };

    // Phase 2: Intelligence Layer
    const [intelligence, rankedTransporters] = await Promise.all([
      IntelligenceService.analyzeListing(extractedData, plotLocation, growerId),
      IntelligenceService.rankTransporters(extractedData, plotLocation, 100).catch(err => {
        console.warn("[Transporters] Parallel call failed:", err.message);
        return [];
      })
    ]);

    // Phase 3: Query Google Cloud Agent Platform agent (ADK)
    let agentResult: any = { responseText: "", toolCallsExecuted: 0, mcpTransportersFound: 0, matchedTransporterIds: [] };
    try {
      agentResult = await Promise.race([
        queryMicroHarvestAgent({
          cropType: extractedData.cropType,
          weightKg: extractedData.weightKg,
          perishTier: extractedData.perishTier,
          latitude: plotLocation.latitude,
          longitude: plotLocation.longitude,
          listingId: listingId,
          growerId: growerId,
        }),
        new Promise<any>((_, reject) => 
          setTimeout(() => reject(new Error("Agent timeout after 35s")), 35000)
        )
      ]);
      console.log("[ADK] Agent Platform integration successful");
    } catch (adkError: any) {
      console.warn("[ADK] Agent Platform query failed or timed out, continuing:", adkError.message);
    }

    // Phase 4: Generate Operational Summary
    // Parse agent response JSON
    let parsedAgent: any = {};
    try {
      parsedAgent = typeof agentResult.responseText === "string"
        ? JSON.parse(agentResult.responseText)
        : agentResult.responseText;
    } catch {
      parsedAgent = {};
    }

    // Use matchedTransporterIds directly from agent result
    const finalMatchedIds = agentResult.matchedTransporterIds?.length > 0
      ? agentResult.matchedTransporterIds
      : (intelligence.matchedTransporterIds || []);

    const mcpTransportersFound = agentResult.mcpTransportersFound
      || agentResult.matchedTransporterIds?.length
      || (intelligence.matchedTransporterIds?.length ?? 0);

    // Build unified intelligence object — new field names, backward compatible
    const unifiedIntelligence = {
      // NEW fields (from Agent Platform)
      weatherRisk: parsedAgent.weatherRisk || intelligence.weatherRisk || "MEDIUM",
      perishabilityRisk: parsedAgent.perishabilityRisk || intelligence.perishabilityRisk || "MEDIUM",
      recommendedVehicle: parsedAgent.recommendedVehicle || intelligence.recommendedTransportType || "STANDARD",
      urgencyBoost: parsedAgent.urgencyBoost ?? intelligence.urgencyScore ?? 0,
      reasoning: parsedAgent.reasoning || intelligence.decisionFactors?.join(". ") || "",
      matchedTransporterIds: finalMatchedIds.length > 0 ? finalMatchedIds : rankedTransporters.map(t => t.uid),

      // BACKWARD COMPAT fields (so Flutter apps keep working during migration)
      urgencyScore: parsedAgent.urgencyBoost ?? intelligence.urgencyScore ?? 0,
      decisionFactors: parsedAgent.reasoning
        ? [parsedAgent.reasoning]
        : (intelligence.decisionFactors || []),
      recommendedTransportType: parsedAgent.recommendedVehicle || intelligence.recommendedTransportType || "STANDARD",

      // NEW tracking field
      elasticIndexed: true,
      processedAt: new Date().toISOString(),
      agentModel: intelligence.agentModel || "gemini-3.1-flash-lite-preview",
      historicalPriceAvg: intelligence?.historicalPriceAvg ?? null,
      recommendedRadiusKm: intelligence.recommendedRadiusKm,
    };

    const summaryReasoning = parsedAgent.reasoning
      || intelligence.decisionFactors?.join(", ")
      || "Logistics assessment complete";

    const summaryPrompt = "You are a calm, professional agricultural logistics coordinator.\nGenerate a concise operational summary of this listing and the reasoning behind its parameters.\n\nData: " + JSON.stringify(extractedData) + "\nReasoning Factors: " + summaryReasoning + "\n\nFocus on the logistics and risks. Keep it under 3 sentences.";

    // Generate summary asynchronously — don't await it
    geminiWithFallback(summaryPrompt, {
      systemInstruction: "You are a calm, professional agricultural logistics coordinator. Generate concise summaries.",
      generationConfig: { temperature: 0.3 },
      modelChain: INTELLIGENCE_MODEL_CHAIN
    }).then(({ result, modelUsed }) => {
      const summaryText = result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";
      console.log(`[Agent] Summary generated with model: ${modelUsed}`);
      return snap.ref.update({
        operationalSummary: summaryText,
        summaryModel: modelUsed,
      });
    }).catch(err => console.warn("[Summary] Failed:", err.message));

    // Update the listing with intelligence immediately
    await snap.ref.update({
      intelligence: unifiedIntelligence,
      agentPlatformResponse: agentResult.responseText,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });


    // Final Log Entry — Ensure all data is collected before writing
    const finalLog = {
      listingId,
      growerId,
      agentPlatformResponse: agentResult.responseText || "",
      agentPlatformToolCalls: agentResult.toolCallsExecuted,
      mcpTransportersFound,
      matchedTransporterIds: finalMatchedIds,
      intelligence: unifiedIntelligence,
      rawInput: data.rawInput || "CREATED_VIA_APP",
      createdAt: new Date(),
    };

    await db.collection("agentLogs").doc(listingId).set(finalLog);
    console.log(`[Agent] AgentLog written with mcpTransportersFound: ${mcpTransportersFound}`);

    logger.log(`[Agent] Successfully processed intelligence for listing ${listingId}`);

  } catch (error) {
    logger.error(`agentProcessListing failed for listing ${listingId}:`, error);
  }
});
