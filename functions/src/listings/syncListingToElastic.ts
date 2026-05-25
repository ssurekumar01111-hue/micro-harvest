import * as functions from "firebase-functions/v2";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { Client } from "@elastic/elasticsearch";
import * as dotenv from "dotenv";

dotenv.config();

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const esClient = new Client({
  node: process.env.ES_URL || "",
  auth: { apiKey: process.env.ES_API_KEY || "" },
});

/**
 * Triggered on any write to a listing document.
 * Ensures Firestore and Elasticsearch remain in sync.
 */
export const syncListingToElastic = functions.firestore.onDocumentWritten({
  document: "listings/{listingId}",
  region: "asia-south1"
}, async (event) => {
  const listingId = event.params.listingId;
  const snapshot = event.data;
  
  // If the document is deleted, remove it from the index
  if (!snapshot || !snapshot.after.exists) {
    try {
      await esClient.delete({
        index: "micro-harvest-listings",
        id: listingId,
      });
      logger.log(`[ES-Sync] Deleted listing ${listingId} from index`);
    } catch (error: any) {
      // Ignore 404s if already deleted
      if (error.meta?.statusCode !== 404) {
        logger.error(`[ES-Sync] Failed to delete listing ${listingId}:`, error);
      }
    }
    return;
  }

  const data = snapshot.after.data()!;
  const beforeData = snapshot.before.exists ? snapshot.before.data() : null;

  // Only sync if relevant fields changed or if it's a new document
  const fieldsToSync = [
    'status', 'cropType', 'weightKg', 'perishTier', 
    'askingPricePerTon', 'askingPriceUSD', 'plotLocation'
  ];

  const hasChanged = !beforeData || fieldsToSync.some(field => 
    JSON.stringify(data[field]) !== JSON.stringify(beforeData[field])
  );

  if (!hasChanged) {
    return;
  }

  try {
    await esClient.index({
      index: "micro-harvest-listings",
      id: listingId,
      document: {
        cropType: data.cropType,
        weightKg: data.weightKg,
        urgency: data.perishTier,
        status: data.status || "OPEN",
        location: {
          lat: data.plotLocation.latitude,
          lon: data.plotLocation.longitude,
        },
        askingPricePerTon: data.askingPricePerTon || data.askingPriceUSD || null,
        growerId: data.growerId,
        createdAt: data.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
      },
    });
    logger.log(`[ES-Sync] Successfully indexed/updated listing ${listingId} with status ${data.status}`);

    // On initial creation, update agentLog if applicable
    if (!beforeData) {
      const db = admin.firestore();
      const agentLogQuery = await db.collection("agentLogs")
        .where("growerId", "==", data.growerId)
        .orderBy("createdAt", "desc")
        .limit(1)
        .get();

      if (!agentLogQuery.empty) {
        const logDoc = agentLogQuery.docs[0];
        await logDoc.ref.update({
          listingId: listingId,
          elasticIndexed: true
        });
        logger.log(`[ES-Sync] Updated agentLog ${logDoc.id} for new listing ${listingId}`);
      }
    }
  } catch (error) {
    logger.error(`[ES-Sync] Failed to sync listing ${listingId}:`, error);
  }
});
