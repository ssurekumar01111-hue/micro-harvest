import { setGlobalOptions } from "firebase-functions/v2";
import * as admin from "firebase-admin";

// Initialize Firebase Admin
if (admin.apps.length === 0) {
  admin.initializeApp();
}

// Set global options to asia-south1
setGlobalOptions({ region: "asia-south1" });

// Agent
export { agentProcessListing } from "./agent/agentProcessListing";
export { processConversationTurn } from "./agent/processConversationTurn";

// Listings
export { syncListingToElastic } from "./listings/syncListingToElastic";
export { onProducerClaim, retryTransporterNotification } from "./listings/onProducerClaim";
export { onTransporterAccept } from "./listings/onTransporterAccept";
export { searchListings } from "./listings/searchListings";

// Users
export { onUserSync } from "./users/onUserSync";

// Handoffs
export { onGate1Confirm } from "./handoffs/onGate1Confirm";
export { onGate2Confirm } from "./handoffs/onGate2Confirm";
export { onDisputeRaised } from "./handoffs/onDisputeRaised";

// Payments
export { onProducerSettle } from "./payments/onProducerSettle";

// Scheduler
export { expireListings } from "./scheduler/expireListings";

// Elastic
export { getElasticStats } from "./elastic/getElasticStats";
export { producerSearch } from "./search/producerSearch";
