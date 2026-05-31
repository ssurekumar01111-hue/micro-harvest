import { GoogleGenerativeAI } from "@google/generative-ai";

// Primary chain for intelligence/reasoning — quality first
export const INTELLIGENCE_MODEL_CHAIN = [
  "gemini-3.1-flash-lite-preview",  // PRIMARY — works reliably
  "gemini-3-flash-preview",          // try if available
  "gemini-3.5-flash-lite",
  "gemini-2.5-flash",
  "gemini-2.5-pro",
  "gemini-2.5-flash-lite",
  "gemini-3.1-pro-preview",          // LAST — quota = 0
];

// Primary chain for conversation turns — speed first
export const CONVERSATION_MODEL_CHAIN = [
  "gemini-3.1-flash-lite-preview",  // PRIMARY — fast + reliable
  "gemini-3-flash-preview",
  "gemini-3.5-flash-lite",
  "gemini-2.5-flash",
  "gemini-2.5-flash-lite",
  "gemini-2.5-pro",
  "gemini-3.1-pro-preview",          // LAST
];

// Keep FALLBACK_MODELS as alias for backward compat
export const FALLBACK_MODELS = INTELLIGENCE_MODEL_CHAIN;

const RETRYABLE_CODES = [429, 500, 502, 503, 504];

interface FallbackOptions {
  systemInstruction?: string;
  tools?: any[];
  generationConfig?: Record<string, any>;
  startModel?: string | null;
  modelChain?: string[]; // NEW — pass custom chain
}

interface FallbackResult {
  result: any;
  modelUsed: string;
}

export async function geminiWithFallback(
  prompt: string,
  options: FallbackOptions = {}
): Promise<FallbackResult> {
  const {
    systemInstruction = null,
    tools = null,
    generationConfig = {},
    startModel = null,
    modelChain = INTELLIGENCE_MODEL_CHAIN, // default to intelligence chain
  } = options;

  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");

  // If startModel specified, slice chain from that model
  let chain = modelChain;
  if (startModel) {
    const startIdx = modelChain.indexOf(startModel);
    if (startIdx >= 0) {
      chain = modelChain.slice(startIdx);
    }
  }

  let lastError: Error | null = null;

  for (const modelName of chain) {
    try {
      console.log(`[geminiWithFallback] Trying model: ${modelName}`);

      const modelConfig: any = { model: modelName };
      if (systemInstruction) modelConfig.systemInstruction = systemInstruction;
      if (tools) modelConfig.tools = tools;

      const model = genAI.getGenerativeModel(modelConfig);
      const result = await model.generateContent({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig,
      });

      console.log(`[geminiWithFallback] Success with model: ${modelName}`);
      return { result, modelUsed: modelName };

    } catch (error: any) {
      const statusCode = error?.status ?? error?.httpErrorCode?.status;

      const isUnsupported =
        statusCode === 404 ||
        (error?.message?.toLowerCase().includes("not found")) ||
        (error?.message?.toLowerCase().includes("not supported")) ||
        (error?.message?.toLowerCase().includes("does not have access"));

      // Treat unsupported models as skippable (not hard failures)
      const isRetryable = RETRYABLE_CODES.includes(statusCode) || isUnsupported;

      console.warn(
        `[geminiWithFallback] Model ${modelName} failed — ` +
        `status: ${statusCode}, retryable: ${isRetryable}, ` +
        `message: ${error.message}`
      );

      lastError = error;

      if (!isRetryable) {
        throw new Error(
          `[geminiWithFallback] Non-retryable error on ${modelName}: ${error.message}`
        );
      }
    }
  }

  throw new Error(
    `[geminiWithFallback] All models exhausted. Last error: ${lastError?.message}`
  );
}

interface ChatFallbackOptions {
  systemInstruction?: string;
  generationConfig?: Record<string, any>;
  startModel?: string | null;
  modelChain?: string[];
}

interface ChatFallbackResult {
  result: any;
  modelUsed: string;
}

export async function geminiChatWithFallback(
  history: Array<{ role: string; parts: Array<{ text: string }> }>,
  newMessage: string,
  options: ChatFallbackOptions = {}
): Promise<ChatFallbackResult> {
  const {
    systemInstruction = null,
    generationConfig = {},
    modelChain = CONVERSATION_MODEL_CHAIN, // default to conversation chain
    startModel = null,
  } = options;

  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");

  let chain = modelChain;
  if (startModel) {
    const startIdx = modelChain.indexOf(startModel);
    if (startIdx >= 0) {
      chain = modelChain.slice(startIdx);
    }
  }

  let lastError: Error | null = null;

  for (const modelName of chain) {
    try {
      console.log(`[geminiChatWithFallback] Trying model: ${modelName}`);

      const modelConfig: any = { model: modelName };
      if (systemInstruction) modelConfig.systemInstruction = systemInstruction;

      const model = genAI.getGenerativeModel(modelConfig);
      const chat = model.startChat({ history, generationConfig });
      const result = await chat.sendMessage(newMessage);

      console.log(`[geminiChatWithFallback] Success with model: ${modelName}`);
      return { result, modelUsed: modelName };

    } catch (error: any) {
      const statusCode = error?.status ?? error?.httpErrorCode?.status;

      const isUnsupported =
        statusCode === 404 ||
        (error?.message?.toLowerCase().includes("not found")) ||
        (error?.message?.toLowerCase().includes("not supported")) ||
        (error?.message?.toLowerCase().includes("does not have access"));

      const isRetryable = RETRYABLE_CODES.includes(statusCode) || isUnsupported;

      console.warn(
        `[geminiChatWithFallback] Model ${modelName} failed — ` +
        `status: ${statusCode}, retryable: ${isRetryable}`
      );

      lastError = error;
      if (!isRetryable) throw error;
    }
  }

  throw new Error(
    `[geminiChatWithFallback] All models exhausted. Last error: ${lastError?.message}`
  );
}
