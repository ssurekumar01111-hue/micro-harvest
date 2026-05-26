import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

let mcpClient: Client | null = null;

export async function getElasticMcpClient(): Promise<Client> {
  if (mcpClient) return mcpClient;

  const mcpUrl = process.env.ES_MCP_URL || "";
  const mcpKey = process.env.ES_MCP_KEY || "";

  if (!mcpUrl || !mcpKey) {
    throw new Error("ES_MCP_URL or ES_MCP_KEY not configured");
  }

  const transport = new StreamableHTTPClientTransport(
    new URL(mcpUrl),
    {
      requestInit: {
        headers: {
          "Authorization": `ApiKey ${mcpKey}`,
          "Content-Type": "application/json",
        }
      }
    }
  );

  mcpClient = new Client(
    { name: "micro-harvest-agent", version: "1.0.0" },
    { capabilities: {} }
  );

  await mcpClient.connect(transport);
  console.log("[MCP] Connected to Elastic Agent Builder MCP server");

  return mcpClient;
}

export async function callMcpTool(
  toolName: string,
  args: Record<string, any>
): Promise<any> {
  try {
    const client = await getElasticMcpClient();
    const result = await client.callTool({
      name: toolName,
      arguments: args,
    });
    console.log(`[MCP] Tool ${toolName} executed successfully`);
    return result;
  } catch (error) {
    console.error(`[MCP] Tool ${toolName} failed:`, error);
    throw error;
  }
}

export async function listMcpTools(): Promise<any> {
  try {
    const client = await getElasticMcpClient();
    const tools = await client.listTools();
    console.log("[MCP] Available tools:", 
      tools.tools.map(t => t.name));
    return tools;
  } catch (error) {
    console.error("[MCP] Failed to list tools:", error);
    throw error;
  }
}
