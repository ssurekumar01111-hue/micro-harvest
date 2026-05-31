import * as admin from "firebase-admin";
import { logger } from "firebase-functions";
import { Client } from "@elastic/elasticsearch";
import { callMcpTool } from "../utils/elasticMcpClient";
import { geminiWithFallback, INTELLIGENCE_MODEL_CHAIN } from "../utils/geminiWithFallback";

const getDb = () => {
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
  return admin.firestore();
};

const getEsClient = () => {
  return new Client({
    node: process.env.ES_URL || "",
    auth: { apiKey: process.env.ES_API_KEY || "" },
  });
};

export interface WeatherData {
  tempC: number;
  rainfallProb: number;
  humidity: number;
  stormRisk: boolean;
  summary: string;
}

export interface IntelligenceResult {
  // New fields
  weatherRisk: "LOW" | "MEDIUM" | "HIGH";
  perishabilityRisk: "LOW" | "MEDIUM" | "HIGH";
  recommendedVehicle: "REFRIGERATED" | "FLATBED" | "STANDARD";
  urgencyBoost: number;
  reasoning: string;
  matchedTransporterIds: string[];
  elasticIndexed: boolean;
  processedAt: string;
  agentModel: string;

  // Backward compat fields
  urgencyScore: number;
  decisionFactors: string[];
  recommendedTransportType: string;
  
  recommendedRadiusKm: number;
  historicalPriceAvg?: number;
}

export class IntelligenceService {
  static async getWeatherData(lat: number, lon: number): Promise<WeatherData> {
    // Simulated weather intelligence for asia-south1
    return {
      tempC: 32,
      rainfallProb: 0.65,
      humidity: 80,
      stormRisk: false,
      summary: "High humidity with evening showers expected."
    };
  }

  static async getGrowerMemory(growerId: string): Promise<any> {
    const db = getDb();
    const memoryDoc = await db.collection("growerMemory").doc(growerId).get();
    return memoryDoc.exists ? memoryDoc.data() : null;
  }

  static async getHistoricalTrends(cropType: string): Promise<any> {
    const esClient = getEsClient();
    try {
      const result = await esClient.search({
        index: "micro-harvest-listings",
        body: {
          query: {
            bool: {
              filter: [
                { term: { cropType: cropType } },
                { term: { status: "SETTLED" } }
              ]
            }
          },
          aggs: {
            avg_price: { avg: { field: "askingPriceUSD" } },
            avg_weight: { avg: { field: "weightKg" } }
          },
          size: 0
        }
      });
      return (result.aggregations as any);
    } catch (e) {
      logger.error("ELK Historical Trends failed:", e);
      return null;
    }
  }

  static async analyzeListing(
    data: any, 
    plotLocation: { latitude: number; longitude: number },
    growerId: string
  ): Promise<IntelligenceResult> {
    const weather = await this.getWeatherData(plotLocation.latitude, plotLocation.longitude);
    const history = await this.getHistoricalTrends(data.cropType);
    const memory = await this.getGrowerMemory(growerId);

    const prompt = `You are an agricultural logistics intelligence agent for Indian farmers.
Analyze this listing and provide logistics recommendations.

Listing Data: ${JSON.stringify(data)}
Weather: ${JSON.stringify(weather)}
Historical Avg Price: ${history?.avg_price?.value || "Unknown"}
Grower Prefs: ${JSON.stringify(memory)}

Return ONLY JSON:
{
  "weatherRisk": "LOW" | "MEDIUM" | "HIGH",
  "perishabilityRisk": "LOW" | "MEDIUM" | "HIGH",
  "recommendedVehicle": "REFRIGERATED" | "FLATBED" | "STANDARD",
  "urgencyBoost": number (0-100),
  "reasoning": "string",
  "urgencyScore": number (0-100),
  "decisionFactors": ["string"],
  "recommendedTransportType": "REFRIGERATED" | "STANDARD",
  "recommendedRadiusKm": number
}`;

    const { result, modelUsed } = await geminiWithFallback(prompt, {
      systemInstruction: "You are an agricultural logistics intelligence agent for Indian farmers.",
      generationConfig: { temperature: 0.2, response_mime_type: "application/json" },
      modelChain: INTELLIGENCE_MODEL_CHAIN,
    });

    const responseText = result.response.candidates?.[0]?.content?.parts?.[0]?.text || "{}";
    const aiResult = JSON.parse(responseText);

    return {
      ...aiResult,
      matchedTransporterIds: [],
      elasticIndexed: false,
      processedAt: new Date().toISOString(),
      agentModel: modelUsed,
      historicalPriceAvg: history?.avg_price?.value ?? null
    };
  }



