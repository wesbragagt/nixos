{
  description = "wesbragagt's NixOS + home-manager flake (multi-host)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    exacli = {
      url = "github:wesbragagt/exacli";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    hunk = {
      url = "github:modem-dev/hunk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    qmd = {
      url = "github:tobi/qmd";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    t3code-src = {
      # Change this pointer to build a personal fork.
      url = "github:pingdotgg/t3code/v0.0.40";
      flake = false;
    };
    chromium-webapps = {
      url = "github:chobbledotcom/nix-chromium-webapps";
    };
    tokyo-night-yazi = {
      url = "github:BennyOe/tokyo-night.yazi";
      flake = false;
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur-combined = {
      url = "github:nix-community/nur-combined";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      darwin,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;
      defaultSystem = "x86_64-linux";
      featureConfigPath = /etc/nixos/features.yaml;
      featureConfig =
        if builtins.pathExists featureConfigPath then builtins.readFile featureConfigPath else "";
      featureEnabled =
        name: builtins.any (line: line == "  ${name}: true") (lib.splitString "\n" featureConfig);
      featureDisabled =
        name: builtins.any (line: line == "  ${name}: false") (lib.splitString "\n" featureConfig);
      defaultFeatures = {
        claude-code = false;
        omp = false;
        gaming = false;
        qbittorrent = false;
        mnemosyne = false;
        ffmpeg = false;
        # Coding agents ship on every host; set "<name>: false" in
        # /etc/nixos/features.yaml to opt a host out.
        # Off by default: the upstream npm postinstall downloads from
        # api.nuget.org, which the Nix build sandbox blocks.
        pi-coding-agent = false;
        codex = true;
        t3code = true;
      };
      machineFeatures = lib.mapAttrs (
        name: default: if default then !(featureDisabled name) else featureEnabled name
      ) defaultFeatures;
      # sops defaults on (existing behaviour); set "sops: false" in
      # /etc/nixos/features.yaml to opt a headless/no-yubikey box out of it.
      sopsHomeSecretsEnabled = !(featureDisabled "sops");

      defaultHostProfile = {
        features = machineFeatures;
        isLaptop = false;
        hasWireless = false;
        headless = false;
        graphics = "generic";
        swapAltSuper = true;
        hypridle = {
          lockTimeout = 300;
          dpmsTimeout = 330;
          suspendTimeout = null;
          suspendRequiresNoSsh = false;
        };
        sopsHostKeyPath = null;
        useHomeSopsSecrets = false;
      };

      homeManagerModule =
        {
          resolvedHostProfile,
          hostSystem,
        }:
        {
          wes.host = lib.removeAttrs resolvedHostProfile [
            "name"
            "useHomeSopsSecrets"
            "features"
            "hunkEnabled"
          ];
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "hm-bak";
          home-manager.extraSpecialArgs = {
            inherit inputs hostSystem;
            hostProfile = resolvedHostProfile;
          };
          home-manager.users.wesbragagt = import ./home/wesbragagt.nix;
        };

      mkHost =
        {
          name,
          system ? defaultSystem,
          hostProfile ? { },
        }:
        let
          resolvedHostProfile = (lib.recursiveUpdate defaultHostProfile hostProfile) // {
            inherit name;
          };
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            hostProfile = resolvedHostProfile;
          };
          modules = [
            (./hosts + "/${name}")
            inputs.sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            (homeManagerModule {
              inherit resolvedHostProfile;
              hostSystem = system;
            })
          ];
        };

      mkDarwinHost =
        {
          name,
          system ? "aarch64-darwin",
          hostProfile ? { },
        }:
        let
          resolvedHostProfile = (lib.recursiveUpdate defaultHostProfile hostProfile) // {
            inherit name;
          };
        in
        darwin.lib.darwinSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            hostProfile = resolvedHostProfile;
          };
          modules = [
            (./hosts + "/${name}")
            ./modules/host-profile.nix
            home-manager.darwinModules.home-manager
            (homeManagerModule {
              inherit resolvedHostProfile;
              hostSystem = system;
            })
          ];
        };
    in
    {
      nixosConfigurations = {
        nixos-hp = mkHost {
          name = "nixos-hp";
          hostProfile = {
            isLaptop = true;
            hasWireless = true;
            graphics = "intel";
            hypridle = {
              lockTimeout = 300;
              dpmsTimeout = 330;
              suspendTimeout = 1800;
            };
            sopsHostKeyPath = "/etc/ssh/ssh_host_ed25519_key";
            # bun (via hunkdiff) needs AVX2; this host's Celeron N4120 lacks it.
            hunkEnabled = false;
          };
        };

        icebox = mkHost {
          name = "icebox";
          hostProfile = {
            isLaptop = false;
            hasWireless = false;
            graphics = "amd";
            swapAltSuper = false;
            hypridle = {
              lockTimeout = 900;
              dpmsTimeout = 1200;
              suspendTimeout = 3600;
              suspendRequiresNoSsh = true;
            };
            sopsHostKeyPath = "/etc/ssh/ssh_host_ed25519_key";
          };
        };
      };

      darwinConfigurations.macos = mkDarwinHost {
        name = "macos";
        hostProfile = {
          # /etc/nixos/features.yaml is a NixOS path, so darwin hosts declare features here.
          features = {
            claude-code = true;
            omp = true;
          };
          isLaptop = true;
          useHomeSopsSecrets = true;
        };
      };

      # Standalone home-manager for non-NixOS Linux machines.
      # Apply with: nix run home-manager/master -- switch --flake .#wesbragagt
      homeConfigurations.wesbragagt = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${defaultSystem};
        extraSpecialArgs = {
          inherit inputs;
          hostSystem = defaultSystem;
          hostProfile = defaultHostProfile // {
            name = "standalone";
            useHomeSopsSecrets = sopsHomeSecretsEnabled;
          };
        };
        modules = [
          ./home/standalone-policy.nix
          ./home/wesbragagt.nix
        ];
      };

      # Standalone home-manager for headless Linux servers.
      # Apply with: nix run home-manager/master -- switch --flake .#wesbragagt-server
      homeConfigurations.wesbragagt-server = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${defaultSystem};
        extraSpecialArgs = {
          inherit inputs;
          hostSystem = defaultSystem;
          hostProfile = defaultHostProfile // {
            name = "standalone-server";
            headless = true;
            useHomeSopsSecrets = sopsHomeSecretsEnabled;
          };
        };
        modules = [
          ./home/standalone-policy.nix
          ./home/wesbragagt.nix
        ];
      };
    };
}
