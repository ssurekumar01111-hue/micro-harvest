# 🌾 Micro-Harvest
### AI-Powered Agricultural Logistics Platform
**Google Cloud Rapid Agent Hackathon 2026 · Elastic Track**

> Connecting Growers, Producers, and Transporters through conversational AI, real-time geo-matching, and automated payment settlement — built for rural India.

**Admin Panel:** https://micro-harvest.web.app
**Hackathon:** [Google Cloud Rapid Agent Hackathon 2026](https://rapid-agent.devpost.com)
**Track:** Elastic Track · Prize Pool: $10,000
**Built by:** Morning Star · Banda, Uttar Pradesh, India

---

## 🎯 Problem Statement

Indian farmers lose an estimated **16% of their produce annually** due to supply chain inefficiencies. Rural growers lack tools to:
- Quickly list surplus crops and find buyers in their language
- Connect with nearby transporters based on real location data
- Receive fair transparent payments without middlemen
- Operate in low-connectivity rural environments
- Understand logistics decisions in plain language

Micro-Harvest solves all five through a conversational AI agent with explainable reasoning, real-time geo-matching via Elasticsearch, and fully automated payment settlement.

---

## 🏗️ Architecture

### 4-App Monorepo

| App | Platform | Role |
|-----|----------|------|
| **Grower App** | Flutter Android | Farmers list surplus crops via AI voice agent |
| **Producer App** | Flutter Android | Buyers discover and claim listings via geo-search |
| **Transporter App** | Flutter Android | Drivers accept hauls and confirm delivery |
| **Admin Panel** | Flutter Web | Platform management and Elastic monitoring |

### Backend

| Service | Provider | Purpose |
|---------|----------|---------|
| Authentication | Firebase Auth (Phone OTP) | All 3 roles |
| Database | Cloud Firestore | Listings, handoffs, conversations |
| AI / NLP | Gemini 2.5 Flash | Listing extraction, conversational agent |
| Search & Matching | Elastic Cloud (asia-south1) | Geo-search, transporter matching, MCP |
| Cloud Functions | Firebase Functions v2 | 14 callable and trigger functions |
| Payments | Stripe (Test Mode) | Automatic 3-way settlement |
| Offline Storage | Hive (Flutter) | Offline queue for grower app |
| Push Notifications | Firebase Cloud Messaging | Haul alerts, status updates |

---

## ✨ Key Features

### 🤖 AI Operational Reasoning Engine
After a grower confirms a listing, the Intelligence Service produces a structured reasoning output with:
- **Urgency Score** (0–100) based on perishability tier, weather risk, and time
- **Weather Risk Analysis** — rainfall probability boosts urgency automatically
- **Explainable Decision Factors** — plain English reasons shown to the grower
- **Recommended Transport Radius** — dynamic based on urgency and crop type

### 🔍 Elasticsearch Integration (Elastic Track)
Three distinct Elastic use cases:
1. **MCP Server + Agent Builder** — Gemini tool-calls `find_nearby_transporters` via Elastic MCP, results stored in `agentLog.matchedTransporterIds`
2. **Geo-Distance Producer Discovery** — listings feed powered by `geo_point` queries on `micro-harvest-listings` index
3. **Conversational Producer Search** — natural language → Gemini extraction → Elastic filters (e.g. "urgent Merlot under 3000 per ton")

### 📡 Offline-First Resilience
Built for rural India where connectivity is unreliable:
- Hive local queue persists listing confirmations across app restarts
- Auto-sync fires when internet returns via `connectivity_plus`
- FIFO queue guarantees ordered, duplicate-free sync
- `listingSource: AGENT_OFFLINE` recorded in Firestore for full audit trail

### 💳 Automated Payment Settlement
Zero manual intervention — triggered automatically on Gate 2 delivery confirmation:
- **80%** → Grower
- **15%** → Transporter  
- **5%** → Platform
- SHA-256 contract hash on every handoff for tamper-evident audit trail

---

## 🔄 Complete Flow
Grower speaks listing → Gemini extracts fields → Listing indexed to Elasticsearch
→ Producer discovers via geo-search → Producer claims listing
→ Elastic geo-query finds nearest transporters → FCM haul alert sent
→ Transporter accepts → Gate 1 GPS + photo at pickup
→ Gate 2 GPS + photo at delivery → Stripe Payment Intent created
→ All 3 apps show SETTLED with correct 80/15/5 split

---

## 🧠 Cloud Functions (14 deployed to asia-south1)

| Function | Type | Purpose |
|----------|------|---------|
| `agentProcessListing` | Callable | Gemini NLP + ES tool-calling + listing creation |
| `processConversationTurn` | Callable | Multi-turn agent with Firestore context |
| `onListingCreated` | Firestore trigger | Index new listing to Elasticsearch |
| `onProducerClaim` | Firestore trigger | ES transporter geo-search + FCM alerts |
| `onTransporterAccept` | Callable | Create handoff + lock listing |
| `onGate1Confirm` | Callable | Record Gate 1 GPS + photo hash |
| `onGate2Confirm` | Callable | Record Gate 2 + create Stripe Payment Intent |
| `onProducerSettle` | Callable | Manual settlement backup |
| `onUserSync` | Firestore trigger | Sync transporter profiles to Elastic |
| `producerSearch` | Callable | Gemini NLP → Elastic geo-search |
| `getElasticStats` | Callable | ES cluster health + index counts for admin |
| `syncListingToElastic` | Callable | Real-time status sync OPEN→SETTLED |
| `retryTransporterNotification` | Callable | FCM retry for missed haul alerts |
| `onDisputeRaised` | Firestore trigger | Dispute workflow initiation |

---

## 🛠️ Tech Stack

**Frontend:** Flutter 3.x, flutter_bloc, go_router, Hive, speech_to_text, flutter_tts, google_maps_flutter, flutter_stripe

**Backend:** Firebase Functions v2 (Node 22), @google/generative-ai, @elastic/elasticsearch v8, stripe, firebase-admin

**Infrastructure:** Firebase (Blaze), Elastic Cloud Serverless (asia-south1 GCP), Stripe Test Mode, Firebase Hosting

---

## 🚀 Local Setup

### Prerequisites
- Flutter 3.x
- Node.js 22+
- Firebase CLI
- A Firebase project with Blaze plan
- Elastic Cloud account
- Stripe account

### 1. Clone & Install

```bash
git clone https://github.com/[username]/micro-harvest.git
cd micro-harvest
```

### 2. Configure Environment

Each app requires a `.env.json` file. Copy the example and fill in your values:

```bash
cp apps/grower/.env.example.json apps/grower/.env.json
cp apps/producer/.env.example.json apps/producer/.env.json
cp apps/transporter/.env.example.json apps/transporter/.env.json
cp apps/admin/.env.example.json apps/admin/.env.json
```

Fill in your Firebase, Stripe, and Google Maps keys in each `.env.json`.

### 3. Cloud Functions

```bash
cd functions
cp .env.example .env
# Fill in GEMINI_API_KEY, ELASTIC_URL, ELASTIC_API_KEY, STRIPE_SECRET_KEY
npm install
npm run build
firebase deploy --only functions
```

### 4. Build Apps

```bash
# Each app has a build script
cd apps/grower && ./build.ps1      # Windows
cd apps/producer && ./build.ps1
cd apps/transporter && ./build.ps1
cd apps/admin && ./build.ps1       # Deploys to Firebase Hosting
```

---

## 🧪 Demo Credentials

| App | Phone | OTP |
|-----|-------|-----|
| Grower App | +16666666666 | 123456 |
| Producer App | +918888888888 | 123456 |
| Transporter App | +917777777777 | 123456 |
| Admin Panel | admin@microharvest.com | Admin@123 |

**Stripe Test Card:** `4242 4242 4242 4242` · Any future expiry · Any CVV

---

## 📁 Repository Structure
micro-harvest/
├── apps/
│   ├── grower/          # Flutter Android — Grower app
│   ├── producer/        # Flutter Android — Producer app
│   ├── transporter/     # Flutter Android — Transporter app
│   └── admin/           # Flutter Web — Admin panel
├── functions/
│   └── src/
│       ├── agent/       # agentProcessListing, processConversationTurn
│       ├── listings/    # onProducerClaim, onTransporterAccept, onListingCreated
│       ├── handoffs/    # onGate1Confirm, onGate2Confirm
│       ├── payments/    # onProducerSettle
│       ├── search/      # producerSearch
│       ├── users/       # onUserSync
│       └── utils/       # geminiWithFallback
├── firestore.rules
├── firebase.json
└── README.md

---

## ⚠️ Known Limitations

| Area | Current State | Planned Fix |
|------|--------------|-------------|
| Payments | Stripe test mode only | Stripe Connect post-hackathon |
| Crops | 5 wine grape varieties | Expand to vegetables, grains |
| Weather | Simulated model (65%) | OpenWeatherMap / IMD API |
| GPS Check | Gate proximity not enforced | Re-enable 500m validation |
| Ratings | Hardcoded 5.0 | Build actual review system |

---

## 📅 Timeline

Built in **6 days** (May 17–23, 2026) for the Google Cloud Rapid Agent Hackathon 2026.

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

*Micro-Harvest · Built for Google Cloud Rapid Agent Hackathon 2026 · Morning Star · Banda, Uttar Pradesh, India*

