import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import * as geofire from "geofire-common";
import { ListingStatus } from "../../../packages/core/src/models";

// Initialize Firebase Admin if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const fcm = admin.messaging();

interface Gate1ConfirmInput {
  handoffId: string;
  transporterId: string;
  gps: { latitude: number; longitude: number };
  imageUrl: string;
  imageHash: string;
}

export const onGate1Confirm = functions.https.onCall({ region: "asia-south1" }, async (request) => {
  const { handoffId, transporterId, gps, imageUrl, imageHash } = request.data as Gate1ConfirmInput;

  if (!handoffId || !transporterId || !gps || !imageUrl || !imageHash) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required fields");
  }

  const handoffRef = db.collection("handoffs").doc(handoffId);
  const handoffDoc = await handoffRef.get();

  if (!handoffDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Handoff not found");
  }

  const handoffData = handoffDoc.data()!;
  const listingRef = db.collection("listings").doc(handoffData.listingId);
  const listingDoc = await listingRef.get();

  if (!listingDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Listing not found");
  }

  const listingData = listingDoc.data()!;

  // Verify handoff status is LOCKED (via listing status)
  if (listingData.status !== ListingStatus.LOCKED) {
    throw new functions.https.HttpsError("failed-precondition", "Listing is not in LOCKED status");
  }

  // Validate GPS within 500 meters of listing plotLocation
  const distanceInM = geofire.distanceBetween(
    [gps.latitude, gps.longitude],
    [listingData.plotLocation.latitude, listingData.plotLocation.longitude]
  ) * 1000;

  if (distanceInM > 500) {
    throw new functions.https.HttpsError("failed-precondition", `GPS location is too far from pickup point (${Math.round(distanceInM)}m)`);
  }

  // Update handoff and listing
  const batch = db.batch();

  batch.update(handoffRef, {
    gate1: {
      confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
      gps,
      imageUrl,
      imageHash,
      transporterId
    }
  });

  batch.update(listingRef, {
    status: ListingStatus.IN_TRANSIT,
    transitStartedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  await batch.commit();

  // Notifications
  const producerId = handoffData.producerId;
  const growerId = handoffData.growerId;
  const userDocs = await db.collection("users").where(admin.firestore.FieldPath.documentId(), "in", [producerId, growerId]).get();
  const tokens: string[] = [];
  userDocs.forEach(doc => {
    const data = doc.data();
    if (data.fcmTokens) tokens.push(...data.fcmTokens);
  });

  if (tokens.length > 0) {
    await fcm.sendEachForMulticast({
      tokens,
      notification: {
        title: "Pickup Confirmed",
        body: `Your cargo is in transit. Expected delivery based on ${listingData.perishTier}.`
      }
    });
  }

  return { success: true };
});
