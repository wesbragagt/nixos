{ config, lib, pkgs, ... }:

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
      iceflake is missing hosts/iceflake/hardware-configuration.nix.
      Generate it on the Framework 16 from the repo root with:
        sudo nixos-generate-config --show-hardware-config > hosts/iceflake/hardware-configuration.nix
      Then stage it with git add -A before running rebuild build.
    '';
  };

  networking.hostName = "iceflake";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.kernelModules = [ "amdgpu" ];

  # Match the driver rather than a PCI address or an unstable card number.
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="card[0-9]*", ENV{DEVTYPE}=="drm_minor", DRIVERS=="amdgpu", SYMLINK+="dri/amd-integrated"
  '';

  # Restrict the desktop compositor to AMD; NVIDIA stays available to apps.
  environment.sessionVariables.AQ_DRM_DEVICES = "/dev/dri/amd-integrated";

  # The login screen uses its own compositor, before the user session starts.
  services.displayManager.sddm.wayland.compositor = "kwin";
  systemd.services.display-manager.environment.KWIN_DRM_DEVICES = "/dev/dri/amd-integrated";

  # Keep AMD available for the desktop and select NVIDIA per application.
  # Deliberately leave hardware.nvidia.prime unset: no PCI bus IDs required.
  services.xserver.videoDrivers = [ "amdgpu" "nvidia" ];
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  boot.blacklistedKernelModules = [ "nouveau" ];

  environment.systemPackages = with pkgs; [
    pciutils
    vulkan-tools
    mesa-demos
  ];

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  system.stateVersion = "25.11";
}
