{ lib, pkgs, ... }:

let
  hardwareConfig = ./hardware-configuration.nix;
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
