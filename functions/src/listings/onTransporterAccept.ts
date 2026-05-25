import * as functions from "firebase-functions/v2";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { Client } from "@elastic/elasticsearch";
import * as dotenv from "dotenv";
import { ListingStatus } from "../../../packages/core/src/models";

dotenv.config();

// Initialize Firebase Admin if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const fcm = admin.messaging();

const esClient = new Client({
  node: process.env.ES_URL || "",
  auth: { apiKey: process.env.ES_API_KEY || "" },
});

interface TransporterAcceptInput {
  listingId: string;
  transporterId: string;
}

export const onTransporterAccept = functions.https.onCall({ region: "asia-south1" }, async (request) => {
  try {
    const { listingId, transporterId } = request.data as TransporterAcceptInput;

    if (!listingId || !transporterId) {
      throw new functions.https.HttpsError("invalid-argument", "Missing listingId or transporterId");
    }

    const listingRef = db.collection("listings").doc(listingId);
    const listingSnap = await listingRef.get();

    if (!listingSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Listing not found");
    }

    const listingData = listingSnap.data()!;

    // Verify listing status is MATCHED
    if (listingData.status !== ListingStatus.MATCHED) {
      throw new functions.https.HttpsError("failed-precondition", "Listing is not in MATCHED status");
    }

    // Verify listing was matched within last 24 hours
    const matchedAt = listingData.matchedAt?.toDate();
    const now = new Date();
    const windowMs = 24 * 60 * 60 * 1000; // 24 hours

    if (!matchedAt || (now.getTime() - matchedAt.getTime()) > windowMs) {
      throw new functions.https.HttpsError("deadline-exceeded", "The 24-hour acceptance window has expired.");
    }

    // Prepare Handoff Data
    const handoffRef = db.collection("handoffs").doc();
    const handoffId = handoffRef.id;

    const weightKg = listingData.weightKg || 0;
    const askingPricePerTon = listingData.askingPriceUSD || 0;
    const totalUSD = (weightKg / 1000) * askingPricePerTon;
    const growerShareUSD = totalUSD * 0.80;
    const transporterFeeUSD = totalUSD * 0.15;
    const platformFeeUSD = totalUSD * 0.05;

    const contractContent = JSON.stringify(listingData);
    const contractHash = crypto.createHash("sha256").update(contractContent).digest("hex");

    const handoffData = {
      handoffId,
      listingId,
      growerId: listingData.growerId,
      producerId: listingData.producerId,
      transporterId: transporterId,
      contractHash,
      gate1: null,
      gate2: null,
      payment: {
        totalUSD,
        growerShareUSD,
        transporterFeeUSD,
        platformFeeUSD,
        stripePaymentId: null,
        stripeClientSecret: null,
        releasedAt: null,
      },
      disputeStatus: null,
      weightKg,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    // Transaction only for writes
    await db.runTransaction(async (transaction) => {
      transaction.update(listingRef, {
        transporterId: transporterId,
        status: ListingStatus.LOCKED,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      transaction.set(handoffRef, handoffData);
    });

    // Update ES status
    try {
      await esClient.update({
        index: "micro-harvest-listings",
        id: listingId,
        doc: { status: ListingStatus.LOCKED },
      });
    } catch (esError) {
      logger.error("[ES] Status update failed for listing:", listingId, esError);
    }

    // Notify parties
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
  } catch (error) {
    logger.error("onTransporterAccept failed:", error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError("internal", "An error occurred during transaction");
  }
});

