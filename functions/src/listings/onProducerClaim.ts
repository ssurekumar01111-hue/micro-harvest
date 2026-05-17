import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import { Client } from "@elastic/elasticsearch";
import * as dotenv from "dotenv";
import { ListingStatus } from "../../../packages/core/src/models";

dotenv.config();

// Initialize Firebase Admin if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const fcm = admin.messaging();

const esClient = new Client({
  node: process.env.ES_URL,
  auth: {
    apiKey: process.env.ES_API_KEY || ""
  }
});

export const onProducerClaim = functions.firestore.onDocumentUpdated({
  document: "listings/{listingId}",
  region: "asia-south1"
}, async (event) => {
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();

  if (!beforeData || !afterData) return;

  // Fire when producerId is set on a listing
  if (!beforeData.producerId && afterData.producerId) {
    if (afterData.status !== ListingStatus.OPEN) {
      console.warn(`Listing ${event.params.listingId} is not OPEN. Current status: ${afterData.status}`);
      return;
    }

    // Transition status to MATCHED
    await event.data?.after.ref.update({
      status: ListingStatus.MATCHED,
      matchedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Query Elastic for Transporters within 50mi
    try {
      const esQuery = {
        bool: {
          must: [
            { term: { role: "TRANSPORTER" } },
            { term: { availabilityStatus: "AVAILABLE" } },
            {
              geo_distance: {
                distance: "50mi",
                location: {
                  lat: afterData.plotLocation.latitude,
                  lon: afterData.plotLocation.longitude
                }
              }
            }
          ]
        }
      };

      const esResult = await esClient.search({
        index: "users",
        body: { query: esQuery, size: 20 }
      });

      const transporters = esResult.hits.hits.map(hit => hit._source as any);
      const transporterTokens = transporters.flatMap(t => t.fcmTokens || []);

      if (transporterTokens.length > 0) {
        await fcm.sendEachForMulticast({
          tokens: transporterTokens,
          notification: {
            title: "Haul Request Available",
            body: `${afterData.cropType} haul, ${afterData.weightKg}kg. Accept within 30 minutes.`
          }
        });
      }
    } catch (error) {
      console.error("Elasticsearch/FCM failed in onProducerClaim:", error);
    }
  }
});
