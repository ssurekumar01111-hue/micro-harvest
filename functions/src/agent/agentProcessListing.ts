import * as functions from "firebase-functions/v2";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import * as dotenv from "dotenv";
import { IntelligenceService } from "./intelligence";
import { generateWithFallback } from "../utils/geminiWithFallback";
import { listMcpTools } from "../utils/elasticMcpClient";
import { queryMicroHarvestAgent } from "../utils/agentPlatformClient";

dotenv.config();

/**
 * Triggered automatically when a new listing is created in Firestore.
 * Performs logistics intelligence and manages Agent Platform integration.
 */
export const agentProcessListing = functions.firestore.onDocumentCreated({
  document: "listings/{listingId}",
  region: "asia-south1"
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
    const intelligence = await IntelligenceService.analyzeListing(extractedData, plotLocation, growerId);
    const rankedTransporters = await IntelligenceService.rankTransporters(extractedData, plotLocation, intelligence.recommendedRadiusKm);

    // Phase 3: Query Google Cloud Agent Platform agent (ADK)
    let agentPlatformResponse = "";
    let agentPlatformToolCalls = 0;
    let mcpTransportersFound = 0;
    try {
      const agentResult = await queryMicroHarvestAgent({
        cropType: extractedData.cropType,
        weightKg: extractedData.weightKg,
        perishTier: extractedData.perishTier,
        latitude: plotLocation.latitude,
        longitude: plotLocation.longitude,
        listingId: listingId,
      });

      agentPlatformResponse = agentResult.responseText;
      agentPlatformToolCalls = agentResult.toolCallsExecuted;
      mcpTransportersFound = agentResult.mcpTransportersFound;
      console.log("[ADK] Agent Platform integration successful");
    } catch (adkError) {
      console.warn("[ADK] Agent Platform query failed, continuing:", adkError);
    }

    // Phase 4: Generate Operational Summary
    // Parse agentPlatformResponse JSON
    let parsedAgent: any = {};
    try {
      parsedAgent = typeof agentPlatformResponse === "string"
        ? JSON.parse(agentPlatformResponse)
        : agentPlatformResponse;
    } catch {
      parsedAgent = {};
    }

    // Build unified intelligence object — new field names, backward compatible
    const unifiedIntelligence = {
      // NEW fields (from Agent Platform)
      weatherRisk: parsedAgent.weatherRisk || intelligence.weatherRisk || "MEDIUM",
      perishabilityRisk: parsedAgent.perishabilityRisk || intelligence.perishabilityRisk || "MEDIUM",
      recommendedVehicle: parsedAgent.recommendedVehicle || intelligence.recommendedTransportType || "STANDARD",
      urgencyBoost: parsedAgent.urgencyBoost ?? intelligence.urgencyScore ?? 0,
      reasoning: parsedAgent.reasoning || intelligence.decisionFactors?.join(". ") || "",
      matchedTransporterIds: parsedAgent.matchedTransporterIds || rankedTransporters.map(t => t.uid) || [],

      // BACKWARD COMPAT fields (so Flutter apps keep working during migration)
      urgencyScore: parsedAgent.urgencyBoost ?? intelligence.urgencyScore ?? 0,
      decisionFactors: parsedAgent.reasoning
        ? [parsedAgent.reasoning]
        : (intelligence.decisionFactors || []),
      recommendedTransportType: parsedAgent.recommendedVehicle || intelligence.recommendedTransportType || "STANDARD",

      // NEW tracking field
      elasticIndexed: true,
      processedAt: new Date().toISOString(),
      agentModel: "gemini-2.5-flash",
      historicalPriceAvg: intelligence?.historicalPriceAvg ?? null,
      recommendedRadiusKm: intelligence.recommendedRadiusKm,
    };

    const summaryReasoning = parsedAgent.reasoning
      || intelligence.decisionFactors?.join(", ")
      || "Logistics assessment complete";

    const summaryPrompt = "You are a calm, professional agricultural logistics coordinator.\nGenerate a concise operational summary of this listing and the reasoning behind its parameters.\n\nData: " + JSON.stringify(extractedData) + "\nReasoning Factors: " + summaryReasoning + "\n\nFocus on the logistics and risks. Keep it under 3 sentences.";

    const summaryText = await generateWithFallback(summaryPrompt);

    // Update the listing with intelligence and summary
    await snap.ref.update({
      intelligence: unifiedIntelligence,
      operationalSummary: summaryText,
      agentPlatformResponse,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Final Log Entry
    await db.collection("agentLogs").add({
      listingId,
      growerId,
      rawInput: data.rawInput || "CREATED_VIA_APP",
      intelligence: unifiedIntelligence,
      matchedTransporterIds: rankedTransporters.map(t => t.uid),
      agentPlatformResponse,
      agentPlatformToolCalls,
      mcpTransportersFound,
      createdAt: new Date(),
    });

    logger.log(`[Agent] Successfully processed intelligence for listing ${listingId}`);

  } catch (error) {
    logger.error(`agentProcessListing failed for listing ${listingId}:`, error);
  }
});
