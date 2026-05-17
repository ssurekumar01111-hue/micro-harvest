import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";

// Initialize Firebase Admin if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const fcm = admin.messaging();

export const onDisputeRaised = functions.firestore.onDocumentUpdated({
  document: "handoffs/{handoffId}",
  region: "asia-south1"
}, async (event) => {
  const beforeData = event.data?.before.data();
  const afterData = event.data?.after.data();

  if (!beforeData || !afterData) return;

  // Fires when disputeStatus changes to RAISED
  if (beforeData.disputeStatus !== "RAISED" && afterData.disputeStatus === "RAISED") {
    
    // Hold payment: set payment.releasedAt to null
    await event.data?.after.ref.update({
      "payment.releasedAt": null
    });

    // Get tokens for all 3 parties
    const userIds = [afterData.growerId, afterData.producerId, afterData.transporterId];
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
          title: "Dispute Raised",
          body: "A dispute has been raised on your handoff. Admin will review within 24hrs."
        }
      });
    }

    // Notify admin
    const adminToken = process.env.ADMIN_FCM_TOKEN;
    if (adminToken) {
      await fcm.send({
        token: adminToken,
        notification: {
          title: "New Dispute Alert",
          body: `Dispute raised on handoff: ${event.params.handoffId}`
        }
      });
    }

    // Log dispute details
    const disputeRef = db.collection("disputes").doc();
    await disputeRef.set({
      disputeId: disputeRef.id,
      handoffId: event.params.handoffId,
      listingId: afterData.listingId,
      growerId: afterData.growerId,
      producerId: afterData.producerId,
      transporterId: afterData.transporterId,
      raisedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: "OPEN"
    });
  }
});
