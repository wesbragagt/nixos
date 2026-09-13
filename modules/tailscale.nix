{ pkgs, ... }:
{
  # Tailscale MagicDNS updates DNS dynamically. Use systemd-resolved instead
  # of plain resolvconf so NetworkManager and Tailscale can coordinate DNS
  # state after link changes/resume, and keep public fallback resolvers
  # available when the Tailscale DNS proxy is temporarily unavailable.
  networking.networkmanager.dns = "systemd-resolved";

  # NetworkManager claimed tailscale0 as an external device and removed the
  # 100.x address that tailscaled had set. The interface kept its routes but
  # sent packets with the LAN source address, so every tailnet host timed out.
  # Keep tailscale0 out of NetworkManager so only tailscaled owns it.
  networking.networkmanager.unmanaged = [ "interface-name:tailscale0" ];

  services.resolved = {
    enable = true;
    fallbackDns = [
      "1.1.1.1"
      "1.0.0.1"
      "8.8.8.8"
      "8.8.4.4"
    ];
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraSetFlags = [ "--ssh" ];
  };

  # The observed failure mode after suspend was: IP routing worked, but
  # /etc/resolv.conf pointed only at Tailscale's 100.100.100.100 resolver and
  # DNS recovered immediately after restarting tailscaled. Refresh tailscaled on
  # resume so its DNS proxy and resolver registration are rebuilt after wake.
  powerManagement.resumeCommands = ''
    ${pkgs.systemd}/bin/systemctl try-restart tailscaled.service
  '';

  environment.systemPackages = with pkgs; [ tailscale ];
}
