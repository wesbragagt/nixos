{
  easy-writer = {
    description = "Bounded mechanical edits and localized fixes.";
    color = "green";
    claudeModel = "haiku";
    instructions = (builtins.fromTOML (builtins.readFile ../../codex/agents/easy-writer.toml)).developer_instructions;
  };
  moderate-writer = {
    description = "Familiar multi-step implementation, diagnosis and refactoring.";
    color = "yellow";
    claudeModel = "sonnet";
    instructions = (builtins.fromTOML (builtins.readFile ../../codex/agents/moderate-writer.toml)).developer_instructions;
  };
  hard-writer = {
    description = "Interacting invariants, concurrency, architecture and partial failures.";
    color = "red";
    claudeModel = "opus";
    instructions = (builtins.fromTOML (builtins.readFile ../../codex/agents/hard-writer.toml)).developer_instructions;
  };
}
