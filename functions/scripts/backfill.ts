import * as admin from "firebase-admin";
import { Client } from "@elastic/elasticsearch";
import * as dotenv from "dotenv";
import * as path from "path";

dotenv.config({ path: path.join(__dirname, "..", ".env") });

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const esClient = new Client({
  node: process.env.ES_URL || "",
  auth: { apiKey: process.env.ES_API_KEY || "" }
});

async function backfill() {
  console.log("Starting backfill script...");
  try {
    const snapshot = await db.collection("users").get();
    let indexed = 0, failed = 0;
    
    for (const doc of snapshot.docs) {
      const d = doc.data();
      try {
        await esClient.index({
          index: "users",
          id: doc.id,
          document: {
            uid: doc.id,
            name: d.displayName || d.name || "",
            role: d.role || "",
            availabilityStatus: d.availabilityStatus || "UNAVAILABLE",
            location: d.geoPoint ? {
              lat: d.geoPoint.latitude,
              lon: d.geoPoint.longitude
            } : null,
            fcmTokens: d.fcmTokens || [],
            suspended: d.suspended || false,
            createdAt: d.createdAt?.toDate?.()?.toISOString() || new Date().toISOString()
          }
        });
        indexed++;
      } catch(e) {
        console.error(`Failed to index user ${doc.id}:`, e);
        failed++;
      }
    }
    console.log(`Done. Total: ${snapshot.size}, Indexed: ${indexed}, Failed: ${failed}`);
  } catch (err) {
    console.error("Fatal error during backfill:", err);
  } finally {
    process.exit(0);
  }
}

backfill();
