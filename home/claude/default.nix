{
  lib,
  pkgs,
  config,
  repoRoot,
  inputs,
  hostProfile ? { },
  ...
}:
let
  hunkEnabled = hostProfile.hunkEnabled or true;
  cfg = config.wes.claudeCode;
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv) system;
    config.allowUnfree = true;
  };
  claudeCodePackage = unstable.callPackage ../../pkgs/claude-code { };
  mkSkillLinks = import ../lib/mk-skill-links.nix { inherit lib; };
  repoSkillLinks = mkSkillLinks {
    inherit (config.lib.file) mkOutOfStoreSymlink;
    skillsRoot = cfg.skillsRoot;
    targetPrefix = ".claude/skills";
  };
in
{
  options.wes.claudeCode = {
    enable = lib.mkEnableOption "repo-managed Claude Code";

    package = lib.mkOption {
      type = lib.types.package;
      default = claudeCodePackage;
      defaultText = lib.literalExpression "pkgs.callPackage ../../pkgs/claude-code { }";
      description = "Claude Code package to install.";
    };

    aliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        cc = "claude-code";
        claude = "claude-code";
      };
      description = "Shell aliases to expose for Claude Code.";
    };

    configRoot = lib.mkOption {
      type = lib.types.str;
      default = "${repoRoot}/home/claude/config";
      description = "Repo-managed Claude Code config root.";
    };

    skillsRoot = lib.mkOption {
      type = lib.types.str;
      default = "${repoRoot}/home/skills";
      description = "Shared skills source root, linked into ~/.claude/skills.";
    };

    sandbox = {
      enable = lib.mkEnableOption "future Claude Code sandbox support";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file = {
      ".claude/CLAUDE.md".source =
        config.lib.file.mkOutOfStoreSymlink "${cfg.configRoot}/CLAUDE.md";
      ".claude/agents".source = config.lib.file.mkOutOfStoreSymlink "${cfg.configRoot}/agents";
      ".claude/commands".source = config.lib.file.mkOutOfStoreSymlink "${cfg.configRoot}/commands";
      ".claude/rules".source = config.lib.file.mkOutOfStoreSymlink "${cfg.configRoot}/rules";
      ".claude/output-styles/asd-ste100.md".source =
        config.lib.file.mkOutOfStoreSymlink "${cfg.configRoot}/output-styles/asd-ste100.md";
    }
    // lib.optionalAttrs hunkEnabled {
      ".claude/skills/hunk".source = inputs.hunk + "/skills/hunk-review";
    }
    // repoSkillLinks;

    home.activation.removeLegacyClaudeSkillsLink = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      if [ -L "$HOME/.claude/skills" ]; then
        $DRY_RUN_CMD rm "$HOME/.claude/skills"
      fi
    '';

    home.activation.setClaudeOutputStyle = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      settings="$HOME/.claude/settings.json"
      tmp="$settings.tmp"
      $DRY_RUN_CMD mkdir -p "$HOME/.claude"
      if [ -f "$settings" ]; then
        $DRY_RUN_CMD ${pkgs.jq}/bin/jq \
          '.outputStyle = "ASD-STE100" | .env.ENABLE_CLAUDEAI_MCP_SERVERS = "false" | .permissions.deny = ((.permissions.deny // []) + ["WebSearch"] | unique)' \
          "$settings" > "$tmp"
      else
        $DRY_RUN_CMD printf '%s\n' '{"outputStyle":"ASD-STE100","env":{"ENABLE_CLAUDEAI_MCP_SERVERS":"false"},"permissions":{"deny":["WebSearch"]}}' > "$tmp"
      fi
      $DRY_RUN_CMD mv "$tmp" "$settings"
    '';

    programs.bash.shellAliases = cfg.aliases;
    programs.zsh.shellAliases = cfg.aliases;
  };
}
