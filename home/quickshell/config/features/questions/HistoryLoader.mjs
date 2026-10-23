import { constants } from "node:fs";
import { open, readdir } from "node:fs/promises";

function visibleText(content) {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content.filter(block => block?.type === "text" && typeof block.text === "string")
    .map(block => block.text).join("");
}

function conversation(source) {
  let session;
  const records = [];
  const byId = new Map();
  for (const line of source.split("\n")) {
    let record;
    try { record = JSON.parse(line); } catch { continue; }
    if (!record || typeof record !== "object") continue;
    records.push(record);
    if (typeof record.id === "string") byId.set(record.id, record);
    if (record?.type === "session" && typeof record.id === "string" && record.id
        && typeof record.timestamp === "string" && Number.isFinite(Date.parse(record.timestamp))) {
      session = { id: record.id, timestamp: record.timestamp };
    }
  }
  // Late off-branch entries preserve the active leaf explicitly instead of
  // selecting their own ancestry when the session is replayed.
  const latest = records.findLast(record => typeof record.id === "string" && "parentId" in record);
  const leafId = latest?.activeLeafId !== undefined ? latest.activeLeafId : latest?.id;
  const active = [];
  const seen = new Set();
  let cursor = byId.get(leafId);
  while (cursor && !seen.has(cursor.id)) {
    seen.add(cursor.id);
    active.push(cursor);
    cursor = byId.get(cursor.parentId);
  }
  const messages = [];
  for (const record of latest ? active.reverse() : records) {
    if (record.type !== "message") continue;
    const message = record.message;
    if (message?.role !== "user" && message?.role !== "assistant") continue;
    const text = visibleText(message.content);
    if (text.trim()) messages.push({ role: message.role, text });
  }
  const users = messages.filter(message => message.role === "user");
  if (!session || !users.length) return null;
  let answer = "";
  if (users.length === 1) {
    // Tool-loop preambles are separate assistant messages. Keep the latest
    // visible response, including a partial response from an interrupted turn.
    const start = messages.findIndex(message => message.role === "user");
    for (const message of messages.slice(start + 1)) {
      if (message.role === "assistant") answer = message.text;
    }
  } else {
    answer = messages.map(message => "## " + (message.role === "user" ? "User" : "Assistant")
      + "\n\n" + message.text).join("\n\n");
  }
  return { ...session, question: users[0].text, answer };
}

async function load(directory) {
  let files;
  try {
    files = await readdir(directory, { withFileTypes: true });
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
  const entries = [];
  for (const file of files) {
    if (!file.isFile() || !file.name.endsWith(".jsonl")) continue;
    let handle;
    try {
      handle = await open(directory + "/" + file.name, constants.O_RDONLY | constants.O_NOFOLLOW);
      const entry = conversation(await handle.readFile("utf8"));
      if (entry) entries.push(entry);
    } catch (error) {
      // A session removed between directory listing and open is no longer history.
      if (error.code !== "ENOENT") throw error;
    } finally {
      await handle?.close();
    }
  }
  entries.sort((left, right) => Date.parse(right.timestamp) - Date.parse(left.timestamp)
    || left.id.localeCompare(right.id));
  return entries;
}

try {
  const directory = process.argv[2];
  if (!directory || !directory.startsWith("/")) throw new Error("Invalid history directory");
  process.stdout.write(JSON.stringify(await load(directory)));
} catch {
  // Never expose paths, session contents, or provider/tool diagnostics in errors.
  process.stderr.write("Saved history could not be read. Check session directory access.\n");
  process.exitCode = 1;
}
