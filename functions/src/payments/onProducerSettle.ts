import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import { ListingStatus } from "../../../packages/core/src/models";

// Initialize Firebase Admin if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const fcm = admin.messaging();

interface ProducerSettleInput {
  handoffId: string;
  producerId: string;
}

export const onProducerSettle = functions.https.onCall({ region: "asia-south1" }, async (request) => {
  const { handoffId, producerId } = request.data as ProducerSettleInput;

  if (!handoffId || !producerId) {
    throw new functions.https.HttpsError("invalid-argument", "Missing handoffId or producerId");
  }

  const handoffRef = db.collection("handoffs").doc(handoffId);
  const handoffDoc = await handoffRef.get();

  if (!handoffDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Handoff not found");
  }

  const handoffData = handoffDoc.data()!;

  if (handoffData.producerId !== producerId) {
    throw new functions.https.HttpsError("permission-denied", "Producer ID mismatch");
  }

  const listingRef = db.collection("listings").doc(handoffData.listingId);
  const listingDoc = await listingRef.get();

  if (!listingDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Listing not found");
  }

  const listingData = listingDoc.data()!;

  if (listingData.status !== ListingStatus.DELIVERED) {
    throw new functions.https.HttpsError("failed-precondition", "Listing is not in DELIVERED status");
  }

  const paymentId = "mock_" + Date.now();
  const now = admin.firestore.Timestamp.now();

  const batch = db.batch();

  batch.update(handoffRef, {
    "payment.releasedAt": now,
    "payment.stripePaymentId": paymentId
  });

  batch.update(listingRef, {
    status: ListingStatus.SETTLED,
    updatedAt: now
  });

  await batch.commit();

  // Notifications to all 3 parties
  const userIds = [handoffData.growerId, handoffData.producerId, handoffData.transporterId];
  const userDocs = await db.collection("users").where(admin.firestore.FieldPath.documentId(), "in", userIds).get();
  const tokens: string[] = [];
  userDocs.forEach(doc => {
    const data = doc.data();
    if (data.fcmTokens) tokens.push(...data.fcmTokens);
  });

  if (tokens.length > 0) {
    await fcm.sendEachForMulticast({
      tokens,
      notification: {
        title: "Payment Released",
        body: "Transaction complete. Payment has been processed."
      }
    });
  }

  return { success: true, paymentId };
});
