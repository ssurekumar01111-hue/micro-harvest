import * as functions from "firebase-functions/v2";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import { Client } from "@elastic/elasticsearch";
import * as dotenv from "dotenv";
import { ListingStatus } from "../../../packages/core/src/models";

dotenv.config();

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const fcm = admin.messaging();

function getEsClient() {
  return new Client({
    node: process.env.ES_URL || "",
    auth: { apiKey: process.env.ES_API_KEY || "" },
  });
}

export const onProducerClaim = functions.firestore.onDocumentUpdated({
  document: "listings/{listingId}",
  region: "asia-south1"
}, async (event) => {
  const esClient = getEsClient();
  try {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    if (!beforeData || !afterData) return;

    const wasOpen = beforeData.status === ListingStatus.OPEN;
    const producerJustClaimed = !beforeData.producerId && afterData.producerId;

    if (wasOpen && producerJustClaimed) {
      logger.log(`[onProducerClaim] Processing claim for listing ${event.params.listingId}`);
      
      await event.data?.after.ref.update({
        status: ListingStatus.MATCHED,
        matchedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      const radiusMiles = afterData.radiusMiles || 100;
      
      const esResult = await esClient.search({
        index: "users",
        body: { 
          query: {
            bool: {
              must: [
                { term: { role: "TRANSPORTER" } },
                { term: { availabilityStatus: "AVAILABLE" } },
                { term: { suspended: false } },
                {
                  geo_distance: {
                    distance: `${radiusMiles}mi`,
                    location: {
                      lat: afterData.plotLocation.latitude,
                      lon: afterData.plotLocation.longitude
                    }
                  }
                }
              ]
            }
          },
          _source: ["uid", "fcmTokens", "displayName", "availabilityStatus", "location"],
          size: 50 
        }
      });

      const hits = esResult.hits.hits;
      const matchedIds = hits.map(hit => hit._id as string);
      
      if (matchedIds.length > 0) {
        // Collect tokens directly from ES results
        const transporterTokens: string[] = [];
        hits.forEach((hit: any) => {
          if (hit._source.fcmTokens) {
            transporterTokens.push(...hit._source.fcmTokens);
          }
        });

        if (transporterTokens.length > 0) {
          await fcm.sendEachForMulticast({
            tokens: transporterTokens,
            notification: {
              title: "Haul Request Available",
              body: `${afterData.cropType} haul, ${afterData.weightKg}kg. Accept within 30 minutes.`
            }
          });
        }

        await event.data?.after.ref.update({
          notifiedTransporterCount: matchedIds.length,
          transporterNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          matchedTransporterIds: matchedIds
        });
      }
    }
  } catch (error) {
    logger.error("onProducerClaim failed:", error);
  }
});

export const retryTransporterNotification = functions.https.onCall({ 
  region: "asia-south1"
}, async (request) => {
  const esClient = getEsClient();
  const listingId = request.data.listingId;
  const listingRef = db.collection("listings").doc(listingId);
  const listingDoc = await listingRef.get();
  if (!listingDoc.exists) throw new functions.https.HttpsError("not-found", "Listing not found");
  const data = listingDoc.data()!;

  const radiusMiles = data.radiusMiles || 100;

  const esResult = await esClient.search({
    index: "users",
    body: {
      query: {
        bool: {
          must: [
            { term: { role: "TRANSPORTER" } },
            { term: { availabilityStatus: "AVAILABLE" } },
            { term: { suspended: false } },
            {
              geo_distance: {
                distance: `${radiusMiles}mi`,
                location: { lat: data.plotLocation.latitude, lon: data.plotLocation.longitude }
              }
            }
          ]
        }
      },
      _source: ["uid", "fcmTokens", "displayName", "availabilityStatus", "location"]
    }
  });

  const hits = esResult.hits.hits;
  const matchedIds = hits.map((hit: any) => hit._id as string);
  
  if (matchedIds.length > 0) {
    const transporterTokens: string[] = [];
    hits.forEach((hit: any) => {
      if (hit._source.fcmTokens) {
        transporterTokens.push(...hit._source.fcmTokens);
      }
    });

    if (transporterTokens.length > 0) {
      await fcm.sendEachForMulticast({ 
        tokens: transporterTokens, 
        notification: { 
          title: "Haul Request (Retry)", 
          body: `${data.cropType} haul` 
        } 
      });
    }
    await listingRef.update({ matchedTransporterIds: matchedIds });
  }
  return { notified: matchedIds.length };
});
