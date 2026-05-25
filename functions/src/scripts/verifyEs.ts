import { Client } from "@elastic/elasticsearch";
import { logger } from "firebase-functions";
import * as dotenv from "dotenv";

dotenv.config();

const esClient = new Client({
  node: process.env.ES_URL || "",
  auth: { apiKey: process.env.ES_API_KEY || "" },
});

async function verify() {
  logger.log("Searching for TRANSPORTERs in Elasticsearch...");
  const result = await esClient.search({
    index: "users",
    body: {
      query: {
        term: { role: "TRANSPORTER" }
      }
    }
  });
  
  const total = (result.hits.total as any)?.value ?? 0;
  logger.log(`Found ${total} transporters`);
  result.hits.hits.forEach((hit: any) => {
    logger.log(`- ${hit._id}: ${hit._source.displayName} (${hit._source.availabilityStatus})`);
  });
}

verify().catch(logger.error);
