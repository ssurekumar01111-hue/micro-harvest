import { VertexAI } from "@google-cloud/vertexai";
import { logger } from "firebase-functions";

const vertexAI = new VertexAI({ project: "micro-harvest", location: "asia-south1" });

async function listModels() {
  const models = [
    "gemini-3.1-flash-lite",
    "gemini-2.5-flash-lite", 
    "gemini-2.5-flash",
    "gemini-2.5-pro",
    "gemini-3.1-pro-preview",
  ];

  for (const modelName of models) {
    try {
      const model = vertexAI.getGenerativeModel({ model: modelName });
      const result = await model.generateContent("test");
      logger.log(`✅ ${modelName} works: ${result.response.candidates?.[0]?.content?.parts?.[0]?.text?.substring(0, 20)}...`);
    } catch (e: any) {
      logger.log(`❌ ${modelName} fails: ${e.message}`);
    }
  }
}

listModels();
