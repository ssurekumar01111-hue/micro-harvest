import { GoogleGenerativeAI } from "@google/generative-ai";
import { logger } from "firebase-functions";

const FALLBACK_MODELS = [
  "gemini-3.1-flash-lite",
  "gemini-2.5-flash-lite", 
  "gemini-2.5-flash",
  "gemini-2.5-pro",
  "gemini-3.1-pro-preview",
];

export async function generateWithFallback(
  apiKey: string,
  prompt: string,
  tools?: any[]
): Promise<string> {
  const genAI = new GoogleGenerativeAI(apiKey);
  
  for (const modelName of FALLBACK_MODELS) {
    try {
      const modelConfig: any = { model: modelName };
      if (tools) modelConfig.tools = tools;
      
      const model = genAI.getGenerativeModel(modelConfig);
      const result = await model.generateContent(prompt);
      
      logger.log(`[Gemini] Success with model: ${modelName}`);
      return result.response.text();
      
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
        logger.warn(`[Gemini] ${modelName} unavailable, trying next...`);
        continue;
      }
      
      // Non-retryable error - throw immediately
      throw error;
    }
  }
  
  throw new Error('All Gemini models unavailable. Please try again.');
}

// For tool-calling (returns full response not just text)
export async function generateWithFallbackFull(
  apiKey: string,
  prompt: string,
  tools?: any[]
): Promise<any> {
  const genAI = new GoogleGenerativeAI(apiKey);
  
  for (const modelName of FALLBACK_MODELS) {
    try {
      const modelConfig: any = { model: modelName };
      if (tools) modelConfig.tools = tools;
      
      const model = genAI.getGenerativeModel(modelConfig);
      const result = await model.generateContent(prompt);
      
      logger.log(`[Gemini] Success with model: ${modelName}`);
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
        logger.warn(`[Gemini] ${modelName} unavailable, trying next...`);
        continue;
      }
      throw error;
    }
  }
  
  throw new Error('All Gemini models unavailable.');
}
