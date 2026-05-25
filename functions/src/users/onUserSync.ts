import * as functions from "firebase-functions/v2";
import { logger } from "firebase-functions";
import { Client } from "@elastic/elasticsearch";
import * as dotenv from "dotenv";

dotenv.config();

const esClient = new Client({
  node: process.env.ES_URL || "",
  auth: { apiKey: process.env.ES_API_KEY || "" },
});

export const onUserSync = functions.firestore.onDocumentWritten(
  { document: "users/{uid}", region: "asia-south1" },
  async (event) => {
    const uid = event.params.uid;
    const data = event.data?.after?.data();

    if (!data) {
      // Document deleted — remove from ES
      try {
        await esClient.delete({ index: "users", id: uid });
      } catch (e) {
        logger.log("ES delete failed or doc not found:", uid);
      }
      return;
    }

    // Only sync TRANSPORTER role. Transporters are the only role that needs to be in Elasticsearch.
    if (data.role !== "TRANSPORTER") {
      try {
        await esClient.delete({ index: "users", id: uid });
        logger.log(`[ES] Removed non-transporter user ${uid}`);
      } catch (e) {
        // ignore if not found
      }
      return;
    }

    const geoPoint = data.geoPoint;
    if (!geoPoint) {
      logger.log("No geoPoint for user:", uid);
      return;
    }

    try {
      await esClient.index({
        index: "users",
        id: uid,
        document: {
          uid,
          displayName: data.displayName || "",
          role: data.role,
          availabilityStatus: data.availabilityStatus || "UNAVAILABLE",
          location: {
            lat: geoPoint._latitude ?? geoPoint.latitude,
            lon: geoPoint._longitude ?? geoPoint.longitude,
          },
          geohash: data.geohash || "",
          radiusMiles: data.radiusMiles || 50,
          cropInterests: data.cropInterests || [],
          fcmTokens: data.fcmTokens || [],
          suspended: data.suspended || false,
        },
      });
      logger.log(`[ES] Synced user ${uid} to Elasticsearch`);
    } catch (error) {
      logger.error("[ES] Failed to sync user:", uid, error);
    }
  }
);
