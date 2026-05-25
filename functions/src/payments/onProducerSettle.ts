import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import Stripe from "stripe";
import * as dotenv from "dotenv";

dotenv.config();

export const onProducerSettle = functions.https.onCall(
  { 
    region: "asia-south1",
  },
  async (request) => {
    const db = admin.firestore();
    const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || "", {
      apiVersion: "2026-04-22.dahlia",
    });

    const { handoffId } = request.data;
    const producerId = request.auth?.uid;

    if (!handoffId || !producerId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing handoffId"
      );
    }

    const handoffRef = db.collection("handoffs").doc(handoffId);
    const handoffSnap = await handoffRef.get();

    if (!handoffSnap.exists) {
      throw new functions.https.HttpsError("not-found", "Handoff not found");
    }

    const handoff = handoffSnap.data()!;

    if (handoff.producerId !== producerId) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Not authorized"
      );
    }

    if (handoff.payment?.releasedAt !== null && 
        handoff.payment?.releasedAt !== undefined &&
        handoff.payment?.stripePaymentId !== null) {
      throw new functions.https.HttpsError(
        "already-exists",
        "Payment already released"
      );
    }

    // Get total amount from handoff payment data
    // Amount in INR paise
    const totalUSD = handoff.payment?.totalUSD || 0;
    const amountPaise = Math.round(totalUSD * 100);

    // Create Stripe Payment Intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountPaise,
      currency: "inr",
      payment_method_types: ["card"],
      metadata: {
        handoffId,
        listingId: handoff.listingId,
        producerId: handoff.producerId,
        growerId: handoff.growerId,
        transporterId: handoff.transporterId,
      },
    });

    // Update handoff with payment intent and releasedAt
    await handoffRef.update({
      "payment.stripePaymentId": paymentIntent.id,
      "payment.stripeClientSecret": paymentIntent.client_secret,
      "payment.releasedAt": admin.firestore.FieldValue.serverTimestamp(),
      "payment.currency": "inr",
      "payment.amountPaise": amountPaise,
    });

    // Update listing status to SETTLED
    await db.collection("listings").doc(handoff.listingId).update({
      status: "SETTLED",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send FCM to grower and transporter
    const [growerSnap, transporterSnap] = await Promise.all([
      db.collection("users").doc(handoff.growerId).get(),
      db.collection("users").doc(handoff.transporterId).get(),
    ]);

    const growerTokens = growerSnap.data()?.fcmTokens || [];
    const transporterTokens = transporterSnap.data()?.fcmTokens || [];
    const allTokens = [...growerTokens, ...transporterTokens];

    if (allTokens.length > 0) {
      await admin.messaging().sendEachForMulticast({
        tokens: allTokens,
        notification: {
          title: "Payment Released",
          body: `Payment of $${totalUSD} has been released`,
        },
        data: {
          type: "PAYMENT_RELEASED",
          handoffId,
        },
      });
    }

    return {
      success: true,
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
      totalUSD,
      amountPaise,
    };
  }
);
