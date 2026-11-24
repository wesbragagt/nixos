{
  easy-writer = {
    description = "Bounded mechanical edits and localized fixes.";
    color = "green";
    claudeModel = "haiku";
    ompModel = "ccflare/claude-haiku-5-5";
    instructions = (builtins.fromTOML (builtins.readFile ../../codex/agents/easy-writer.toml)).developer_instructions;
  };
  moderate-writer = {
    description = "Familiar multi-step implementation, diagnosis and refactoring.";
    color = "yellow";
    claudeModel = "sonnet";
    ompModel = "ccflare/claude-sonnet-5-5";
    instructions = (builtins.fromTOML (builtins.readFile ../../codex/agents/moderate-writer.toml)).developer_instructions;
  };
  hard-writer = {
    description = "Interacting invariants, concurrency, architecture and partial failures.";
    color = "red";
    claudeModel = "opus";
    ompModel = "ccflare/claude-opus-5-5";
    instructions = (builtins.fromTOML (builtins.readFile ../../codex/agents/hard-writer.toml)).developer_instructions;
  };
}
