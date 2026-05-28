import * as functions from "firebase-functions";
import fetch from "node-fetch";

export const mcpProxy = functions
  .region("asia-south1")
  .https.onRequest(async (req, res) => {
    const mcpUrl = process.env.ES_MCP_URL || "";
    const mcpKey = process.env.ES_MCP_KEY || "";

    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers",
      "Content-Type, Authorization, Accept, Mcp-Session-Id");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (!mcpUrl || !mcpKey) {
      res.status(500).json({ error: "MCP not configured" });
      return;
    }

    try {
      const headers: Record<string, string> = {
        "Authorization": `ApiKey ${mcpKey}`,
        "Content-Type": "application/json",
        "Accept": "application/json",
      };

      if (req.headers["mcp-session-id"]) {
        headers["Mcp-Session-Id"] = req.headers["mcp-session-id"] as string;
      }

      const fetchOptions: any = {
        method: req.method,
        headers,
      };

      if (req.method === "POST") {
        fetchOptions.body = JSON.stringify(req.body);
      }

      console.log(`[MCP Proxy] ${req.method} → ${mcpUrl}`);
      console.log(`[MCP Proxy] Body: ${JSON.stringify(req.body).substring(0, 100)}`);

      const response = await fetch(mcpUrl, fetchOptions);
      const contentType = response.headers.get("content-type") || "";

      console.log(`[MCP Proxy] Response status: ${response.status}`);

      if (contentType.includes("text/event-stream")) {
        res.set("Content-Type", "text/event-stream");
        res.set("Cache-Control", "no-cache");
        res.set("Connection", "keep-alive");
        response.body.pipe(res);
        return;
      }

      const text = await response.text();
      console.log(`[MCP Proxy] Response body: ${text.substring(0, 200)}`);

      try {
        const data = JSON.parse(text);
        res.status(response.status).json(data);
      } catch {
        res.status(response.status).send(text);
      }

    } catch (error) {
      console.error("[MCP Proxy] Error:", error);
      res.status(500).json({ 
        error: "Proxy failed", 
        detail: String(error) 
      });
    }
  });
