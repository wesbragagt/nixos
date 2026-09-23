{ lib, pkgs, inputs, ... }:

let
  hardwareConfig = ./hardware-configuration.nix;
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  t3code = unstable.callPackage ../../pkgs/t3code { t3codeSrc = inputs.t3code-src; };
in
{
  imports = (lib.optional (builtins.pathExists hardwareConfig) hardwareConfig) ++ [
    ../../common.nix
  ];

  assertions = lib.optional (!(builtins.pathExists hardwareConfig)) {
    assertion = false;
    message = ''
      icebox is missing hosts/icebox/hardware-configuration.nix.
      Generate it on icebox with:
        sudo nixos-generate-config --show-hardware-config > hosts/icebox/hardware-configuration.nix
    '';
  };

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Identity
  networking.hostName = "icebox";

  # t3code desktop control surface, reachable from phones on the LAN
  # and over the tailnet at http://icebox:3773.
  networking.firewall.allowedTCPPorts = [ 3773 ];

  systemd.services.t3code-server = {
    description = "T3 Code server (tailnet-reachable control surface)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      User = "wesbragagt";
      ExecStart = "${t3code}/bin/t3 serve --host 0.0.0.0 --port 3773";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # Wake-on-LAN for the wired NIC. BIOS enables platform support, but Linux
  # still needs to allow the PCI device as a wake source and arm magic-packet
  # wake after each boot.
  environment.systemPackages = with pkgs; [ ethtool ];
  systemd.services.wake-on-lan = {
    description = "Enable Wake-on-LAN for enp9s0";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      iface=enp9s0
      if [ -e "/sys/class/net/$iface/device/power/wakeup" ]; then
        echo enabled > "/sys/class/net/$iface/device/power/wakeup"
      fi
      ${pkgs.ethtool}/bin/ethtool -s "$iface" wol g
    '';
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  system.stateVersion = "25.11";
}
