import * as functions from "firebase-functions/v2";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import * as geofire from "geofire-common";
import Stripe from "stripe";
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

interface Gate2ConfirmInput {
  handoffId: string;
  producerId?: string; // Optional producerId
  gps: { latitude: number; longitude: number };
  imageUrl: string;
  imageHash: string;
}

export const onGate2Confirm = functions.https.onCall({ region: "asia-south1" }, async (request) => {
  try {
    const { handoffId, producerId, gps, imageUrl, imageHash } = request.data as Gate2ConfirmInput;

    const handoffRef = db.collection("handoffs").doc(handoffId);
    const handoffDoc = await handoffRef.get();

    if (!handoffDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Handoff not found");
    }

    const handoffData = handoffDoc.data()!;
    // Use producerId from request, or fallback to the one in handoff data
    const effectiveProducerId = producerId || handoffData.producerId;

    if (!handoffId || !effectiveProducerId || !gps || !imageUrl || !imageHash) {
      throw new functions.https.HttpsError("invalid-argument", "Missing required fields");
    }

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
    const producerRef = db.collection("users").doc(effectiveProducerId);
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

    // Calculate payment split
    const pricePerTon = listingData.askingPricePerTon 
      || listingData.askingPriceUSD 
      || 0;
    const weightTons = (listingData.weightKg || 0) / 1000;
    const totalUSD = Math.round(pricePerTon * weightTons);

    const growerShareUSD = Math.round(totalUSD * 0.80);
    const transporterFeeUSD = Math.round(totalUSD * 0.15);
    const platformFeeUSD = Math.round(totalUSD * 0.05);

    // Automatic payment settlement
    const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || "", {
      apiVersion: "2023-10-16" as any, // Use a stable API version
    });

    // Ensure minimum of 50 INR (5000 paise)
    const amountPaise = Math.max(Math.round(totalUSD * 100), 5000); 

    // Create Stripe Payment Intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountPaise,
      currency: "inr",
      payment_method_types: ["card"],
      confirm: false,
      metadata: {
        handoffId,
        listingId: handoffData.listingId,
        producerId: handoffData.producerId,
        growerId: handoffData.growerId,
        transporterId: handoffData.transporterId,
      },
    });

    // Update handoff and listing
    const batch = db.batch();

    batch.update(handoffRef, {
      gate2: {
        confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
        gps,
        imageUrl,
        imageHash,
        producerId: effectiveProducerId
      },
      payment: {
        totalUSD,
        growerShareUSD,
        transporterFeeUSD,
        platformFeeUSD,
        stripePaymentId: paymentIntent.id,
        stripeClientSecret: paymentIntent.client_secret,
        releasedAt: admin.firestore.FieldValue.serverTimestamp(),
        currency: "inr",
        amountPaise: amountPaise,
      }
    });

    batch.update(listingRef, {
      status: ListingStatus.SETTLED,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    await batch.commit();

    // Update ES status
    try {
      await esClient.update({
        index: "micro-harvest-listings",
        id: handoffData.listingId,
        doc: { status: ListingStatus.SETTLED },
      });
    } catch (esError: any) {
      logger.error("[ES] Status update failed for listing:", handoffData.listingId, esError);
    }

    // Notifications to all 3 parties
    const growerSnap = await db.collection("users").doc(handoffData.growerId).get();
    const producerSnap = await db.collection("users").doc(handoffData.producerId).get();
    const transporterSnap = await db.collection("users").doc(handoffData.transporterId).get();

    const allTokens = [
      ...(growerSnap.data()?.fcmTokens || []),
      ...(producerSnap.data()?.fcmTokens || []),
      ...(transporterSnap.data()?.fcmTokens || []),
    ];

    if (allTokens.length > 0) {
      await fcm.sendEachForMulticast({
        tokens: allTokens,
        notification: {
          title: "Delivery Complete — Payment Processed",
          body: `Transaction of $${totalUSD} has been settled`,
        },
        data: {
          type: "PAYMENT_SETTLED",
          handoffId: handoffId,
        },
      });
    }

    return { success: true };
  } catch (error) {
    logger.error("onGate2Confirm failed:", error);
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError("internal", "An error occurred during transaction");
  }
});
