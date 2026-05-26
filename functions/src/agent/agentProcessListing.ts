import * as functions from "firebase-functions/v2";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { SchemaType } from "@google/generative-ai";
import * as dotenv from "dotenv";
import { IntelligenceService } from "./intelligence";
import { generateWithFallback, generateWithFallbackFull } from "../utils/geminiWithFallback";
import { listMcpTools } from "../utils/elasticMcpClient";
import { queryMicroHarvestAgent } from "../utils/agentPlatformClient";

dotenv.config();

const apiKey = process.env.GEMINI_API_KEY || "";


if (!process.env.GEMINI_API_KEY) {
  logger.error("FATAL: GEMINI_API_KEY is not set");
}

interface AgentProcessInput {
  rawInput: string;
  growerId: string;
  plotLocation: { latitude: number; longitude: number };
}

export const agentProcessListing = functions.https.onCall({ 
  region: "asia-south1" 
}, async (request) => {
  const db = admin.firestore();
  const { rawInput, growerId, plotLocation } = request.data as AgentProcessInput;

  // Log MCP tools available at startup
  try {
    const mcpTools = await listMcpTools();
    console.log("[MCP] Agent Builder tools available:", 
      mcpTools.tools?.length || 0);
  } catch (e) {
    console.warn("[MCP] Could not list tools:", e);
  }

  if (!rawInput || !growerId || !plotLocation) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required fields");
  }

  try {
    const tools = [{
      functionDeclarations: [{
        name: "find_nearby_transporters",
        description: "Searches Elasticsearch users index to find available transporters within radius of a location",
        parameters: {
          type: SchemaType.OBJECT,
          properties: {
            latitude: { type: SchemaType.NUMBER },
            longitude: { type: SchemaType.NUMBER },
            radiusKm: { type: SchemaType.NUMBER }
          },
          required: ["latitude", "longitude", "radiusKm"]
        }
      }]
    }];

    const extractionPrompt = `You are an expert agricultural logistics assistant helping farmers list surplus crops for sale. 
Extract listing details from the grower's message and make smart assumptions for missing fields.

You support English, Hindi, and Hinglish naturally.
Examples:
- 'Mere paas 2 ton aloo ready hai' → cropType: POTATO, weightKg: 2000
- '20 bori tamatar hai' → cropType: TOMATO, containerType: SACK, containerCount: 20
- 'Kal tak chahiye' → perishTier: HOURS_24
Extract correctly regardless of language used.

CONTAINER WEIGHT RULES:
- MACRO_BIN: 500kg
- HALF_BIN: 250kg  
- LUG_BOX: 20kg
- BULK_BAG: 500kg
- CRATE: 25kg
- SACK: 50kg
- QUINTAL: 100kg
- TROLLEY: 1000kg
Always calculate weightKg = containerCount * containerWeight

SMART ASSUMPTION RULES:
- If weight given but no container info:
  Assume BULK_BAG containers
  Calculate count: weight / 500kg per bag
  Round up to nearest whole number

- If only tons given: multiply by 1000 for kg
  e.g. '20 tons' = 20000kg

- If no perishTier mentioned:
  Default to HOURS_24 (assume urgency)

- If no price mentioned or price is 0:
  Set askingPricePerTon to null (optional field)

- If crop type is clear: use it
  Accept common variations:
  'pinot', 'pinot noir' = PINOT_NOIR
  'tomato', 'tamatar' = TOMATO
  'potato', 'aloo' = POTATO
  'onion', 'pyaz' = ONION
  'mango', 'aam' = MANGO
  'wheat', 'gehu' = WHEAT
  'rice', 'chawal' = RICE
  'sugarcane', 'ganna' = SUGARCANE
  'cotton', 'kapas' = COTTON
  'soybean', 'soya' = SOYBEAN
  'chickpea', 'chana' = CHICKPEA

- If harvest window not mentioned:
  Default to 24 hours from now

ONLY return null for cropType if you genuinely cannot determine what crop it is.
Everything else should have a smart default.

Enum Values:
CropType: PINOT_NOIR, MERLOT, CABERNET, CHARDONNAY, RIESLING, TOMATO, POTATO, ONION, MANGO, WHEAT, RICE, SUGARCANE, COTTON, SOYBEAN, CHICKPEA
ContainerType: MACRO_BIN, HALF_BIN, LUG_BOX, BULK_BAG, CRATE, SACK, QUINTAL, TROLLEY
PerishTier: HOURS_12, HOURS_24, DAYS_3, DAYS_7

Return ONLY this JSON, no extra text:
{
  "cropType": string | null,
  "containerType": string,
  "containerCount": number,
  "weightKg": number,
  "perishTier": string,
  "askingPricePerTon": number | null,
  "harvestWindowHours": number,
  "confidence": {
    "containerType": "stated" | "assumed",
    "containerCount": "stated" | "assumed",
    "perishTier": "stated" | "assumed",
    "weightKg": "stated" | "assumed"
  }
}
`;

    const fullPrompt = extractionPrompt + "\n\nGrower Message: \"" + rawInput + "\"\nThe grower's plot location is: lat " + plotLocation.latitude + ", lon " + plotLocation.longitude + ".\nAfter extracting the listing data, call find_nearby_transporters with these coordinates and radiusKm: 100 to find available transporters.";
    const extractionResult = await generateWithFallbackFull(apiKey, fullPrompt, tools as any);

    // --- Pass 1: Handle Tool Calls (Transporter Matching & Intelligence) ---
    const candidate = extractionResult.response.candidates?.[0];
    const parts = candidate?.content?.parts || [];

    for (const part of parts) {
      if (part.functionCall?.name === "find_nearby_transporters") {
         // In Phase 2 we use IntelligenceService.rankTransporters later
      }
    }

    // --- Pass 2: Extract JSON (The actual listing data) ---
    let extractionText = "";
    try {
      extractionText = extractionResult.response.text();
    } catch (e) {
      const textPart = parts.find((p: any) => p.text)?.text;
      if (textPart) extractionText = textPart;
    }

    let jsonMatch = extractionText.match(/\{[\s\S]*\}/);
    
    if (!jsonMatch) {
      extractionText = await generateWithFallback(apiKey, extractionPrompt + "\n\nGrower Message: \"" + rawInput + "\"" + "\n\nIMPORTANT: Return ONLY the JSON object.");
      jsonMatch = extractionText.match(/\{[\s\S]*\}/);
    }

    const cleanJsonText = jsonMatch ? jsonMatch[0] : extractionText.trim().replace(/```json|```/g, "");
    
    let extracted;
    try {
      extracted = JSON.parse(cleanJsonText);
    } catch (parseError) {
      throw new functions.https.HttpsError("internal", "Failed to extract listing data.");
    }

    if (!extracted.cropType) {
      return {
        success: false,
        needsMoreInfo: true,
        missingFields: ["cropType"],
        message: "I couldn't identify what crop you want to list."
      };
    }

    const containerWeights: Record<string, number> = {
      MACRO_BIN: 500,
      HALF_BIN: 250,
      LUG_BOX: 20,
      BULK_BAG: 500,
      CRATE: 25,
      SACK: 50,
      QUINTAL: 100,
      TROLLEY: 1000,
    };

    const extractedData = {
      cropType: extracted.cropType,
      containerType: extracted.containerType,
      containerCount: extracted.containerCount,
      weightKg: extracted.weightKg || (extracted.containerCount * (containerWeights[extracted.containerType] || 500)),
      perishTier: extracted.perishTier,
      askingPricePerTon: extracted.askingPricePerTon,
      harvestWindowHours: extracted.harvestWindowHours
    };

    const assumptions = {
      containerType: extracted.confidence.containerType === "assumed",
      containerCount: extracted.confidence.containerCount === "assumed",
      perishTier: extracted.confidence.perishTier === "assumed",
      weightKg: extracted.confidence.weightKg === "assumed",
    };

    // Phase 2: Intelligence Layer
    const intelligence = await IntelligenceService.analyzeListing(extractedData, plotLocation, growerId);
    const rankedTransporters = await IntelligenceService.rankTransporters(extractedData, plotLocation, intelligence.recommendedRadiusKm);

    // Query Google Cloud Agent Platform agent
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
        listingId: `${growerId}_${Date.now()}`, // Temporary listing ID for agent context
      });

      agentPlatformResponse = agentResult.responseText;
      agentPlatformToolCalls = agentResult.toolCallsExecuted;
      mcpTransportersFound = agentResult.mcpTransporters.length;
      console.log("[ADK] Agent Platform integration successful");
    } catch (adkError) {
      console.warn("[ADK] Agent Platform query failed, continuing:", adkError);
    }

    const summaryPrompt = "You are a calm, professional agricultural logistics coordinator.\nGenerate a concise operational summary of this listing and the reasoning behind its parameters.\n\nData: " + JSON.stringify(extractedData) + "\nReasoning Factors: " + intelligence.decisionFactors.join(", ") + "\n\nFocus on the logistics and risks. Keep it under 3 sentences.";

    const summaryText = await generateWithFallback(apiKey, summaryPrompt);

    await db.collection("agentLogs").add({
      growerId,
      rawInput,
      intelligence,
      matchedTransporterIds: rankedTransporters.map(t => t.uid),
      agentPlatformResponse,
      agentPlatformToolCalls,
      mcpTransportersFound,
      createdAt: new Date(),
    });

    return {
      success: true,
      summary: summaryText,
      assumptions,
      extractedData,
      reasoning: intelligence,
    };

  } catch (error) {
    logger.error("agentProcessListing failed:", error);
    throw new functions.https.HttpsError("internal", "Internal error");
  }
});
