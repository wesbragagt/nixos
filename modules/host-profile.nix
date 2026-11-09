{ lib, ... }:

{
  options.wes.host = {
    isLaptop = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether this host has laptop-only hardware such as a lid, battery, backlight keys, and touchpad.";
    };

    hasWireless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to install and launch Wi-Fi-oriented desktop UI helpers.";
    };

    headless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether this host runs without a local graphical display.";
    };

    graphics = lib.mkOption {
      type = lib.types.enum [
        "generic"
        "intel"
        "amd"
        "nvidia"
      ];
      default = "generic";
      description = "Host graphics profile used for hardware acceleration packages and environment defaults.";
    };

    swapAltSuperKeyboards = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "32ac:0012" ];
      description = "keyd vendor:product IDs of keyboards that swap left Alt and left Super; other keyboards keep native keys.";
    };

    hypridle = {
      lockTimeout = lib.mkOption {
        type = lib.types.ints.positive;
        default = 300;
        description = "Seconds of inactivity before locking the session.";
      };

      dpmsTimeout = lib.mkOption {
        type = lib.types.ints.positive;
        default = 330;
        description = "Seconds of inactivity before turning displays off.";
      };

      suspendTimeout = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "Seconds of inactivity before suspending, or null to disable idle suspend.";
      };

      suspendRequiresNoSsh = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "When true, the idle suspend command skips suspend while a remote SSH session is active.";
      };
    };

    sopsHostKeyPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/etc/ssh/ssh_host_ed25519_key";
      description = ''
        Host SSH private key path used by sops-nix for unattended system
        secret decryption. Leave null for bootstrap installs before the host
        key has been generated and added as a recipient.
      '';
    };
  };
}
