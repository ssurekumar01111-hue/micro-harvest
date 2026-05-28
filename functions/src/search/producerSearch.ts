import * as functions from "firebase-functions/v2";
import { logger } from "firebase-functions";
import * as dotenv from "dotenv";
import { Client } from "@elastic/elasticsearch";
import { generateWithFallback } from "../utils/geminiWithFallback";

dotenv.config();

const esClient = new Client({
  node: process.env.ES_URL || "",
  auth: { apiKey: process.env.ES_API_KEY || "" },
});

interface SearchParams {
  cropType: string | null;
  maxPricePerTon: number | null;
  minWeightKg: number | null;
  radiusKm: number;
  urgency: string | null;
  sortBy: string;
  naturalReply: string;
}

export const producerSearch = functions.https.onCall(
  { region: "asia-south1" },
  async (request) => {
    const { message, producerLocation } = request.data;
    const producerId = request.auth?.uid;

    if (!message || !producerLocation || !producerId) {
      throw new functions.https.HttpsError(
        "invalid-argument", 
        "Missing required fields"
      );
    }

    // Step 1: Gemini extracts search params
    const extractionPrompt = `
You are a produce marketplace search assistant.
Extract search parameters from the producer's query.

Producer location: lat ${producerLocation.latitude}, 
lon ${producerLocation.longitude}
Query: "${message}"

Return ONLY valid JSON, no markdown:
{
  "cropType": "PINOT_NOIR" | "MERLOT" | "CABERNET" | "CHARDONNAY" | "RIESLING" | "SAUVIGNON_BLANC" | "TOMATO" | "POTATO" | "ONION" | "MANGO" | "WHEAT" | "RICE" | "SUGARCANE" | "COTTON" | "SOYBEAN" | "CHICKPEA" | null,
  "maxPricePerTon": number | null,
  "minWeightKg": number | null,
  "radiusKm": number,
  "urgency": "HOURS_12" | "HOURS_24" | "DAYS_3" | "DAYS_7" | null,
  "sortBy": "price_asc" | "price_desc" | "weight_desc" | "urgency",
  "naturalReply": "one sentence describing what you are searching for"
}

RULES:
- radiusKm default is 80 if not mentioned
- "nearby" or "close" = 30km
- "urgent" or "asap" = HOURS_12 urgency
- "today" = HOURS_24 urgency
- "tomorrow" = DAYS_3 urgency
- sortBy default is "urgency"
- naturalReply must be plain English, no markdown

CROP TYPE MAP:
- pinot/pinot noir → PINOT_NOIR
- merlot → MERLOT
- cabernet → CABERNET
- chardonnay → CHARDONNAY
- riesling → RIESLING
- sauvignon blanc → SAUVIGNON_BLANC
- sauvignon → SAUVIGNON_BLANC
- tomato/tamatar → TOMATO
- potato/aloo → POTATO
- onion/pyaz → ONION
- mango/aam → MANGO
- wheat/gehu → WHEAT
- rice/chawal → RICE
- sugarcane/ganna → SUGARCANE
- cotton/kapas → COTTON
- soybean/soya → SOYBEAN
- chickpea/chana → CHICKPEA
`;

    const responseText = await generateWithFallback(
      extractionPrompt
    );
    
    const jsonMatch = responseText.match(/\{[\s\S]*\}/);
    let params: SearchParams;
    
    try {
      params = jsonMatch 
        ? JSON.parse(jsonMatch[0]) 
        : {
            cropType: null,
            maxPricePerTon: null,
            minWeightKg: null,
            radiusKm: 80,
            urgency: null,
            sortBy: "urgency",
            naturalReply: "Searching for available listings near you."
          };
    } catch (e) {
      params = {
        cropType: null,
        maxPricePerTon: null,
        minWeightKg: null,
        radiusKm: 80,
        urgency: null,
        sortBy: "urgency",
        naturalReply: "Searching for available listings near you."
      };
    }

    // Step 2: Build Elastic query
    const filters: any[] = [
      { term: { status: "OPEN" } }
    ];

    if (params.cropType) {
      filters.push({ term: { cropType: params.cropType } });
    }

    if (params.maxPricePerTon && params.maxPricePerTon > 0) {
      filters.push({
        range: { askingPricePerTon: { lte: params.maxPricePerTon } }
      });
    }

    if (params.minWeightKg && params.minWeightKg > 0) {
      filters.push({
        range: { weightKg: { gte: params.minWeightKg } }
      });
    }

    if (params.urgency) {
      filters.push({ term: { urgency: params.urgency } });
    }

    filters.push({
      geo_distance: {
        distance: `${params.radiusKm || 80}km`,
        location: {
          lat: producerLocation.latitude,
          lon: producerLocation.longitude
        }
      }
    });

    const sortOptions: Record<string, any> = {
      price_asc: { askingPricePerTon: { order: "asc" } },
      price_desc: { askingPricePerTon: { order: "desc" } },
      weight_desc: { weightKg: { order: "desc" } },
      urgency: { createdAt: { order: "desc" } },
    };

    const esQuery = {
      query: { bool: { filter: filters } },
      sort: [sortOptions[params.sortBy] || sortOptions.urgency],
      size: 10,
      _source: true
    };

    // Step 3: Execute Elastic search
    let hits: any[] = [];
    try {
      const esResult = await esClient.search({
        index: "micro-harvest-listings",
        ...esQuery
      });
      hits = (esResult.hits.hits as any[]).map(hit => ({
        listingId: hit._id,
        ...hit._source,
      }));
      logger.log(`[producerSearch] Found ${hits.length} results`);
    } catch (esError) {
      logger.error("[producerSearch] ES error:", esError);
      hits = [];
    }

    // Step 4: Generate result summary
    let resultSummary = "";
    if (hits.length === 0) {
      resultSummary = `No listings found matching your search within ${params.radiusKm}km. Try expanding your radius or adjusting filters.`;
    } else {
      resultSummary = `Found ${hits.length} listing${hits.length > 1 ? 's' : ''} matching your search within ${params.radiusKm}km.`;
    }

    return {
      success: true,
      naturalReply: params.naturalReply,
      resultSummary,
      listings: hits,
      searchParams: params,
      totalResults: hits.length,
    };
  }
);
