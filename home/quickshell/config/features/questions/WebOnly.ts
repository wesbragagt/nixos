type ToolEvent = {
  toolName: string;
  input?: { path?: unknown };
};

type ToolDecision = { block: true; reason: string } | undefined;
type ExtensionApi = {
  on(event: "tool_call", callback: (event: ToolEvent) => ToolDecision): void;
};

// This is a tool boundary, not an operating-system sandbox.
export default function (pi: ExtensionApi) {
  pi.on("tool_call", (event) => {
    if (event.toolName === "web_search") return;
    if (event.toolName === "read"
        && typeof event.input?.path === "string"
        && /^https?:\/\//i.test(event.input.path)) return;
    return {
      block: true,
      reason: "Quick questions allow only web search and HTTP(S) page reading.",
    };
  });
}
