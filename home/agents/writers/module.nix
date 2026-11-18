{ config, lib, repoRoot, ... }:
let
  writers = import ./default.nix;
in
{
  home.file = lib.mkMerge (lib.mapAttrsToList (name: writer: {
    ".claude/agents/${name}.md".text = ''
      ---
      name: ${name}
      description: ${writer.description}
      model: ${writer.claudeModel}
      color: ${writer.color}
      ---

      ${writer.instructions}
    '';
    ".codex/agents/${name}.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${repoRoot}/home/codex/agents/${name}.toml";
  }) writers);
}
