// Live control-flow diagram server.
// Serves graph.json embedded in an HTML page (React Flow renders it client-side),
// watches graph.json, and pushes valid changes to browsers over a WebSocket.
// graph.json and details/ live under /tmp/flow-diagram (or $FLOW_DATA_DIR), not
// in this skill directory, since they are per-session output.
//
// Usage: bun server.ts   (from this directory)
import { existsSync, watch } from "node:fs";
import { mkdir } from "node:fs/promises";
import { join, resolve, sep } from "node:path";

type GraphNode = { id: string; label: string; description: string; detailFile?: string };
type GraphEdge = { source: string; target: string; label?: string };
type Graph = { nodes: GraphNode[]; edges: GraphEdge[] };

const dir = import.meta.dir;
// graph.json and details/ are per-session output, not skill assets, so they live
// under /tmp instead of this repo directory. Override with FLOW_DATA_DIR.
const dataDir = process.env.FLOW_DATA_DIR || "/tmp/flow-diagram";
const graphPath = join(dataDir, "graph.json");
const cssPath = join(dir, "style.css");
const detailsDir = join(dataDir, "details");
const DEFAULT_PORT = 4173;
const TOPIC = "graph";

await mkdir(detailsDir, { recursive: true });
if (!existsSync(graphPath)) {
  const starter: Graph = {
    nodes: [
      { id: "start", label: "Start", description: "Replace this with the first step of your concept." },
      { id: "end", label: "End", description: "Replace this with the last step of your concept." },
    ],
    edges: [{ source: "start", target: "end" }],
  };
  await Bun.write(graphPath, JSON.stringify(starter, null, 2) + "\n");
}

const nonEmpty = (v: unknown): v is string => typeof v === "string" && v.trim() !== "";

const readGraphText = () => Bun.file(graphPath).text();

// Returns the graph, or a list of problems if the text is not a valid graph.
function parseGraph(text: string): { graph: Graph } | { errors: string[] } {
  let raw: any;
  try {
    raw = JSON.parse(text);
  } catch (err) {
    return { errors: [`cannot parse graph.json: ${(err as Error).message}`] };
  }
  if (!Array.isArray(raw?.nodes) || !Array.isArray(raw?.edges)) {
    return { errors: ['graph.json must have "nodes" and "edges" arrays'] };
  }

  const errors: string[] = [];
  const ids = new Set<string>();
  raw.nodes.forEach((n: any, i: number) => {
    for (const key of ["id", "label", "description"]) {
      if (!nonEmpty(n?.[key])) errors.push(`nodes[${i}] is missing a non-empty "${key}"`);
    }
    if (nonEmpty(n?.id)) {
      if (ids.has(n.id)) errors.push(`nodes[${i}] has duplicate id "${n.id}"`);
      ids.add(n.id);
    }
    if (n?.detailFile !== undefined && !nonEmpty(n.detailFile)) {
      errors.push(`nodes[${i}].detailFile must be a non-empty string when present`);
    }
  });
  raw.edges.forEach((e: any, i: number) => {
    for (const key of ["source", "target"]) {
      if (!nonEmpty(e?.[key])) errors.push(`edges[${i}] is missing "${key}"`);
      else if (!ids.has(e[key])) errors.push(`edges[${i}].${key} "${e[key]}" is not a node id`);
    }
  });
  if (errors.length) return { errors };

  return {
    graph: {
      nodes: raw.nodes.map((n: any) => ({
        id: n.id,
        label: n.label,
        description: n.description,
        ...(nonEmpty(n.detailFile) ? { detailFile: n.detailFile } : {}),
      })),
      edges: raw.edges.map((e: any) => ({
        source: e.source,
        target: e.target,
        ...(nonEmpty(e.label) ? { label: e.label } : {}),
      })),
    },
  };
}

let lastText = await readGraphText();
const initial = parseGraph(lastText);
if ("errors" in initial) {
  console.error("graph.json is invalid:\n  " + initial.errors.join("\n  "));
  process.exit(1);
}
let graph: Graph = initial.graph;

// Escape "<" so labels cannot close the <script> tag.
const embed = (g: Graph) => JSON.stringify(g).replace(/</g, "\\u003c");

