{ lib, config, repoRoot, ... }:
let
  mkSkillLinks = import ../lib/mk-skill-links.nix { inherit lib; };
in
{
  # Codex discovers user skills here. Link individual skills so externally
  # installed skills can coexist, keeping one live source for all harnesses.
  home.file = {
    ".codex/AGENTS.md".source =
      config.lib.file.mkOutOfStoreSymlink "${repoRoot}/home/agents/AGENTS.md";
  } // mkSkillLinks {
    inherit (config.lib.file) mkOutOfStoreSymlink;
    skillsRoot = "${repoRoot}/home/skills";
    targetPrefix = ".agents/skills";
  };
}
