import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { ListingStatus, HandoffModel } from "../../../packages/core/src/models";

// Initialize Firebase Admin if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const fcm = admin.messaging();

interface TransporterAcceptInput {
  listingId: string;
  transporterId: string;
}

export const onTransporterAccept = functions.https.onCall({ region: "asia-south1" }, async (request) => {
  const { listingId, transporterId } = request.data as TransporterAcceptInput;

  if (!listingId || !transporterId) {
    throw new functions.https.HttpsError("invalid-argument", "Missing listingId or transporterId");
  }

  const listingRef = db.collection("listings").doc(listingId);
  
  return db.runTransaction(async (transaction) => {
    const listingDoc = await transaction.get(listingRef);
    if (!listingDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Listing not found");
    }

    const listingData = listingDoc.data()!;

    // Verify listing status is MATCHED
    if (listingData.status !== ListingStatus.MATCHED) {
      throw new functions.https.HttpsError("failed-precondition", "Listing is not in MATCHED status");
    }

    // Verify listing was matched within last 30 minutes
    const matchedAt = listingData.matchedAt?.toDate();
    if (!matchedAt || (Date.now() - matchedAt.getTime()) > 30 * 60 * 1000) {
      throw new functions.https.HttpsError("deadline-exceeded", "The 30-minute acceptance window has expired.");
    }

    // Set transporterId and Transition status to LOCKED
    transaction.update(listingRef, {
      transporterId: transporterId,
      status: ListingStatus.LOCKED,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Create /handoffs/{handoffId} document
    const handoffRef = db.collection("handoffs").doc();
    const handoffId = handoffRef.id;

    const contractContent = JSON.stringify(listingData);
    const contractHash = crypto.createHash("sha256").update(contractContent).digest("hex");

    const handoffData: HandoffModel = {
      handoffId,
      listingId,
      growerId: listingData.growerId,
      producerId: listingData.producerId,
      transporterId: transporterId,
      contractHash,
      disputeStatus: null
    };

    transaction.set(handoffRef, handoffData);

    // Get tokens for all 3 parties
    const userIds = [listingData.growerId, listingData.producerId, transporterId];
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
          title: "Handoff Confirmed",
          body: `Your ${listingData.cropType} handoff is locked in. Pickup scheduled.`
        }
      });
    }

    return { success: true, handoffId };
  });
});