const page = (g: Graph) => `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>Control flow diagram</title>
  <link rel="stylesheet" href="https://unpkg.com/reactflow@11.11.4/dist/style.css" />
  <link rel="stylesheet" href="/style.css" />
  <script src="https://unpkg.com/react@18.3.1/umd/react.production.min.js"></script>
  <script src="https://unpkg.com/react-dom@18.3.1/umd/react-dom.production.min.js"></script>
  <script src="https://unpkg.com/reactflow@11.11.4/dist/umd/index.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/marked@15.0.12/marked.min.js"></script>
</head>
<body>
  <div id="root"></div>
  <script id="graph-data" type="application/json">${embed(g)}</script>
  <script>
    const RF = window.ReactFlow;
    const h = React.createElement;

    // Top-to-bottom layering: rank = longest path from a root, ignoring back edges (loops).
    function layout(nodes, edges) {
      const out = new Map(nodes.map(n => [n.id, []]));
      const indeg = new Map(nodes.map(n => [n.id, 0]));
      edges.forEach(e => { if (out.has(e.source) && indeg.has(e.target)) { out.get(e.source).push(e.target); indeg.set(e.target, indeg.get(e.target) + 1); } });

      const rank = new Map();
      const state = new Map(); // 1 = visiting, 2 = done
      const roots = nodes.filter(n => indeg.get(n.id) === 0).map(n => n.id);
      if (roots.length === 0 && nodes.length) roots.push(nodes[0].id);
      function visit(id, r) {
        if (state.get(id) === 1) return; // back edge
        if (rank.has(id) && rank.get(id) >= r && state.get(id) === 2) return;
        rank.set(id, Math.max(rank.get(id) ?? 0, r));
        state.set(id, 1);
        out.get(id).forEach(t => visit(t, rank.get(id) + 1));
        state.set(id, 2);
      }
      roots.forEach(id => visit(id, 0));
      nodes.forEach(n => { if (!rank.has(n.id)) visit(n.id, 0); });

      const rows = new Map();
      nodes.forEach(n => { const r = rank.get(n.id); rows.set(r, [...(rows.get(r) || []), n.id]); });
      const pos = new Map();
      rows.forEach((ids, r) => ids.forEach((id, i) => pos.set(id, { x: (i - (ids.length - 1) / 2) * 220, y: r * 120 })));
      return { pos, out, indeg };
    }

    // Convert {nodes, edges} from graph.json into React Flow nodes and edges.
    function toFlow(graph) {
      const { pos, out, indeg } = layout(graph.nodes, graph.edges);
      const nodes = graph.nodes.map(n => {
        const outs = out.get(n.id).length;
        const type = indeg.get(n.id) === 0 ? 'input' : outs === 0 ? 'output' : 'default';
        const label = h('div', null,
          h('span', { className: 'node-label' }, n.label),
          h('span', { className: 'node-description' }, n.description));
        const className = [outs > 1 ? 'decision' : '', n.detailFile ? 'has-detail' : ''].filter(Boolean).join(' ');
        return { id: n.id, type, data: { label, title: n.label, detailFile: n.detailFile }, position: pos.get(n.id), className };
      });
      const edges = graph.edges.map((e, i) => ({
        id: 'e' + i, source: e.source, target: e.target, label: e.label || undefined,
        type: 'smoothstep', markerEnd: { type: RF.MarkerType.ArrowClosed },
      }));
      return { nodes, edges };
    }

    // Side panel with a node's Markdown detail. detail = null (hidden) or { title, html }.
    function DetailPanel({ detail, onClose }) {
      if (!detail) return null;
      return h('aside', { className: 'detail-panel' },
        h('button', { className: 'detail-close', onClick: onClose, 'aria-label': 'Close' }, '\\u00d7'),
        h('h1', { className: 'detail-title' }, detail.title),
        h('div', { className: 'detail-body', dangerouslySetInnerHTML: { __html: detail.html } }));
    }

    function App() {
      const [state, setState] = React.useState(() => ({
        version: 0,
        flow: toFlow(JSON.parse(document.getElementById('graph-data').textContent)),
      }));
      const [detail, setDetail] = React.useState(null);
      const requested = React.useRef(null); // detailFile of the latest click, to drop stale fetches
      React.useEffect(() => {
        const ws = new WebSocket((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/ws');
        ws.onmessage = ev => setState(s => ({ version: s.version + 1, flow: toFlow(JSON.parse(ev.data)) }));
        return () => ws.close();
      }, []);
      React.useEffect(() => {
        const onKey = ev => { if (ev.key === 'Escape') setDetail(null); };
        window.addEventListener('keydown', onKey);
        return () => window.removeEventListener('keydown', onKey);
      }, []);

      const close = () => { requested.current = null; setDetail(null); };
      async function openDetail(_ev, node) {
        const { detailFile, title } = node.data;
        if (!detailFile) return;
        requested.current = detailFile;
        let html;
        try {
          const res = await fetch('/' + detailFile, { cache: 'no-store' });
          if (!res.ok) throw new Error(res.status + ' ' + res.statusText);
          html = marked.parse(await res.text());
        } catch (err) {
          html = '<p class="detail-error">Could not load ' + detailFile + ': ' + err.message + '</p>';
        }
        if (requested.current === detailFile) setDetail({ title, html });
      }

      // A new key remounts React Flow so fitView frames the updated graph.
      return h(React.Fragment, null,
        h(RF.default, { key: state.version, nodes: state.flow.nodes, edges: state.flow.edges, fitView: true, nodesConnectable: false,
            onNodeClick: openDetail, onPaneClick: close },
          h(RF.Background, null), h(RF.Controls, null)),
        h(DetailPanel, { detail, onClose: close }));
    }
    ReactDOM.createRoot(document.getElementById('root')).render(h(App));
  </script>
</body>
</html>`;

