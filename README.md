# Micro-Harvest 🌾

> AI-powered agri-logistics platform connecting 
> Growers, Producers, and Transporters.
> Built for the Google Cloud Rapid Agent Hackathon 2026.

## What it does
Micro-Harvest is a three-sided marketplace that 
uses a Gemini AI agent to match surplus crop 
sellers (Growers) with artisanal buyers (Producers) 
and local haulers (Transporters) in real time.

## Architecture
- **Grower App** — Natural language listing 
  creation via Gemini AI agent
- **Producer App** — Geo-filtered surplus 
  discovery with Elastic MCP matching
- **Transporter App** — Haul alerts, GPS 
  gate confirmation, earnings tracking
- **Firebase Cloud Functions** — 8 TypeScript 
  functions handling all business logic
- **Elastic MCP** — Geo-spatial matching of 
  Producers and Transporters within radius
- **Gemini 3.1 Flash Lite** — Natural language 
  parsing and listing summary generation

## Tech Stack
| Layer | Technology |
|---|---|
| Mobile Apps | Flutter 3.x (3 apps) |
| State Management | BLoC |
| Backend | Firebase Cloud Functions (TypeScript) |
| Database | Firestore |
| Auth | Firebase Auth (Phone OTP + Google) |
| AI Agent | Gemini 3.1 Flash Lite |
| Geo Search | Elastic MCP Server |
| Notifications | Firebase Cloud Messaging |
| Payments | Stripe Connect (mocked) |

## Agent Flow
1. Grower types natural language input
2. Gemini extracts structured listing JSON
3. Elastic MCP finds nearby Producers + Transporters
4. Firestore listing created automatically
5. FCM alerts sent to matched parties
6. Full handoff lifecycle tracked to settlement

## Setup
### Prerequisites
- Flutter 3.x
- Node.js 22+
- Firebase CLI
- Google Cloud CLI

### Installation
```bash
git clone https://github.com/ssurekumar01111-hue/micro-harvest
cd micro-harvest
```

### Cloud Functions
```bash
cd functions
npm install
cp .env.example .env
# Fill in your API keys
firebase deploy --only functions
```

### Flutter Apps
```bash
cd apps/grower && flutter pub get
cd apps/producer && flutter pub get
cd apps/transporter && flutter pub get
```

## Live Demo
- Deployed Cloud Functions: Firebase (asia-south1)
- Elastic Search: Elastic Cloud (asia-south1)

## License
MIT License — see LICENSE file.
