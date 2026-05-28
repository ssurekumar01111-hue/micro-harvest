import { VertexAI } from "@google-cloud/vertexai";
import { logger } from "firebase-functions";

const vertexAI = new VertexAI({ project: "micro-harvest", location: "asia-south1" });

const FALLBACK_MODELS = [
  "gemini-2.5-flash",
];

export async function generateWithFallback(
  prompt: string,
  tools?: any[]
): Promise<string> {
  for (const modelName of FALLBACK_MODELS) {
    try {
      const modelConfig: any = { model: modelName };
      if (tools) modelConfig.tools = tools;
      
      const model = vertexAI.getGenerativeModel(modelConfig);
      const result = await model.generateContent(prompt);
      
      const response = result.response;
      const text = response.candidates?.[0]?.content?.parts?.[0]?.text || "";
      
      logger.log(`[VertexAI] Success with model: ${modelName}`);
      return text;
      
    } catch (error: any) {
      const isRetryable = 
        error?.status === 503 ||
        error?.status === 429 ||
        error?.message?.includes('503') ||
        error?.message?.includes('429') ||
        error?.message?.includes('overloaded') ||
        error?.message?.includes('high demand') ||
        error?.message?.includes('rate limit') ||
        error?.message?.includes('quota');
        
      if (isRetryable) {
        logger.warn(`[VertexAI] ${modelName} unavailable, trying next...`);
        continue;
      }
      
      throw error;
    }
  }
  
  throw new Error('All Vertex AI Gemini models unavailable. Please try again.');
}

export async function generateWithFallbackFull(
  prompt: string,
  tools?: any[]
): Promise<any> {
  for (const modelName of FALLBACK_MODELS) {
    try {
      const modelConfig: any = { model: modelName };
      if (tools) modelConfig.tools = tools;
      
      const model = vertexAI.getGenerativeModel(modelConfig);
      const result = await model.generateContent(prompt);
      
      logger.log(`[VertexAI] Success with model: ${modelName}`);
      return result;
      
    } catch (error: any) {
      const isRetryable = 
        error?.status === 503 ||
        error?.status === 429 ||
        error?.message?.includes('503') ||
        error?.message?.includes('429') ||
        error?.message?.includes('overloaded') ||
        error?.message?.includes('high demand') ||
        error?.message?.includes('rate limit') ||
        error?.message?.includes('quota');
        
      if (isRetryable) {
        logger.warn(`[VertexAI] ${modelName} unavailable, trying next...`);
        continue;
      }
      throw error;
    }
  }
  
  throw new Error('All Vertex AI Gemini models unavailable.');
}
