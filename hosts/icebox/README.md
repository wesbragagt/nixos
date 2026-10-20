# icebox

Starter desktop host based on `nixos-hp`, using hostname `icebox`, the same `wesbragagt` user, and shared base config, but without laptop-only/wireless profile features. It also disables the Hyprland Alt/Super swap with `swapAltSuper = false` and uses a desktop idle policy: lock after 15 minutes, turn displays off after 20 minutes, and suspend after 30 minutes only when no SSH session is active.

`idle-control toggle` or Super+Shift+I disables idle timers without unlocking the desktop. The lock screen runs in its own `hyprlock.service`, so stopping `hypridle.service` does not kill it and leave Hyprland locked without a password prompt.

Before installing or building this host, generate the machine-specific hardware config on icebox:

```bash
sudo nixos-generate-config --show-hardware-config > hosts/icebox/hardware-configuration.nix
```

Do not copy `hosts/nixos-hp/hardware-configuration.nix`; it contains HP-specific disk UUIDs and CPU modules.

This host starts in SOPS bootstrap mode (`sopsHostKeyPath = null` in `flake.nix`), so the first switch does not require `/etc/ssh/ssh_host_ed25519_key` or an `icebox` recipient in `.sops.yaml`.

After the first successful switch, enable unattended secrets:

1. Generate or verify the host key on icebox:

```bash
sudo ssh-keygen -A
nix-shell -p ssh-to-age --run 'ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub'
```

2. Add that recipient to `.sops.yaml` and re-wrap secrets from an admin machine:

```bash
sops-updatekeys-all
```

3. Set `sopsHostKeyPath = "/etc/ssh/ssh_host_ed25519_key"` for `icebox` in `flake.nix`, commit/push, then switch again.
