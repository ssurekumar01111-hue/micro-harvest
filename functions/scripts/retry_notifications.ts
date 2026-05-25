import * as admin from "firebase-admin";
import { Client } from "@elastic/elasticsearch";
import * as dotenv from "dotenv";
import * as path from "path";

dotenv.config({ path: path.join(__dirname, "..", ".env") });

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const fcm = admin.messaging();
const esClient = new Client({
  node: process.env.ES_URL || "",
  auth: { apiKey: process.env.ES_API_KEY || "" }
});

async function retry(listingId: string) {
  console.log(`Retrying for ${listingId}...`);
  const listingRef = db.collection("listings").doc(listingId);
  const listingDoc = await listingRef.get();

  if (!listingDoc.exists) {
    console.error("Not found");
    return;
  }

  const data = listingDoc.data()!;
  let transporterTokens: string[] = [];
  let notifiedCount = 0;

  try {
    const esResult = await esClient.search({
      index: "users",
      body: {
        query: {
          bool: {
            must: [
              { term: { role: "TRANSPORTER" } },
              { term: { availabilityStatus: "AVAILABLE" } },
              { term: { suspended: false } },
              {
                geo_distance: {
                  distance: "50mi",
                  location: {
                    lat: data.plotLocation.latitude,
                    lon: data.plotLocation.longitude
                  }
                }
              }
            ]
          }
        },
        size: 20
      }
    });

    const hits = esResult.hits.hits;
    if (hits.length > 0) {
      transporterTokens = hits.flatMap(hit => (hit._source as any).fcmTokens || []);
      notifiedCount = hits.length;
    }
  } catch (error) {
    console.error("ES failed:", error);
  }

  if (notifiedCount > 0) {
    await fcm.sendEachForMulticast({
      tokens: transporterTokens,
      notification: {
        title: "Haul Request (Retry)",
        body: `${data.cropType} haul, ${data.weightKg}kg. Accept within 30 minutes.`
      }
    });

    await listingRef.update({
      notifiedTransporterCount: notifiedCount,
      transporterNotifiedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`Notified ${notifiedCount} transporters.`);
  } else {
    console.log("No transporters found.");
  }
}

async function run() {
  await retry('UkRU7jnXxZlrBxCsgJqP');
  await retry('TJ6Ei0gOl0WpK6GhwLGJ');
  process.exit(0);
}

run();
