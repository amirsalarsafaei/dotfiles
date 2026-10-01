import { createServer } from "node:http";
import { existsSync, rmSync } from "node:fs";
import { connect, createServer as createProbe } from "node:net";
import { WebSocket, WebSocketServer } from "ws";

const extensionPort = Number(process.env.BROWSER_MCP_PORT || 9009);
const requestTimeoutMs = Number(process.env.BROWSER_MCP_REQUEST_TIMEOUT_MS || 35000);
const noExtensionMessage =
  "No connection to browser extension. In order to proceed, you must first connect a tab by clicking the Browser MCP extension icon in the browser toolbar and clicking the 'Connect' button.";

const log = (...args) => console.error("[browser-mcp-broker]", ...args);

function brokerSocketPath() {
  const dir =
    process.env.BROWSER_MCP_RUNTIME_DIR ||
    process.env.XDG_RUNTIME_DIR ||
    `/run/user/${process.getuid()}`;
  return process.env.BROWSER_MCP_BROKER_SOCKET || `${dir}/browser-mcp.sock`;
}

function portAvailable(port) {
  return new Promise((resolve) => {
    const probe = createProbe();
    probe.once("error", () => resolve(false));
    probe.once("listening", () => probe.close(() => resolve(true)));
    probe.listen(port);
  });
}

function socketResponds(path) {
  return new Promise((resolve) => {
    const probe = connect(path);
    probe.once("connect", () => {
      probe.destroy();
      resolve(true);
    });
    probe.once("error", () => {
      probe.destroy();
      resolve(false);
    });
  });
}

const socketPath = brokerSocketPath();

async function acquireExtensionPort() {
  const deadline = Date.now() + 60000;
  while (!(await portAvailable(extensionPort))) {
    if (Date.now() > deadline) {
      log(`port ${extensionPort} is held by another process; refusing to start, nothing was killed`);
      return false;
    }
    log(`port ${extensionPort} is held by another process, retrying in 2s`);
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }
  return true;
}

if (!(await acquireExtensionPort())) {
  process.exit(1);
}

if (existsSync(socketPath) && (await socketResponds(socketPath))) {
  log(`another broker is already listening on ${socketPath}`);
  process.exit(1);
}

rmSync(socketPath, { force: true });

let extension = null;
let inFlight = null;
let counter = 0;
const sessions = new Set();
const pending = new Map();
const queue = [];

function extensionOpen() {
  return extension !== null && extension.readyState === WebSocket.OPEN;
}

function reply(session, id, payload) {
  if (!session.alive) {
    return;
  }
  session.socket.send(JSON.stringify({ type: "messageResponse", payload: { requestId: id, ...payload } }));
}

function dispatch() {
  while (inFlight === null && queue.length > 0) {
    const job = queue.shift();
    if (!job.session.alive) {
      continue;
    }
    if (!extensionOpen()) {
      reply(job.session, job.id, { error: noExtensionMessage });
      continue;
    }
    const extensionId = `b${++counter}`;
    inFlight = extensionId;
    const timer = setTimeout(() => {
      pending.delete(extensionId);
      if (inFlight === extensionId) {
        inFlight = null;
        log(`request ${extensionId} timed out without a response`);
        dispatch();
      }
    }, requestTimeoutMs);
    pending.set(extensionId, { session: job.session, id: job.id, timer });
    try {
      extension.send(JSON.stringify({ id: extensionId, type: job.type, payload: job.payload }));
    } catch (error) {
      clearTimeout(timer);
      pending.delete(extensionId);
      inFlight = null;
      reply(job.session, job.id, { error: `failed to reach the browser extension: ${error.message}` });
    }
  }
}

function onExtensionMessage(raw) {
  let message;
  try {
    message = JSON.parse(raw.toString());
  } catch {
    return;
  }
  if (message.type !== "messageResponse") {
    return;
  }
  const { requestId, result, error } = message.payload || {};
  const entry = pending.get(requestId);
  if (!entry) {
    return;
  }
  clearTimeout(entry.timer);
  pending.delete(requestId);
  if (inFlight === requestId) {
    inFlight = null;
  }
  reply(entry.session, entry.id, error ? { error } : { result });
  dispatch();
}

const extensionServer = new WebSocketServer({ port: extensionPort });

extensionServer.on("connection", (socket) => {
  if (extension !== null) {
    try {
      extension.close();
    } catch {
      extension = null;
    }
  }
  extension = socket;
  log("browser extension connected");
  socket.on("message", onExtensionMessage);
  socket.on("error", () => {});
  socket.on("close", () => {
    if (extension === socket) {
      extension = null;
      log("browser extension disconnected");
    }
  });
});

extensionServer.on("error", (error) => {
  log(`extension listener failed: ${error.message}`);
  rmSync(socketPath, { force: true });
  process.exit(1);
});

const shimServer = createServer();
const shimWss = new WebSocketServer({ server: shimServer });

shimWss.on("connection", (socket) => {
  const session = { socket, alive: true };
  sessions.add(session);
  log(`session connected (${sessions.size} active)`);
  socket.on("message", (raw) => {
    let message;
    try {
      message = JSON.parse(raw.toString());
    } catch {
      return;
    }
    if (message.type === "messageResponse") {
      return;
    }
    queue.push({ session, id: message.id, type: message.type, payload: message.payload });
    dispatch();
  });
  socket.on("error", () => {});
  socket.on("close", () => {
    session.alive = false;
    sessions.delete(session);
    log(`session disconnected (${sessions.size} active)`);
    dispatch();
  });
});

shimServer.on("error", (error) => {
  log(`shim listener failed: ${error.message}`);
  process.exit(1);
});

shimServer.listen(socketPath, () => {
  log(`extension listening on port ${extensionPort}`);
  log(`shims listening on ${socketPath}`);
});

function shutdown(signal) {
  log(`${signal} received, shutting down`);
  for (const entry of pending.values()) {
    clearTimeout(entry.timer);
  }
  pending.clear();
  try {
    extensionServer.close();
  } catch {
    log("extension listener already closed");
  }
  try {
    shimWss.close();
    shimServer.close();
  } catch {
    log("shim listener already closed");
  }
  rmSync(socketPath, { force: true });
  process.exit(0);
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
