import * as admin from "firebase-admin";
import { logger } from "firebase-functions";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

async function cleanup() {
  logger.log("Starting cleanup of handoff documents...");
  const handoffs = await db.collection("handoffs").get();
  
  if (handoffs.empty) {
    logger.log("No handoff documents found.");
    return;
  }

  const batch = db.batch();
  let count = 0;
  
  handoffs.docs.forEach(doc => {
    const data = doc.data();
    const updates: any = {
      growerShare: admin.firestore.FieldValue.delete(),
      transporterShare: admin.firestore.FieldValue.delete(),
      totalAmountUsd: admin.firestore.FieldValue.delete(),
      platformFee: admin.firestore.FieldValue.delete(),
      askingPricePerTon: admin.firestore.FieldValue.delete(),
    };

    // Also check if weightKg is missing and add it if possible
    if (data.weightKg === undefined) {
        // Fallback logic could go here
    }

    batch.update(doc.ref, updates);
    count++;
  });
  
  await batch.commit();
  logger.log(`Cleaned ${count} handoff documents`);
}

cleanup().catch(logger.error);
