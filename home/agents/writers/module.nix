{ config, lib, ... }:
let
  writers = import ./default.nix;
in
{
  home.file = lib.mkMerge ([
    # Codex opens each role file without following a final symlink.
    { ".codex/writer-configs".source = ../../codex/agents; }
  ] ++ lib.mapAttrsToList (name: writer: {
    ".claude/agents/${name}.md".text = ''
      ---
      name: ${name}
      description: ${writer.description}
      model: ${writer.claudeModel}
      color: ${writer.color}
      ---

      ${writer.instructions}
    '';
    ".omp/agent/agents/${name}.md" = lib.mkIf config.wes.omp.enable {
      text = ''
        ---
        name: ${name}
        description: ${writer.description}
        model: ${writer.ompModel}
        ---

        ${writer.instructions}
      '';
    };
  }) writers);
}
