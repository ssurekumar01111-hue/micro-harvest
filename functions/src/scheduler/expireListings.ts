import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import { ListingStatus } from "../../../packages/core/src/models";

// Initialize Firebase Admin if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const fcm = admin.messaging();

export const expireListings = functions.scheduler.onSchedule({
  schedule: "every 15 minutes",
  region: "asia-south1"
}, async (event) => {
  const now = admin.firestore.Timestamp.now();

  const expiredListingsQuery = db.collection("listings")
    .where("status", "==", ListingStatus.OPEN)
    .where("harvestWindowEnd", "<", now.toDate());

  const snapshot = await expiredListingsQuery.get();
  console.log(`Found ${snapshot.size} expired listings.`);

  if (snapshot.empty) return;

  const batch = db.batch();
  const notificationPromises: Promise<any>[] = [];

  for (const doc of snapshot.docs) {
    const listingData = doc.data();
    batch.update(doc.ref, {
      status: ListingStatus.EXPIRED,
      updatedAt: now
    });

    // Notify Grower
    notificationPromises.push((async () => {
      const growerDoc = await db.collection("users").doc(listingData.growerId).get();
      const growerData = growerDoc.data();
      if (growerData?.fcmTokens && growerData.fcmTokens.length > 0) {
        await fcm.sendEachForMulticast({
          tokens: growerData.fcmTokens,
          notification: {
            title: "Listing Expired",
            body: `Your ${listingData.cropType} listing has expired. Create a new one to find buyers.`
          }
        });
      }
    })());
  }

  await batch.commit();
  await Promise.all(notificationPromises);

  console.log(`Successfully expired ${snapshot.size} listings.`);
});
