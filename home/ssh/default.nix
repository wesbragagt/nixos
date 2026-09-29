{ ... }:
{
  home.sessionVariables = {
    SSH_AUTH_SOCK = "$HOME/.bitwarden-ssh-agent.sock";
  };

  home.file.".ssh/github_key.pub" = {
    source = ./github_key.pub;
    force = true;
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "icebox" = {
        hostname = "icebox";
        user = "wesbragagt";
        localForwards = [
          { bind.port = 3000; host.address = "localhost"; host.port = 3000; }
          { bind.port = 3002; host.address = "localhost"; host.port = 3002; }
          { bind.port = 8250; host.address = "localhost"; host.port = 8250; }
        ];
      };
      "github.com" = {
        hostname = "github.com";
        user = "git";
        # Public key stub used to select the matching Bitwarden-managed agent key.
        identityFile = "~/.ssh/github_key.pub";
        identityAgent = "~/.bitwarden-ssh-agent.sock";
        identitiesOnly = true;
      };
    };
  };
}
