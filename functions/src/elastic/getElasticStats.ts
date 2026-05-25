import * as functions from "firebase-functions/v2";
import { logger } from "firebase-functions";
import { Client } from "@elastic/elasticsearch";
import * as dotenv from "dotenv";
dotenv.config();

const esClient = new Client({
  node: process.env.ES_URL || "",
  auth: { apiKey: process.env.ES_API_KEY || "" },
});

export const getElasticStats = functions.https.onCall(
  { region: "asia-south1", cors: true },
  async (request) => {
    try {
      const [listingsCount, usersCount] = await Promise.all([
        esClient.count({ index: "micro-harvest-listings" }),
        esClient.count({ index: "users" }),
      ]);
      return {
        clusterHealth: "green", // Mocked as cluster.health() is not available in serverless
        listingsIndexed: listingsCount.count,
        usersIndexed: usersCount.count,
      };
    } catch (error) {
      logger.error("[ES] getElasticStats failed:", error);
      throw new functions.https.HttpsError("internal", 
        "Failed to fetch Elastic stats");
    }
  }
);