function start(port: number) {
  return Bun.serve({
    port,
    fetch(req, server) {
      const { pathname } = new URL(req.url);
      if (pathname === "/ws") {
        return server.upgrade(req) ? undefined : new Response("expected a WebSocket", { status: 400 });
      }
      if (pathname === "/style.css") {
        return new Response(Bun.file(cssPath), { headers: { "Content-Type": "text/css; charset=utf-8" } });
      }
      if (pathname.startsWith("/details/")) {
        // Resolve inside details/ only, so "../" cannot read other files.
        const filePath = resolve(detailsDir, decodeURIComponent(pathname.slice("/details/".length)));
        if (!filePath.startsWith(detailsDir + sep)) return new Response("not found", { status: 404 });
        const file = Bun.file(filePath);
        return file.exists().then(ok =>
          ok
            ? new Response(file, { headers: { "Content-Type": "text/plain; charset=utf-8" } })
            : new Response("not found", { status: 404 }),
        );
      }
      if (pathname === "/") {
        return new Response(page(graph), { headers: { "Content-Type": "text/html; charset=utf-8" } });
      }
      return new Response("not found", { status: 404 });
    },
    websocket: {
      open(ws) {
        ws.subscribe(TOPIC);
      },
      message() {},
    },
  });
}

// Bind to DEFAULT_PORT, or the next free port after it.
let server: ReturnType<typeof start> | undefined;
for (let port = DEFAULT_PORT; port < DEFAULT_PORT + 20 && !server; port++) {
  try {
    server = start(port);
  } catch (err: any) {
    if (err?.code !== "EADDRINUSE") throw err;
    console.log(`port ${port} is in use, trying ${port + 1}`);
  }
}
if (!server) {
  console.error(`no free port in ${DEFAULT_PORT}-${DEFAULT_PORT + 19}`);
  process.exit(1);
}

// Watch the directory, not the file: editors often save by writing a temp file and
// renaming it over graph.json, which ends a watch on the original file. Bun reports
// such a save under the temp file's name, so react to any event and compare contents.
let timer: ReturnType<typeof setTimeout> | undefined;
watch(dataDir, () => {
  clearTimeout(timer);
  timer = setTimeout(async () => {
    let text: string;
    try {
      text = await readGraphText();
    } catch {
      return; // graph.json briefly missing mid-save; the next event will re-read it
    }
    if (text === lastText) return;
    lastText = text;
    const result = parseGraph(text);
    if ("errors" in result) {
      console.warn("graph.json change skipped, keeping last good graph:\n  " + result.errors.join("\n  "));
      return;
    }
    graph = result.graph;
    server!.publish(TOPIC, JSON.stringify(graph));
    console.log(`graph.json reloaded (${graph.nodes.length} nodes, ${graph.edges.length} edges), pushed to clients`);
  }, 100);
});

console.log(`Serving http://localhost:${server.port} - watching ${graphPath} for changes`);
