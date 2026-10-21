{ lib, pkgs, ... }:

let
  diskSwapPath = "/var/lib/swapfile";
  diskSwapMemoryPercent = 50;
  diskSwapUnit = "var-lib-swapfile.swap";
in
{
  # The current icebox workload is memory-pressure bound, not just CPU-bound:
  # journalctl shows global kernel OOM events after zram swap reached 0 free.
  # Make userspace kill runaway desktop/dev processes before the kernel has to.
  systemd.oomd = {
    enable = true;
    enableUserSlices = true;
    settings.OOM = {
      DefaultMemoryPressureLimit = "60%";
      DefaultMemoryPressureDurationSec = "20s";
    };
  };

  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeMemKillThreshold = 2;
    freeSwapThreshold = 10;
    freeSwapKillThreshold = 5;
    enableNotifications = true;
    reportInterval = 60;
    extraArgs = [
      "--prefer"
      "(^|/)(chrome|chromium|node|bun|java)$"
      "--avoid"
      "(^|/)(Hyprland|quickshell|systemd|sshd|tmux|zsh)$"
    ];
  };

  # Keep CPU/IO-heavy background work from starving the compositor and shell.
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-cpp;
    settings = {
      apply_cgroup = false;
      cgroup_load = false;
      cgroup_realtime_workaround = lib.mkForce false;
    };
  };

  # Use zram as the fast first swap tier, but keep it smaller so it does not
  # pin too much RAM under sustained pressure.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  # Add disk-backed emergency overflow sized as a percentage of RAM so this
  # module remains sensible across machines. zswap below compresses/caches this
  # path before it has to hit NVMe, avoiding the zram-only cliff where earlyoom
  # must kill interactive apps as soon as compressed swap fills.
  systemd.services.create-disk-swapfile = {
    description = "Create percentage-sized emergency swapfile";
    wantedBy = [ diskSwapUnit ];
    after = [ "systemd-modules-load.service" ];
    before = [
      diskSwapUnit
      "shutdown.target"
    ];
    conflicts = [ "shutdown.target" ];
    unitConfig = {
      RequiresMountsFor = [ (dirOf diskSwapPath) ];
      DefaultDependencies = false;
    };
    path = with pkgs; [
      coreutils
      e2fsprogs
      gnugrep
      gawk
      util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      UMask = "0177";
    };
    script = ''
      set -euo pipefail

      mem_mib=$(awk '/^MemTotal:/ { print int($2 / 1024) }' /proc/meminfo)
      target_mib=$(( mem_mib * ${toString diskSwapMemoryPercent} / 100 ))
      current_mib=$(( $(stat -c '%s' ${diskSwapPath} 2>/dev/null || echo 0) / 1024 / 1024 ))

      if [ "$current_mib" -eq "$target_mib" ]; then
        exit 0
      fi

      if swapon --show=NAME --noheadings | grep -Fxq ${diskSwapPath}; then
        echo "${diskSwapPath} is active at ''${current_mib}MiB; leaving resize to next boot"
        exit 0
      fi

      mkdir -p ${dirOf diskSwapPath}
      rm -f ${diskSwapPath}
      touch ${diskSwapPath}
      chmod 0600 ${diskSwapPath}
      chattr +C ${diskSwapPath} 2>/dev/null || true
      fallocate -l "''${target_mib}M" ${diskSwapPath}
      mkswap ${diskSwapPath}
    '';
  };

  swapDevices = [
    {
      device = diskSwapPath;
      priority = 1;
      options = [ "nofail" ];
    }
  ];

  boot.kernelParams = [
    "zswap.enabled=1"
    "zswap.compressor=zstd"
    "zswap.max_pool_percent=20"
    "zswap.shrinker_enabled=1"
  ];

  boot.kernel.sysctl = {
    # Prefer reclaiming cache over entering deep swap pressure; disk swap is an
    # emergency overflow tier, not something we want to use aggressively.
    "vm.swappiness" = 30;
    "vm.vfs_cache_pressure" = 50;
  };

  # /tmp on tmpfs is useful, but 50% of 64 GiB lets temp files consume too much
  # RAM during data/dev workloads. Cap it lower so pressure control has headroom.
  boot.tmp = {
    useTmpfs = true;
    tmpfsSize = "25%";
  };

  # Nix builds should yield to interactive desktop work when the machine is hot.
  systemd.services.nix-daemon.serviceConfig = {
    CPUWeight = 50;
    IOWeight = 50;
    Nice = 5;
  };
}
