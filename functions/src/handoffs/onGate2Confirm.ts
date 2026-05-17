import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import * as geofire from "geofire-common";
import { ListingStatus } from "../../../packages/core/src/models";

// Initialize Firebase Admin if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const fcm = admin.messaging();
const storage = admin.storage();

interface Gate2ConfirmInput {
  handoffId: string;
  producerId: string;
  gps: { latitude: number; longitude: number };
  imageBase64: string;
}

export const onGate2Confirm = functions.https.onCall({ region: "asia-south1" }, async (request) => {
  const { handoffId, producerId, gps, imageBase64 } = request.data as Gate2ConfirmInput;

  if (!handoffId || !producerId || !gps || !imageBase64) {
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

  // Verify listing is IN_TRANSIT
  if (listingData.status !== ListingStatus.IN_TRANSIT) {
    throw new functions.https.HttpsError("failed-precondition", "Listing is not IN_TRANSIT");
  }

  // Validate GPS within 500 meters of Producer's location
  const producerRef = db.collection("users").doc(producerId);
  const producerDoc = await producerRef.get();

  if (!producerDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Producer not found");
  }

  const producerData = producerDoc.data()!;
  const distanceInM = geofire.distanceBetween(
    [gps.latitude, gps.longitude],
    [producerData.geoPoint.latitude, producerData.geoPoint.longitude]
  ) * 1000;

  if (distanceInM > 500) {
    throw new functions.https.HttpsError("failed-precondition", `GPS location is too far from delivery point (${Math.round(distanceInM)}m)`);
  }

  // Upload image to Storage
  const bucket = storage.bucket();
  const filePath = `handoffs/${handoffId}/gate2.jpg`;
  const file = bucket.file(filePath);
  const buffer = Buffer.from(imageBase64, "base64");

  await file.save(buffer, {
    metadata: { contentType: "image/jpeg" },
    public: true
  });

  const imageUrl = file.publicUrl();
  const imageHash = crypto.createHash("sha256").update(imageBase64).digest("hex");

  // Calculate payment split
  const totalUSD = listingData.askingPriceUSD || 0;
  const platformFeeUSD = totalUSD * 0.05;
  const transporterFeeUSD = totalUSD * 0.15;
  const growerShareUSD = totalUSD * 0.80;

  // Update handoff and listing
  const batch = db.batch();

  batch.update(handoffRef, {
    gate2: {
      confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
      gps,
      imageUrl,
      imageHash,
      producerId
    },
    payment: {
      totalUSD,
      growerShareUSD,
      transporterFeeUSD,
      platformFeeUSD,
      stripePaymentId: null,
      releasedAt: null
    }
  });

  batch.update(listingRef, {
    status: ListingStatus.DELIVERED,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
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
        title: "Delivery Confirmed",
        body: "Cargo delivered successfully. Awaiting quality confirmation."
      }
    });
  }

  return { success: true };
});
