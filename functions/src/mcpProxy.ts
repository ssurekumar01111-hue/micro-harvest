import * as functions from "firebase-functions";
import fetch from "node-fetch";

export const mcpProxy = functions
  .region("asia-south1")
  .https.onRequest(async (req, res) => {
    const mcpUrl = process.env.ES_MCP_URL || "";
    const mcpKey = process.env.ES_MCP_KEY || "";

    if (!mcpUrl || !mcpKey) {
      res.status(500).json({ error: "MCP not configured" });
      return;
    }

    try {
      const response = await fetch(mcpUrl, {
        method: req.method,
        headers: {
          "Authorization": `ApiKey ${mcpKey}`,
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: req.method !== "GET" ? JSON.stringify(req.body) : undefined,
      });

      const data = await response.json();
      res.status(response.status).json(data);
    } catch (error) {
      console.error("[MCP Proxy] Error:", error);
      res.status(500).json({ error: "Proxy failed" });
    }
  });
