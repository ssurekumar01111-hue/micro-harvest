import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import * as dotenv from "dotenv";
import { IntelligenceService } from "./intelligence";
import { generateWithFallback } from "../utils/geminiWithFallback";

dotenv.config();
const apiKey = process.env.GEMINI_API_KEY || "";

function stripMarkdown(text: string): string {
  return text
    .replace(/\*\*(.*?)\*\*/g, '$1')  // bold
    .replace(/\*(.*?)\*/g, '$1')       // italic
    .replace(/#{1,6}\s/g, '')          // headers
    .replace(/`(.*?)`/g, '$1')         // code
    .replace(/Option \d+.*?:/gi, '')   // option labels
    .replace(/\n{3,}/g, '\n')          // excess newlines
    .trim();
}

interface ConversationTurnInput {
  conversationId: string;
  message: string;
  growerId: string;
  plotLocation: { latitude: number; longitude: number };
}

export const processConversationTurn = functions.https.onCall({ 
  region: "asia-south1" 
}, async (request) => {
  const db = admin.firestore();
  const { conversationId, message, growerId, plotLocation } = request.data as ConversationTurnInput;

  if (!message || !growerId || !plotLocation) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required fields");
  }

  // FIX 1 — Backend: robust ID resolution
  const resolvedId = (conversationId && conversationId.trim() !== "") 
    ? conversationId 
    : db.collection("conversations").doc().id;

  const convRef = db.collection("conversations").doc(resolvedId);
  const convDoc = await convRef.get();

  let state = convDoc.exists ? convDoc.data()! : {
    growerId,
    messages: [],
    extractedData: {},
    status: "ACTIVE",
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  };

  const existingData = state.extractedData || {};

  // 1. Extraction Pass

  const extractionPrompt = `You are an operational agricultural logistics assistant.
Your goal is to accurately extract listing data for a farming marketplace.
Maintain a calm, professional, and logistics-focused tone. 

You support English only.
Extract data accurately from English messages.

Current extracted data so far: ${JSON.stringify(existingData)}
New message from grower: "${message}"

Only update fields that are mentioned in the new message.
Keep existing values for fields not mentioned.
Never set a field to null if it already has a value.
Return complete updated JSON with ALL fields.

Return ONLY JSON with these fields (use null if unknown):
{
  "cropType": "PINOT_NOIR" | "MERLOT" | "CABERNET" | "CHARDONNAY" | "RIESLING" | "SAUVIGNON_BLANC" | "TOMATO" | "POTATO" | "ONION" | "MANGO" | "WHEAT" | "RICE" | "SUGARCANE" | "COTTON" | "SOYBEAN" | "CHICKPEA" | null,
  "containerType": "MACRO_BIN" | "HALF_BIN" | "LUG_BOX" | "BULK_BAG" | "CRATE" | "SACK" | "QUINTAL" | "TROLLEY" | null,
  "containerCount": number | null,
  "weightKg": number | null,
  "perishTier": string | null,
  "askingPricePerTon": number | null
}

CONTAINER TYPE RULES:
- macro bin / macro bins → MACRO_BIN (500kg each)
- half bin / half bins → HALF_BIN (250kg each)
- lug box / lug boxes → LUG_BOX (20kg each)
- bulk bag / bulk bags → BULK_BAG (500kg each)
- crate / crates → CRATE (25kg each)
- sack / sacks / bori → SACK (50kg each)
- quintal / quintals → QUINTAL (100kg each)
- trolley / trolleys → TROLLEY (1000kg each)`;

  const responseText = await generateWithFallback(apiKey, extractionPrompt);
  const jsonMatch = responseText.match(/\{[\s\S]*\}/);
  const geminiOutput = jsonMatch ? JSON.parse(jsonMatch[0]) : {};

  // 2. Merge Data
  const updatedData = {
    ...existingData,
    ...Object.fromEntries(
      Object.entries(geminiOutput).filter(([_, v]) => v !== null)
    )
  };

  // Manual extraction fallback maps
  const cropMap: Record<string, string> = {
    // Wine grapes
    'merlot': 'MERLOT',
    'pinot noir': 'PINOT_NOIR',
    'pinot': 'PINOT_NOIR',
    'chardonnay': 'CHARDONNAY',
    'cabernet': 'CABERNET',
    'riesling': 'RIESLING',
    'sauvignon': 'SAUVIGNON_BLANC',
    // Indian crops
    'tomato': 'TOMATO',
    'tomatoes': 'TOMATO',
    'tamatar': 'TOMATO',
    'potato': 'POTATO',
    'potatoes': 'POTATO',
    'aloo': 'POTATO',
    'onion': 'ONION',
    'onions': 'ONION',
    'pyaz': 'ONION',
    'mango': 'MANGO',
    'mangoes': 'MANGO',
    'aam': 'MANGO',
    'wheat': 'WHEAT',
    'gehu': 'WHEAT',
    'rice': 'RICE',
    'chawal': 'RICE',
    'sugarcane': 'SUGARCANE',
    'ganna': 'SUGARCANE',
    'cotton': 'COTTON',
    'kapas': 'COTTON',
    'soybean': 'SOYBEAN',
    'soya': 'SOYBEAN',
    'chickpea': 'CHICKPEA',
    'chana': 'CHICKPEA',
  };

  const containerMap: Record<string, string> = {
    'macro bin': 'MACRO_BIN',
    'macro bins': 'MACRO_BIN',
    'bulk bag': 'BULK_BAG',
    'bulk bags': 'BULK_BAG',
    'lug box': 'LUG_BOX',
    'lug boxes': 'LUG_BOX',
    'half bin': 'HALF_BIN',
    'half bins': 'HALF_BIN',
    'crate': 'CRATE',
    'crates': 'CRATE',
    'sack': 'SACK',
    'sacks': 'SACK',
    'bori': 'SACK',
    'quintal': 'QUINTAL',
    'quintals': 'QUINTAL',
    'trolley': 'TROLLEY',
    'trolleys': 'TROLLEY',
  };

  const msgLower = message.toLowerCase();

  // Manual crop extraction fallback
  if (!updatedData.cropType) {
    for (const [keyword, value] of Object.entries(cropMap)) {
      if (msgLower.includes(keyword)) {
        updatedData.cropType = value;
        break;
      }
    }
  }

  // Manual container extraction fallback
  if (!updatedData.containerType) {
    for (const [keyword, value] of Object.entries(containerMap)) {
      if (msgLower.includes(keyword)) {
        updatedData.containerType = value;
        break;
      }
    }
  }

  // Manual container count fallback
  if (!updatedData.containerCount) {
    const numberMatch = message.match(/\b(\d+)\b/);
    if (numberMatch) {
      updatedData.containerCount = parseInt(numberMatch[1]);
    }
  }

  // BUG 2 — Price asked twice (4000 not recognized)
  // If we just asked for price and user replied with a number, extract it as price
  const lastAssistantMsg = state.messages
    .filter((m: any) => m.role === 'assistant')
    .pop()?.content || '';

  const priceWasAsked = lastAssistantMsg.includes('price') 
    || lastAssistantMsg.includes('per ton');

  if (priceWasAsked && !updatedData.askingPricePerTon) {
    const priceMatch = message.match(/\b(\d+(?:,\d+)?(?:\.\d+)?)\b/);
    if (priceMatch) {
      const price = parseFloat(priceMatch[1].replace(',', ''));
      // Only use as price if it's a reasonable price (> 100)
      // and not already used as containerCount
      if (price > 100 && price !== updatedData.containerCount) {
        updatedData.askingPricePerTon = price;
      }
    }
  }

  // Normalization step to convert raw text to enums
  if (updatedData.containerType) {
    const normalized = containerMap[updatedData.containerType.toLowerCase().trim()];
    if (normalized) updatedData.containerType = normalized;
  }

  if (updatedData.cropType) {
    const normalized = cropMap[updatedData.cropType.toLowerCase().trim()];
    if (normalized) updatedData.cropType = normalized;
  }

  // Handle complete input in one message - container weight calculation
  const containerWeights: Record<string, number> = {
    MACRO_BIN: 500,
    HALF_BIN: 250,
    LUG_BOX: 20,
    BULK_BAG: 500,
    CRATE: 25,
    SACK: 50,
    QUINTAL: 100,
    TROLLEY: 1000,
  };

  if (!updatedData.weightKg && updatedData.containerType && updatedData.containerCount) {
    const avgWeight = containerWeights[updatedData.containerType];
    if (avgWeight) {
      updatedData.weightKg = updatedData.containerCount * avgWeight;
    }
  }

  // BUG 1 — weightKg being overwritten by price value
  // Lock weightKg once calculated from containers
  if (existingData.weightKg && existingData.weightKg > 0) {
    updatedData.weightKg = existingData.weightKg;
  }

  // BUG 3 — perishTier wrong enum format
  // Normalize perishTier from Gemini output or manual input
  const perishTierMap: Record<string, string> = {
    '24_hours': 'HOURS_24',
    '48_hours': 'HOURS_48',
    '72_hours': 'DAYS_3',
    'hours_24': 'HOURS_24',
    'hours_48': 'HOURS_48',
    'days_3': 'DAYS_3',
    '24h': 'HOURS_24',
    '48h': 'HOURS_48',
    'within 24 hours': 'HOURS_24',
    'within 48 hours': 'HOURS_48',
    'within 72 hours': 'DAYS_3',
    '24 hours': 'HOURS_24',
    '48 hours': 'HOURS_48',
    '72 hours': 'DAYS_3',
    'today': 'HOURS_24',
    'tomorrow': 'HOURS_48',
    'urgent': 'HOURS_24',
  };

  // Manual perishTier inference
  if (!updatedData.perishTier) {
    if (msgLower.includes('24') || msgLower.includes('today') 
        || msgLower.includes('urgent') || msgLower.includes('now')) {
      updatedData.perishTier = 'HOURS_24';
    } else if (msgLower.includes('48') || msgLower.includes('tomorrow')) {
      updatedData.perishTier = 'HOURS_48';
    } else if (msgLower.includes('72') || msgLower.includes('3 day')) {
      updatedData.perishTier = 'DAYS_3';
    }
  }

  // Run normalization and validation
  if (updatedData.perishTier) {
    const key = updatedData.perishTier.toLowerCase().trim();
    const normalized = perishTierMap[key];
    if (normalized) {
      updatedData.perishTier = normalized;
    } else if (!['HOURS_24','HOURS_48','DAYS_3'].includes(updatedData.perishTier)) {
      // Value is not a valid enum — clear it and let inference handle it next turn
      delete updatedData.perishTier;
    }
  }

  // 3. Detect Missing Fields
  const requiredFields = ["cropType", "containerType", "containerCount", "weightKg", "perishTier"];
  const missingFields = requiredFields.filter(f => !updatedData[f] || updatedData[f] === null);

  // 4. Generate Response (Simplified)
  let aiResponse = "";
  let needsReview = false;
  let reasoning = null;

  if (missingFields.length > 0) {
    const fieldQuestions: Record<string, string> = {
      cropType: "What type of crop do you have ready?",
      containerType: "What containers are you using — crates, sacks, quintals, or trolleys?",
      containerCount: "How many containers do you have?",
      weightKg: "What is the approximate total weight in kilograms?",
      perishTier: "How urgently does this need to move — within 24 hours, 48 hours, or 72 hours?",
    };
    
    aiResponse = fieldQuestions[missingFields[0]];
    
  } else if (!updatedData.askingPricePerTon || updatedData.askingPricePerTon <= 0) {
    aiResponse = "What price are you asking per ton? You can skip this if unsure.";
    
  } else {
    reasoning = await IntelligenceService.analyzeListing(updatedData, plotLocation, growerId);
    aiResponse = "I have all the details needed. Please review your listing below.";
    needsReview = true;
  }

  // Post-process response to ensure no markdown remains
  aiResponse = stripMarkdown(aiResponse);

  // 5. Update State
  state.messages.push({ role: "user", content: message, timestamp: new Date() });
  state.messages.push({ role: "assistant", content: aiResponse, timestamp: new Date() });
  state.extractedData = updatedData;
  state.reasoning = reasoning;
  state.updatedAt = admin.firestore.FieldValue.serverTimestamp();

  await convRef.set(state);

  return {
    success: true,
    conversationId: convRef.id,
    aiResponse,
    extractedData: updatedData,
    reasoning,
    needsReview,
    missingFields: requiredFields.filter(f => !updatedData[f] || updatedData[f] === null)
  };
});
