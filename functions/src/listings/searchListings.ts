import * as functions from "firebase-functions/v2";
import { logger } from "firebase-functions";
import { Client } from "@elastic/elasticsearch";
import * as dotenv from "dotenv";

dotenv.config();

const esClient = new Client({
  node: process.env.ES_URL || "",
  auth: { apiKey: process.env.ES_API_KEY || "" },
});

interface SearchListingsInput {
  cropType?: string;
  lat: number;
  lon: number;
  radiusMiles: number;
}

export const searchListings = functions.https.onCall({ 
  region: "asia-south1"
}, async (request) => {
  if (!request.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }

  const { cropType, lat, lon, radiusMiles } = request.data as SearchListingsInput;

  if (lat === undefined || lon === undefined || radiusMiles === undefined) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required parameters.");
  }

  try {
    const filters: any[] = [
      { term: { status: "OPEN" } },
      {
        geo_distance: {
          distance: `${radiusMiles}mi`,
          location: { lat, lon },
        },
      },
    ];

    if (cropType) {
      filters.push({ term: { cropType } });
    }

    const response = await esClient.search({
      index: "micro-harvest-listings",
      body: {
        query: { bool: { filter: filters } },
        size: 50,
      },
    });

    const hits = response.hits.hits.map((hit: any) => {
      const source = hit._source;
      return {
        id: hit._id,
        cropType: source.cropType,
        weightKg: source.weightKg,
        urgency: source.urgency, // Corrected to use source.urgency
        askingPricePerTon: source.askingPricePerTon, // Corrected to use source.askingPricePerTon
        location: source.location,
        growerId: source.growerId,
        createdAt: source.createdAt,
      };
    });

    return { hits };
  } catch (error) {
    logger.error("searchListings failed:", error);
    throw new functions.https.HttpsError("internal", "An error occurred while searching for listings.");
  }
});
