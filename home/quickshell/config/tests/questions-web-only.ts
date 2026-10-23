import extension from "../features/questions/WebOnly";
import { strict as assert } from "node:assert";

type ToolEvent = { toolName: string; input: { query?: string; path?: string; command?: string } };
type ToolGuard = (event: ToolEvent) => { block: true; reason: string } | undefined;
let callback: ToolGuard;
extension({ on(name: string, handler: ToolGuard) { assert.equal(name, "tool_call"); callback = handler; } });
for (const event of [
  { toolName: "web_search", input: { query: "Qt" } },
  { toolName: "read", input: { path: "https://doc.qt.io/qt-6/qml-qtquick-textedit.html" } },
  { toolName: "read", input: { path: "HTTP://example.com/" } },
]) assert.equal((await callback!(event))?.block, undefined);
for (const event of [
  { toolName: "read", input: { path: "/etc/passwd" } },
  { toolName: "read", input: { path: "file:///etc/passwd" } },
  { toolName: "read", input: { path: "ssh://server/secret" } },
  { toolName: "read", input: { path: "cfg://settings" } },
  { toolName: "read", input: {} },
  { toolName: "bash", input: { command: "true" } },
]) assert.equal((await callback!(event))?.block, true);
console.log("Web-only boundary passed: HTTP(S) and search allowed; local/internal/other tools denied.");
