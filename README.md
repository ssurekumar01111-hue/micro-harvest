# Micro-Harvest

Micro-Harvest is an AI-powered agricultural surplus marketplace connecting growers, producers, and transporters across India to streamline supply chain logistics, optimize freight matching, and reduce post-harvest waste through intelligent, real-time spatial data.

## Architecture
Micro-Harvest is a multi-platform ecosystem built for agricultural logistics, featuring AI-driven matching and real-time tracking across mobile and web interfaces. It leverages Firebase for backend infrastructure, ensuring seamless data synchronization between all actors, while utilizing Elasticsearch for high-performance spatial queries. The platform provides tailored interfaces for each stakeholder, optimizing crop listing, haul management, and administrative oversight.

- **apps/grower** (Flutter Android)
- **apps/producer** (Flutter Android)
- **apps/transporter** (Flutter Android)
- **apps/admin** (Flutter Web — https://micro-harvest.web.app)

## Elastic Track Integration
- **MCP Endpoint:** `https://asia-south1-micro-harvest.cloudfunctions.net`
- **Agent Builder Tools:**
    - `search_crop_listings`: Queries active surplus crops using spatial criteria.
    - `find_nearby_transporters`: Locates available transporters within a defined radius.
- **Gemini & Elasticsearch:** Gemini utilizes tool-calling to convert conversational requests (e.g., "Find transport for 5 tons of Pinot Noir near Nashik") into structured queries against the Elasticsearch indices.
- **Indices:**
    - `micro-harvest-listings`: `geo_point` mapping for efficient location-based matching.
    - `users`: `geo_point` mapping for transporter and producer positioning.
- **Real-time Sync:** All Cloud Functions maintain Elasticsearch sync; `onUserSync` automatically indexes/updates transporter availability and location upon profile changes.

## Tech Stack
- **Frontend:** Flutter
- **Backend:** Firebase (Firestore, Auth, FCM, Cloud Functions, Hosting)
- **Search & Spatial:** Elasticsearch (Elastic Cloud, asia-south1)
- **AI:** Gemini 2.5 Flash
- **Payments:** Stripe, Razorpay-ready

## Demo Credentials
- **Grower:** +91 test phone / OTP: 123456
- **Producer:** +91 test phone / OTP: 123456
- **Transporter:** +91 test phone / OTP: 123456
- **Admin:** `admin@microharvest.com` / `Admin@123`
- **Admin Panel:** https://micro-harvest.web.app

## Cloud Functions
1. **agentProcessListing**: AI-powered extraction and indexing for new crop listings.
2. **onProducerClaim**: Orchestrates producer listing claims and transporter matchmaking.
3. **onTransporterAccept**: Manages transporter haul request acceptance.
4. **onGate1Confirm**: Records pickup confirmation and status updates.
5. **onGate2Confirm**: Handles delivery confirmation and automated payment settlement.
6. **onDisputeRaised**: Manages dispute logging, admin alerts, and resolution status.
7. **onUserSync**: Automatically synchronizes user data with Elasticsearch for searchability.
8. **expireListings**: Scheduled cron job to handle stale listing expirations.
9. **searchListings**: Facilitates high-performance spatial queries for available hauls.

## Setup Instructions
1. `git clone <repository-url>`
2. `firebase login`
3. `cd functions && npm install`
4. `flutter pub get` in each app directory (`apps/grower`, `apps/producer`, `apps/transporter`, `apps/admin`).
5. Configure `.env` files in `functions/` with `GEMINI_API_KEY`, `ES_URL`, `ES_API_KEY`, `STRIPE_SECRET_KEY`.
6. `firebase deploy`
7. `flutter run` in the desired app directory.

## Payment Flow
Payment settlement occurs automatically upon Gate 2 confirmation. A Stripe Payment Intent is created, and the total amount is automatically split (80% grower, 15% transporter, 5% platform) and recorded in the Firestore handoff document.
