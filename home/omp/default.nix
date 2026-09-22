{ lib, pkgs, config, repoRoot, ... }:
let
  cfg = config.wes.omp;
  ompPkg = pkgs.callPackage ../../pkgs/pi-coding-agent {
    bun-bin-1_4_2 = pkgs.callPackage ../../pkgs/bun-bin-1_4_2 { };
  };

  mkSkillLinks = import ../lib/mk-skill-links.nix { inherit lib; };
  repoSkillLinks = mkSkillLinks {
    inherit (config.lib.file) mkOutOfStoreSymlink;
    skillsRoot = cfg.skillsRoot;
    targetPrefix = ".omp/agent/skills";
  };

  agentsLink = lib.optionalAttrs (builtins.pathExists ./config/agents) {
    ".omp/agent/agents".source = config.lib.file.mkOutOfStoreSymlink "${cfg.configRoot}/agents";
  };

  # Expose the shared verifier agent definition to OMP without duplicating it.
  # Skipped when config/agents exists, since agentsLink already symlinks the
  # whole ".omp/agent/agents" directory and would collide with a per-file link.
  verifierAgentLink = lib.optionalAttrs (!builtins.pathExists ./config/agents) {
    ".omp/agent/agents/verifier.md".source =
      config.lib.file.mkOutOfStoreSymlink "${repoRoot}/home/claude/config/agents/verifier.md";
  };

  yamlFormat = pkgs.formats.yaml { };

  # Metadata for models the bundled OMP catalog does not know. Without an entry
  # here OMP falls back to contextWindow 128000, maxTokens 16384, reasoning
  # false and zero cost, which breaks compaction and cost reporting.
  # Values come from the models.dev `openai/gpt-6-astra` entry, the same
  # catalogue OMP itself builds from.
  modelMetadata = {
    "gpt-6-astra" = {
      name = "GPT-6 Astra";
      reasoning = true;
      supportsTools = true;
      contextWindow = 1050000;
      maxTokens = 128000;
      input = [ "text" "image" ];
      thinking = {
        mode = "effort";
        efforts = [ "low" "medium" "high" "xhigh" "max" ];
      };
      cost = {
        input = 10;
        output = 50;
        cacheRead = 1;
        cacheWrite = 12.5;
      };
    };
  };

  # Generated from home/ccflare/config.yml so OMP and Claude Code share one pointer.
  modelsFile = yamlFormat.generate "omp-models.yml" {
    providers.ccflare = {
      inherit (config.wes.ccflare) baseUrl apiKey;
      api = "anthropic-messages";
      models = map (id: { inherit id; } // (modelMetadata.${id} or { })) config.wes.ccflare.models;
    };
  };
in
{
  options.wes.omp = {
    enable = lib.mkEnableOption "repo-managed OMP (Oh My Pi) agent config";

    configRoot = lib.mkOption {
      type = lib.types.str;
      default = "${repoRoot}/home/omp/config";
      description = "Repo-managed OMP agent config root.";
    };

    skillsRoot = lib.mkOption {
      type = lib.types.str;
      default = "${repoRoot}/home/skills";
      description = "Shared skills source root, linked into ~/.omp/agent/skills.";
    };
  };

  config = lib.mkIf cfg.enable {

    home.packages = [ ompPkg ];

    home.file = {
      ".omp/agent/config.yml".source =
        config.lib.file.mkOutOfStoreSymlink "${cfg.configRoot}/config.yml";
      ".omp/agent/models.yml".source = modelsFile;
      ".omp/agent/AGENTS.md".source =
        config.lib.file.mkOutOfStoreSymlink "${cfg.configRoot}/AGENTS.md";
      ".omp/agent/rules/communication.md".source =
        config.lib.file.mkOutOfStoreSymlink "${cfg.configRoot}/rules/communication.md";
    }
    // agentsLink
    // verifierAgentLink
    // repoSkillLinks;

    # OMP writes runtime files (config.yml updates, dbs) into ~/.omp/agent.
    # Drop any pre-existing plain files so home-manager can take over the
    # mutable out-of-store symlinks without a checkLinkTargets clobber error.
    home.activation.removeLegacyOmpConfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      for f in config.yml models.yml AGENTS.md; do
        target="$HOME/.omp/agent/$f"
        if [ -e "$target" ] && [ ! -L "$target" ]; then
          $DRY_RUN_CMD rm -f "$target"
        fi
      done
    '';
  };
}
