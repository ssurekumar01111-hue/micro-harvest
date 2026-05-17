import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { Client } from "@elastic/elasticsearch";
import * as dotenv from "dotenv";
import { 
  ListingStatus, 
  ListingModel, 
  AgentLogModel 
} from "../../../packages/core/src/models";

dotenv.config();

// Initialize Firebase Admin if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const fcm = admin.messaging();

// Initialize Gemini
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
const model = genAI.getGenerativeModel({ model: "gemini-3.1-flash-lite" });


// Initialize Elasticsearch
const esClient = new Client({
  node: process.env.ES_URL,
  auth: {
    apiKey: process.env.ES_API_KEY || ""
  }
});

interface AgentProcessInput {
  rawInput: string;
  growerId: string;
  plotLocation: { latitude: number; longitude: number };
  harvestWindowEnd: string;
}

export const agentProcessListing = functions.https.onCall({ region: "asia-south1" }, async (request) => {
  const startTime = Date.now();
  const { rawInput, growerId, plotLocation, harvestWindowEnd } = request.data as AgentProcessInput;

  if (!rawInput || !growerId || !plotLocation || !harvestWindowEnd) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required fields");
  }

  try {
    // Step 1: Gemini Extraction
    const extractionPrompt = `You are an agricultural logistics assistant. 
Extract listing fields from the grower's message as strict JSON. Only use these exact enum values:

CropType: PINOT_NOIR, CHARDONNAY, RIESLING, CABERNET, MERLOT, SAUVIGNON_BLANC
ContainerType: MACRO_BIN, HALF_BIN, LUG_BOX, BULK_BAG
PerishTier: HOURS_12, HOURS_24, DAYS_3, DAYS_7

Return ONLY this JSON structure, no extra text:
{
  "cropType": string | null,
  "containerType": string | null,
  "containerCount": number | null,
  "weightKg": number | null,
  "perishTier": string | null,
  "askingPriceUSD": number | null,
  "harvestWindowHours": number | null
}

Return null for any field you cannot determine with confidence. Never invent values.

Grower Message: "${rawInput}"`;

    const extractionResult = await model.generateContent(extractionPrompt);
    const extractionText = extractionResult.response.text().trim().replace(/```json|```/g, "");
    const extractedJson = JSON.parse(extractionText);

    // Step 2: Validation
    const requiredFields = ["cropType", "containerType", "containerCount", "perishTier"];
    const missingFields = requiredFields.filter(field => !extractedJson[field]);

    if (missingFields.length > 0) {
      return {
        success: false,
        message: `I couldn't identify some important details: ${missingFields.join(", ")}. Please provide these so I can help you list your crop.`
      };
    }

    // Step 3: Elastic Geo-matching
    // Ensure index exists (simplified check/create)
    try {
      const indexExists = await esClient.indices.exists({ index: "users" });
      if (!indexExists) {
        await esClient.indices.create({
          index: "users",
          body: {
            mappings: {
              properties: {
                uid: { type: "keyword" },
                role: { type: "keyword" },
                displayName: { type: "text" },
                location: { type: "geo_point" },
                geohash: { type: "keyword" },
                radiusMiles: { type: "float" },
                availabilityStatus: { type: "keyword" },
                cropInterests: { type: "keyword" },
                fcmTokens: { type: "keyword" }
              }
            }
          }
        });
      }
    } catch (e) {
      console.error("Elasticsearch index check/create failed", e);
    }

    const esQuery = {
      bool: {
        must: [
          {
            geo_distance: {
              distance: "50mi",
              location: {
                lat: plotLocation.latitude,
                lon: plotLocation.longitude
              }
            }
          }
        ],
        should: [
          { term: { role: "PRODUCER" } },
          {
            bool: {
              must: [
                { term: { role: "TRANSPORTER" } },
                { term: { availabilityStatus: "AVAILABLE" } }
              ]
            }
          }
        ],
        minimum_should_match: 1
      }
    };

    const esResult = await esClient.search({
      index: "users",
      body: {
        query: esQuery,
        size: 10
      }
    });

    const matches = esResult.hits.hits.map(hit => hit._source as any);
    const producers = matches.filter(m => m.role === "PRODUCER");
    const transporters = matches.filter(m => m.role === "TRANSPORTER");

    // Step 4: Write to Firestore
    const listingRef = db.collection("listings").doc();
    const listingId = listingRef.id;

    const listingData: ListingModel = {
      listingId,
      growerId,
      cropType: extractedJson.cropType,
      containerType: extractedJson.containerType,
      containerCount: extractedJson.containerCount,
      weightKg: extractedJson.weightKg || 0,
      perishTier: extractedJson.perishTier,
      askingPriceUSD: extractedJson.askingPriceUSD || 0,
      plotLocation,
      geohash: "", // Geohash generation would typically happen here
      harvestWindowEnd: new Date(harvestWindowEnd),
      status: ListingStatus.OPEN,
      producerId: null,
      transporterId: null,
      listingSource: "AGENT",
      createdAt: new Date(),
      updatedAt: new Date()
    };

    await listingRef.set(listingData);

    const logRef = db.collection("agentLogs").doc();
    const logData: AgentLogModel = {
      logId: logRef.id,
      growerId,
      rawInput,
      geminiOutput: extractedJson,
      elasticQuery: esQuery,
      elasticResult: esResult.hits.hits,
      listingId,
      processingMs: Date.now() - startTime,
      createdAt: new Date()
    };

    await logRef.set(logData);

    // Step 5: FCM Alerts
    const producerTokens = producers.flatMap(p => p.fcmTokens || []);
    const transporterTokens = transporters.flatMap(t => t.fcmTokens || []);

    if (producerTokens.length > 0) {
      await fcm.sendEachForMulticast({
        tokens: producerTokens,
        notification: {
          title: "Flash Surplus Alert",
          body: `New ${extractedJson.cropType} listing near you. ${extractedJson.weightKg || 0}kg available now.`
        }
      });
    }

    if (transporterTokens.length > 0) {
      await fcm.sendEachForMulticast({
        tokens: transporterTokens,
        notification: {
          title: "Haul Available",
          body: `New haul request: ${extractedJson.weightKg || 0}kg, pickup within ${extractedJson.perishTier}.`
        }
      });
    }

    // Step 6: Gemini Summary
    const summaryPrompt = `Summarize this listing result for the grower in 1-2 sentences:
Crop: ${extractedJson.cropType}, Quantity: ${extractedJson.containerCount} ${extractedJson.containerType}, Weight: ${extractedJson.weightKg}kg.
Producers notified: ${producers.length}, Transporters notified: ${transporters.length}.`;

    const summaryResult = await model.generateContent(summaryPrompt);
    const summaryText = summaryResult.response.text().trim();

    return {
      success: true,
      listingId,
      summary: summaryText
    };

  } catch (error) {
    console.error("agentProcessListing failed:", error);
    throw new functions.https.HttpsError("internal", "An error occurred while processing your request.");
  }
});
