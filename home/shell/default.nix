{
  lib,
  pkgs,
  repoRoot,
  config,
  hostSystem,
  hostProfile ? { },
  ...
}:
let
  sopsHostKeyPath = hostProfile.sopsHostKeyPath or null;
  useSystemSopsSecrets = sopsHostKeyPath != null;
  useHomeSopsSecrets = hostProfile.useHomeSopsSecrets or false;
  isDarwin = lib.hasSuffix "-darwin" hostSystem;
  isLinux = lib.hasSuffix "-linux" hostSystem;
  managedHostName =
    let
      name = hostProfile.name or null;
    in
    if name == null || name == "standalone" then null else name;
  commonAliases = {
    vi = "nvim";
    sf = "file-fzf";
    sg = "grep-fzf";
    mk = "markdown-fzf";
    gs = "git status";
    gitd = "lazygit";
    # git add all changes and commit
    gg = "git add -A && git commit";
    # github cli command to push current branch to origin
    gpr = "git push -u origin HEAD";
    # github cli command to open pull request in browser
    got = "gh pr view --web";
  };
  secretPath =
    systemPath: homePath:
    if useSystemSopsSecrets then
      systemPath
    else if useHomeSopsSecrets then
      homePath
    else
      "";
  exaApiKeyPath = secretPath "/run/secrets/exa_api_key" config.sops.secrets.exa_api_key.path;
  shellBootstrap = ''
    # Non-interactive bash (for example Claude/bash tool invocations) does not
    # read ~/.bashrc, so point it at a small BASH_ENV that imports direnv for
    # the current working directory before running the requested command.
    export BASH_ENV="$HOME/.config/bash/bash_env"

    if [[ -z "$SSH_AUTH_SOCK" && -S "$HOME/.bitwarden-ssh-agent.sock" ]]; then
      export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
    fi

    if [[ -n "${exaApiKeyPath}" && -f "${exaApiKeyPath}" ]]; then
      export EXA_API_KEY="$(< "${exaApiKeyPath}")"
    fi

${lib.optionalString isLinux ''
    # uv-managed venv pythons are downloaded standalone builds that don't get the
    # wrappedPython LD_LIBRARY_PATH prefix, so wheels that dlopen libstdc++ (duckdb,
    # pyarrow, ...) fail to import. Expose the nix-ld library path here so uv's
    # spawned interpreters inherit it.
    export LD_LIBRARY_PATH="/run/current-system/sw/share/nix-ld/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

''}    __flake_host() {
      local host
      host="$(hostname -s 2>/dev/null || hostname)"
      host="''${host%%.*}"

      if [[ -z "$host" ]]; then
        echo "Unable to determine current hostname for rebuild" >&2
        return 1
      fi

      echo "$host"
    }

    rebuild() {
      local action host
      action="''${1:-switch}"

      case "$action" in
${if isDarwin then ''        build|check|switch)'' else ''        boot|build|dry-build|dry-activate|switch|test)''}
          if (( $# > 0 )); then
            shift
          fi
          ;;
        *)
          action="switch"
          ;;
      esac

      host="${if managedHostName == null then "" else managedHostName}"
      if [[ -z "$host" ]]; then
        host="$(__flake_host)" || return
      fi
      echo "Rebuilding host '$host' with action '$action'..." >&2
${if isDarwin then ''      sudo darwin-rebuild "$action" --impure --flake ${repoRoot}#"$host" "$@"'' else ''      sudo nixos-rebuild "$action" --impure --flake ${repoRoot}#"$host" "$@"''}
    }

    cd/() {
      local repo_root
      repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1
      cd "$repo_root"
    }

    cdl() {
      local selection dir
      selection=$(fzf --preview 'bat --style=numbers --color=always --line-range :500 {}') || return 0
      [[ -n "$selection" ]] || return 0

      sleep 0.3
      dir=$(dirname "$selection")
      [[ -n "$dir" ]] || return 0

      echo "Changing directory to $dir"
      cd "$dir"
    }

  '';
in
{
  sops.secrets = lib.optionalAttrs useHomeSopsSecrets {
    exa_api_key = { };
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    MANPAGER = "nvim +Man!";
    BASH_ENV = "$HOME/.config/bash/bash_env";
  };

  home.file.".config/bash/bash_env".text = ''
    # BASH_ENV is sourced by every non-interactive bash, including shellHook
    # helper scripts spawned while direnv/nix-direnv is already evaluating an
    # environment. Re-entering direnv there can recursively load the same dev
    # shell many times.
    if [[ -z "''${__HM_DIRENV_BASH_ENV_ACTIVE:-}" \
       && -z "''${DIRENV_FILE:-}" \
       && -z "''${DIRENV_DIR:-}" ]] \
       && command -v direnv >/dev/null 2>&1; then
      export __HM_DIRENV_BASH_ENV_ACTIVE=1
      eval "$(direnv export bash)"
      unset __HM_DIRENV_BASH_ENV_ACTIVE
    fi
  '';

  programs.bash = {
    enable = true;
    shellAliases = commonAliases;
    initExtra = lib.mkMerge [
      shellBootstrap
      # zoxide's doctor expects its hook to be installed after other shell hooks.
      (lib.mkOrder 9999 ''
        eval "$(${lib.getExe config.programs.zoxide.package} init bash --cmd cd)"
      '')
    ];
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    historySubstringSearch.enable = true;
    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      share = true;
      extended = true;
    };
    shellAliases = commonAliases;
    initContent = lib.mkMerge [
      (shellBootstrap + ''
        if [[ $options[zle] = on && -t 0 && -t 1 ]]; then
          source <(${lib.getExe config.programs.fzf.package} --zsh)
          # fzf binds Ctrl-R in emacs/vi keymaps; bind main explicitly so the
          # active keymap always opens fzf history search instead of redisplay.
          bindkey '^R' fzf-history-widget
          autoload -Uz edit-command-line
          zle -N edit-command-line
          bindkey '^Y' autosuggest-accept
          bindkey '^P' up-line-or-history
          bindkey '^N' down-line-or-history
          bindkey '^X^E' edit-command-line
        fi
      '')
      # Keep zoxide late so later integrations cannot clobber its chpwd hook.
      # Some interactive tools can still reset chpwd_functions after startup;
      # make zoxide's doctor repair the hook instead of printing a warning.
      (lib.mkOrder 9999 ''
        eval "$(${lib.getExe config.programs.zoxide.package} init zsh --cmd cd)"

        __zoxide_doctor() {
          [[ ''${_ZO_DOCTOR:-1} -ne 0 ]] || return 0
          [[ ''${chpwd_functions[(Ie)__zoxide_hook]:-0} -ne 0 ]] || chpwd_functions+=(__zoxide_hook)
        }
      '')
    ];
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    settings = builtins.fromTOML (builtins.readFile ../../starship/zephyr.toml);
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = false;
    enableBashIntegration = true;
    defaultCommand = "rg --files --hidden --follow --glob '!.git'";
    defaultOptions = [
      "--height=40%"
      "--layout=reverse"
      "--border"
    ];
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = false;
    enableBashIntegration = false;
    options = [ "--cmd cd" ];
  };

  programs.ripgrep.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  home.activation.createDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p $HOME/Wallpapers
    mkdir -p $HOME/Screenshots
    mkdir -p $HOME/Videos
  '';
}
