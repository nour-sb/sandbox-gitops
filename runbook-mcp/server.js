const { McpServer } = require("@modelcontextprotocol/sdk/server/mcp.js");
const { StreamableHTTPServerTransport } = require("@modelcontextprotocol/sdk/server/streamableHttp.js");
const http = require("http");
const fs = require("fs");
const path = require("path");
const { z } = require("zod");

const RUNBOOKS_DIR = path.join(__dirname, "runbooks");

function loadRunbook(service) {
  const file = path.join(RUNBOOKS_DIR, `${service}.md`);
  try {
    return fs.readFileSync(file, "utf8");
  } catch {
    return null;
  }
}

function listRunbooks() {
  try {
    return fs.readdirSync(RUNBOOKS_DIR)
      .filter(f => f.endsWith(".md"))
      .map(f => f.replace(/\.md$/, ""));
  } catch {
    return [];
  }
}

const PORT = 3001;

function log(label, data) {
  console.log(`\n[${new Date().toISOString()}] ${label}`);
  console.log(JSON.stringify(data, null, 2));
}

const app = http.createServer(async (req, res) => {
  if (req.url !== "/mcp") {
    console.log(`${new Date().toISOString()} ${req.method} ${req.url} → 404`);
    res.writeHead(404);
    res.end("Not found");
    return;
  }

  const body = await bodyJson(req);
  const method = body.method || "(no method)";
  console.log(`\n${new Date().toISOString()} ${req.method} /mcp  method=${method}`);

  const server = new McpServer({
    name: "runbook-mcp",
    version: "1.0.0",
    description:
      "Provides official runbooks for all production services. MUST be consulted before investigating any service alert or outage. Do not perform analysis without first retrieving the runbook for the affected service.",
  });

  server.tool(
    "get_runbook",
    "MANDATORY: Call this immediately when investigating any service alert, incident, or outage. Returns the official runbook containing recovery steps, architecture notes, replica counts, endpoints, and escalation procedures. Always call this first — before querying metrics or drawing conclusions — using the service name from the alert labels.",
    { service: z.string().describe("The service name from the alert labels, e.g. products-api or cart-api") },
    async ({ service }) => {
      log("REQUEST tools/call get_runbook", { service });
      const key = service.toLowerCase().trim();
      const runbook = loadRunbook(key);
      if (runbook) {
        log("RESPONSE get_runbook", { found: true, service: key, length: runbook.length });
        return { content: [{ type: "text", text: runbook }] };
      }
      const available = listRunbooks().join(", ");
      log("RESPONSE get_runbook", { found: false, service: key, available });
      return {
        content: [{ type: "text", text: `No runbook found for "${service}". Available: ${available}` }],
      };
    }
  );

  const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
  res.on("close", () => transport.close());
  await server.connect(transport);
  await transport.handleRequest(req, res, body);
});

function bodyJson(req) {
  return new Promise((resolve) => {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      try { resolve(JSON.parse(body)); } catch { resolve({}); }
    });
  });
}

app.listen(PORT, () => console.log(`runbook-mcp listening on http://localhost:${PORT}/mcp`));
