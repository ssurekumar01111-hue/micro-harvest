import { setGlobalOptions } from "firebase-functions/v2";

// Set global options to asia-south1
setGlobalOptions({ region: "asia-south1" });

// Agent
export { agentProcessListing } from "./agent/agentProcessListing";

// Listings
export { onProducerClaim } from "./listings/onProducerClaim";
export { onTransporterAccept } from "./listings/onTransporterAccept";

// Handoffs
export { onGate1Confirm } from "./handoffs/onGate1Confirm";
export { onGate2Confirm } from "./handoffs/onGate2Confirm";
export { onDisputeRaised } from "./handoffs/onDisputeRaised";

// Payments
export { onProducerSettle } from "./payments/onProducerSettle";

// Scheduler
export { expireListings } from "./scheduler/expireListings";
