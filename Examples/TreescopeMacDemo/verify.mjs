// Connects to a running Treescope server (default 127.0.0.1:50067) over WebSocket,
// performs the handshake, fetches the hierarchy, and prints a summary. Exits 0 on
// success, non-zero otherwise. Uses Node's global WebSocket (Node 22+).
const PORT = process.argv[2] ? Number(process.argv[2]) : 50067;
const URL = `ws://127.0.0.1:${PORT}/ws`;

function fail(msg) { console.error("VERIFY FAILED:", msg); process.exit(2); }

const ws = new WebSocket(URL);
let nextId = 1;
const pending = new Map();

function request(message) {
  return new Promise((resolve, reject) => {
    const id = nextId++;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, message }));
    setTimeout(() => { if (pending.delete(id)) reject(new Error("timeout")); }, 15000);
  });
}

ws.addEventListener("error", (e) => fail("ws error: " + (e.message || e)));
ws.addEventListener("message", (ev) => {
  const env = JSON.parse(ev.data);
  if (env.id === 0) return; // push
  const w = pending.get(env.id);
  if (w) { pending.delete(env.id); w.resolve(env.message); }
});

ws.addEventListener("open", async () => {
  try {
    const ack = await request({ t: "handshake", client: { name: "verify", version: "0.1.0", protocolVersion: 1 } });
    if (ack.t !== "handshakeAck") fail("no handshakeAck");
    console.log(`VERIFY: handshake ok — ${ack.info.device.appName} on ${ack.info.device.osName} ${ack.info.device.osVersion} (sim=${ack.info.device.isSimulator})`);

    const h = await request({ t: "fetchHierarchy", options: { includeSwiftUI: true, includeLayers: true, hideSystemViews: false, requestSnapshots: true, maxDepth: 0 } });
    if (h.t !== "hierarchy") fail("no hierarchy");

    let total = 0, appkit = 0, swiftui = 0, layers = 0;
    const walk = (n) => {
      total++;
      if (n.kind === "nsView" || n.kind === "nsWindow") appkit++;
      if (n.kind === "swiftUI") swiftui++;
      if (n.kind === "caLayer") layers++;
      n.children.forEach(walk);
    };
    h.snapshot.roots.forEach(walk);
    console.log(`VERIFY: captured ${total} nodes — ${appkit} AppKit, ${swiftui} SwiftUI, ${layers} CALayer`);

    const foundAppKitField = JSON.stringify(h.snapshot).includes("appkit.textField") || JSON.stringify(h.snapshot).includes("Type here");
    if (total < 10) fail("too few nodes");
    if (appkit < 1) fail("no AppKit views captured");
    console.log(`VERIFY: AppKit text field present: ${foundAppKitField}`);
    console.log("VERIFY SUCCEEDED ✅");
    process.exit(0);
  } catch (e) {
    fail(String(e));
  }
});
