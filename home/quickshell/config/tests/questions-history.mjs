import assert from "node:assert/strict";
import { mkdtemp, writeFile, readFile, mkdir, symlink, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = await mkdtemp(join(tmpdir(), "quickshell-history-"));
const directory = join(root, "sessions");
const loader = fileURLToPath(new URL("../features/questions/HistoryLoader.mjs", import.meta.url));
function invoke(path = directory) {
  return spawnSync(process.execPath, [loader, path], { encoding: "utf8" });
}
function entries() {
  const result = invoke();
  assert.equal(result.status, 0, result.stderr);
  return JSON.parse(result.stdout);
}
const header = (id, timestamp) => ({ type: "session", id, timestamp, cwd: "/secret/filesystem" });
const message = (role, content) => ({ type: "message", message: { role, content } });
const text = value => ({ type: "text", text: value });
const jsonl = records => records.map(record => JSON.stringify(record)).join("\n") + "\n";
try {
  assert.deepEqual(entries(), [], "missing directory is empty history");
  await mkdir(directory);
  assert.deepEqual(entries(), [], "empty directory is empty history");
  const single = jsonl([
    header("single", "2026-10-22T18:00:00Z"),
    { type: "model_change", model: "anything" },
    message("user", [text("Official Qt documentation?")]),
    message("assistant", [text("Searching the web"), { type: "toolCall", name: "secret-tool" }]),
    message("toolResult", [text("secret-tool-output")]),
    message("assistant", [{ type: "thinking", thinking: "secret-thought" }, text("## Qt\n"), text("Use the official [docs](https://doc.qt.io/).")])
  ]);
  await writeFile(join(directory, "single.jsonl"), single + "{not-json}\n" + '{"type":"message"');
  await writeFile(join(directory, "multi.jsonl"), jsonl([
    header("multi", "2026-10-23T18:00:00Z"),
    message("user", "First question"),
    message("assistant", "First answer"),
    message("user", [text("Follow-up unicorn")]),
    message("assistant", [text("Second answer")])
  ]));
  await writeFile(join(directory, "partial.jsonl"), jsonl([
    header("partial", "2026-10-24T18:00:00Z"),
    message("user", "Interrupted request"),
    message("assistant", [text("Partial response")])
  ]));
  await writeFile(join(directory, "pending.jsonl"), jsonl([
    header("pending", "2026-10-21T18:00:00Z"), message("user", "No answer yet")
  ]));
  await writeFile(join(directory, "junk.jsonl"), "not JSON\n");
  await writeFile(join(directory, "ignored.txt"), single);
  await symlink(join(directory, "single.jsonl"), join(directory, "linked.jsonl"));
  await mkdir(join(directory, "nested.jsonl"));
  const loaded = entries();
  assert.deepEqual(loaded.map(entry => entry.id), ["partial", "multi", "single", "pending"], "sort by session timestamp, not filename or model");
  assert.equal(loaded[0].answer, "Partial response", "interrupted response remains readable");
  assert.equal(loaded[1].question, "First question");
  assert.equal(loaded[1].answer, "## User\n\nFirst question\n\n## Assistant\n\nFirst answer\n\n## User\n\nFollow-up unicorn\n\n## Assistant\n\nSecond answer", "multi-turn history retains visible conversation and roles");
  assert.equal(loaded[2].answer, "## Qt\nUse the official [docs](https://doc.qt.io/).", "final visible assistant replaces preamble despite malformed trailing records");
  assert.equal(loaded[3].answer, "", "unanswered request remains findable");
  for (const hidden of ["secret-tool", "secret-tool-output", "secret-thought", "/secret/filesystem", "Searching the web"]) {
    assert.ok(!JSON.stringify(loaded).includes(hidden), "non-answer material excluded: " + hidden);
  }
  assert.deepEqual(Object.keys(loaded[0]).sort(), ["answer", "id", "question", "timestamp"]);
  await writeFile(join(directory, "partial.jsonl"), jsonl([
    header("partial", "2026-10-24T18:00:00Z"), message("user", "Interrupted request"), message("assistant", "Now complete")
  ]));
  assert.equal(entries()[0].answer, "Now complete", "refresh rereads current file contents");
  assert.equal(await readFile(join(directory, "single.jsonl"), "utf8"), single + "{not-json}\n" + '{"type":"message"', "loader never rewrites sessions");
  const failed = invoke(join(directory, "single.jsonl"));
  assert.notEqual(failed.status, 0, "unreadable directory is not an empty result");
  assert.match(failed.stderr, /Saved history could not be read/);
  assert.ok(!failed.stderr.includes(directory), "load diagnostics expose no filesystem details");
  assert.equal(failed.stdout, "");
  await writeFile(join(directory, "branch.jsonl"), jsonl([
    header("branch", "2026-10-25T18:00:00Z"),
    { ...message("user", "Active question"), id: "u", parentId: null },
    { ...message("assistant", "Abandoned reply"), id: "old", parentId: "u" },
    { ...message("user", "Abandoned followup"), id: "follow", parentId: "old" },
    { ...message("assistant", "Current reply"), id: "current", parentId: "u" },
    { type: "custom", id: "exit", parentId: "current", data: "private metadata" },
    { type: "model_usage", id: "late-usage", parentId: "old", activeLeafId: "current" }
  ]));
  assert.equal(entries()[0].answer, "Current reply", "late off-branch usage preserves the saved active leaf");
  assert.ok(!JSON.stringify(entries()[0]).includes("Abandoned"));
  await writeFile(join(directory, "branch.jsonl"), jsonl([
    header("branch", "2026-10-25T18:00:00Z"),
    { ...message("user", "Abandoned question"), id: "u", parentId: null },
    { type: "model_usage", id: "usage", parentId: "u", activeLeafId: null }
  ]));
  assert.ok(!entries().some(entry => entry.id === "branch"), "explicitly empty active leaf does not restore abandoned messages");
  console.log("BEHAVIOR PASS: saved history loader");
} finally {
  await rm(root, { recursive: true, force: true });
}
