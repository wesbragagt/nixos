{ lib, config, pkgs, repoRoot, ... }:
let
  mkSkillLinks = import ../lib/mk-skill-links.nix { inherit lib; };
in
{
  # Codex discovers user skills here. Link individual skills so externally
  # installed skills can coexist, keeping one live source for all harnesses.
  home.activation.backupCodexConfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    target="$HOME/.codex/config.toml"
    if [ -f "$target" ] && [ ! -L "$target" ]; then
      if [ -e "$target.before-nix" ]; then
        echo "Codex config backup already exists: $target.before-nix" >&2
        exit 1
      fi
      $DRY_RUN_CMD mv "$target" "$target.before-nix"
    fi
  '';
  home.file = {
    ".codex/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${repoRoot}/home/codex/config.toml";
    ".codex/AGENTS.md".source =
      config.lib.file.mkOutOfStoreSymlink "${repoRoot}/home/agents/AGENTS.md";
  } // mkSkillLinks {
    inherit (config.lib.file) mkOutOfStoreSymlink;
    skillsRoot = "${repoRoot}/home/skills";
    targetPrefix = ".agents/skills";
  };
}
