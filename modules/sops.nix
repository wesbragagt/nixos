{
  lib,
  pkgs,
  config,
  ...
}:
let
  repoSecretsFile = ../secrets/secrets.yaml;
  sopsHostKeyPath = config.wes.host.sopsHostKeyPath;
  hasSopsHostKey = sopsHostKeyPath != null;
in
{
  services.pcscd.enable = lib.mkDefault true;

  sops = {
    age = {
      sshKeyPaths = lib.optionals hasSopsHostKey [ sopsHostKeyPath ];
      plugins = [ pkgs.age-plugin-yubikey ];
    };
    defaultSopsFormat = "yaml";
  }
  // lib.optionalAttrs (hasSopsHostKey && builtins.pathExists repoSecretsFile) {
    defaultSopsFile = repoSecretsFile;
    secrets = {
      exa_api_key = {
        owner = "wesbragagt";
      };
      forgejo_token = {
        owner = "wesbragagt";
      };
    };
  };
}