  static async rankTransporters(
    listingData: any,
    plotLocation: { latitude: number; longitude: number },
    radiusKm: number = 100
  ): Promise<any[]> {
    
    // Try MCP first
    try {
      console.log("[MCP] Calling find_nearby_transporters via MCP (nlQuery format)");
      const mcpResult = await callMcpTool(
        "find_nearby_transporters",
        {
          nlQuery: `Find available transporters within ${radiusKm}km of latitude ${plotLocation.latitude}, longitude ${plotLocation.longitude}`
        }
      );
      
      console.log("[MCP] find_nearby_transporters result:", 
        JSON.stringify(mcpResult).substring(0, 200));
      
      // Parse MCP result — it returns content array
      const content = mcpResult?.content || [];
      const textContent = content.find((c: any) => c.type === "text");
      if (textContent?.text) {
        try {
          const parsed = JSON.parse(textContent.text);
          // If MCP returned results use them
          if (Array.isArray(parsed) && parsed.length > 0) {
            console.log(`[MCP] Found ${parsed.length} transporters via MCP`);
            return parsed.map((t: any) => ({
              ...t,
              totalScore: 100,
              reasoning: ["Matched via Elastic Agent Builder MCP"]
            }));
          }
        } catch (parseError) {
          console.warn("[MCP] Could not parse result, falling back to direct ES");
        }
      }
    } catch (mcpError) {
      console.warn("[MCP] MCP call failed, falling back to direct ES:", 
        mcpError);
    }

    // Fallback to direct ES client
    console.log("[ES Direct] Falling back to direct Elasticsearch query");
    const esClient = getEsClient();
    try {
      const esResult = await esClient.search({
        index: "users",
        body: {
          query: {
            bool: {
              filter: [
                { term: { role: "TRANSPORTER" } },
                { term: { availabilityStatus: "AVAILABLE" } },
                { term: { suspended: false } },
                {
                  geo_distance: {
                    distance: `${radiusKm}km`,
                    location: {
                      lat: plotLocation.latitude,
                      lon: plotLocation.longitude
                    }
                  }
                }
              ]
            }
          },
          size: 20
        }
      });

      const transporters = (esResult.hits.hits as any[]).map(hit => ({
        ...hit._source,
        totalScore: 0,
        reasoning: [] as string[]
      }));

      for (const t of transporters) {
        let score = 100;

        // 1. Distance factor (0-40 points)
        const distKm = 15; // Mocked distance
        const distScore = Math.max(0, 40 - (distKm / 2));
        score += distScore;
        t.reasoning.push(`Distance: ${distKm.toFixed(1)}km (+${distScore.toFixed(0)} pts)`);

        // 2. Vehicle compatibility (0-30 points)
        if (listingData.perishTier === "HOURS_12" && t.vehicleType === "REFRIGERATED") {
          score += 30;
          t.reasoning.push("Refrigerated vehicle matches perishability (+30 pts)");
        } else {
          score += 10;
          t.reasoning.push("Standard vehicle (+10 pts)");
        }

        // 3. Historical reliability (0-30 points)
        const reliability = t.reliabilityScore || 0.8;
        const relScore = reliability * 30;
        score += relScore;
        t.reasoning.push(`Reliability: ${(reliability * 100).toFixed(0)}% (+${relScore.toFixed(0)} pts)`);

        t.totalScore = score;
      }

      return transporters.sort((a, b) => b.totalScore - a.totalScore);
    } catch (e) {
      logger.error("Transporter ranking failed:", e);
      return [];
    }
  }
}
