{ lib, pkgs, hostProfile ? { }, ... }:

let
  enabled = (hostProfile.features or { }).vanta or false;
  agent = pkgs.callPackage ../pkgs/vanta-agent { };
in
{
  config = lib.mkIf enabled {
    environment.systemPackages = [ agent ];

    # Vanta downloads new osquery binaries into /var/vanta after installation.
    programs.nix-ld.enable = true;

    systemd.tmpfiles.rules = [ "d /var/vanta 0700 root root -" ];

    systemd.services.vanta = {
      description = "Vanta device compliance agent";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig.ConditionPathExists = "/etc/vanta.conf";
      path = with pkgs; [ coreutils procps util-linux systemd ];
      environment = {
        NIX_LD = "${pkgs.stdenv.cc.bintools.dynamicLinker}";
        NIX_LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.glibc ];
        SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
      };
      preStart = ''
        chmod 600 /etc/vanta.conf
        # Keep runtime updates across restarts; reseed when the pinned package changes.
        if [ ! -f /var/vanta/.package ] || [ "$(cat /var/vanta/.package)" != "${agent}" ]; then
          cp --no-preserve=mode ${agent}/share/vanta/* /var/vanta/
          chmod 700 /var/vanta/{launcher,metalauncher,osqueryd,osquery-vanta.ext,vanta-cli}
          echo '${agent}' > /var/vanta/.package
        fi
      '';
      serviceConfig = {
        Type = "simple";
        WorkingDirectory = "/var/vanta";
        ExecStart = "/var/vanta/metalauncher";
        Restart = "on-failure";
        RestartSec = 5;
        KillMode = "control-group";
        TimeoutStartSec = 0;
      };
    };
  };
}
