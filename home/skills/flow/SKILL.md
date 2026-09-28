---
name: flow
description: Explain a concept step by step with a live control-flow diagram (boxes and arrows) served by a local Bun server and viewed in Chromium. Use when the user asks to visualize or explain a process, decision flow, state machine, or the branches of a function.
---

# Control flow diagram

A concept-explainer tool. The diagram teaches a concept one step at a time. Each node is a step, and its `description` explains why that step exists or matters, not just what it does.

A Bun server (`server.ts`) serves `graph.json` as a React Flow diagram and pushes every saved change to the browser over a WebSocket.

`graph.json` and `details/*.md` are output, not skill source. The server reads and writes them under `/tmp/flow-diagram/` (override with `$FLOW_DATA_DIR`), never inside this skill's directory.

## Steps

1. Write the concept into `/tmp/flow-diagram/graph.json`, in this shape:

   ```json
   {
     "nodes": [
       {"id": "start", "label": "Start", "description": "why this step matters", "detailFile": "details/start.md"},
       {"id": "check", "label": "Input valid?", "description": "Downstream logic assumes clean input, so bad input must stop here"}
     ],
     "edges": [{"source": "start", "target": "check", "label": "next"}]
   }
   ```

   - `nodes[].id` (required): unique id.
   - `nodes[].label` (required): short step name, shown in bold.
   - `nodes[].description` (required, non-empty): explains why this step matters, not just what it does. Shown as muted-gray text under the label.
   - `nodes[].detailFile` (optional): path to a Markdown file under `details/`, relative to `/tmp/flow-diagram/` (for example `details/start.md`, saved at `/tmp/flow-diagram/details/start.md`). Use it for 2 to 4 short paragraphs that go deeper into the "why" than `description` can.
   - `edges[].source` and `edges[].target` (required): must match node ids.
   - `edges[].label` (optional): branch conditions such as `yes` and `no`.
   - Loops (back edges) are allowed.

2. Start the server from this skill's directory:

   ```bash
   cd <skill-dir> && bun server.ts
   ```

   It logs `Serving http://localhost:4173 - watching graph.json for changes`. If port 4173 is taken, it uses the next free port and logs that port.

3. Open the logged URL in Chromium:

   ```bash
   chromium http://localhost:4173 &
   ```

4. Edit `/tmp/flow-diagram/graph.json` and save. The browser redraws the diagram through the WebSocket. No refresh needed.
   - If the saved file is invalid (bad JSON, missing `id`/`label`/`description`, or an edge pointing at an unknown node id), the server logs a warning and keeps showing the last valid graph.

5. Click a node that has a `detailFile` to open its detail panel on the right. The browser fetches the raw Markdown from `/details/<file>.md` and renders it with `marked`. Close the panel with the × button, Escape, or a click on empty canvas. Nodes without a `detailFile` do nothing on click.
   - The browser fetches detail files on every click, so edits to `details/*.md` show up on the next click. No refresh needed.

6. Stop the server with Ctrl-C when done.

## Rendering rules

- Layout is top-to-bottom. Each node's row is its longest path from a root. Nodes in the same row spread left and right.
- Layout re-runs on every update.
- Nodes with no incoming edges are start nodes (green).
- Nodes with no outgoing edges are end nodes (red).
- Nodes with more than one outgoing edge are branches (amber).
- All diagram styling lives in `style.css`.

## Files

- `server.ts`: Bun server, file watcher, WebSocket push, and the client script.
- `style.css`: node, label, description, edge, and detail panel styles.
- `/tmp/flow-diagram/graph.json`: the diagram data (output, not tracked in this repo). The server creates a starter graph here on first run if none exists.
- `/tmp/flow-diagram/details/*.md`: per-node Markdown detail (output, not tracked in this repo).

## Requirements

- `bun` and `chromium` on PATH.
- Network access to unpkg.com and cdn.jsdelivr.net when the page opens (React, ReactDOM, and React Flow load from unpkg; `marked` loads from jsDelivr).
