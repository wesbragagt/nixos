# iceflake — Framework 16

AMD desktop graphics with the NVIDIA open kernel driver available for per-app
render offloading. No PRIME bus IDs or global NVIDIA offload variables are set.
The shared graphics module enables both 64-bit and 32-bit graphics support.
The desktop uses this repository's Hyprland configuration.

AMD is loaded in the initrd for early display initialization. A driver-based udev
rule creates `/dev/dri/amd-integrated`, independent of PCI addresses and DRM card
numbering. Hyprland uses only this device through `AQ_DRM_DEVICES`. The SDDM login
screen uses KWin with `KWIN_DRM_DEVICES` set to the same AMD device.
Displays wired directly to the NVIDIA GPU are excluded from these compositors;
use the laptop's internal screen for the initial boot test.

## Bootstrap on the Framework

From the repository root on the installed Framework NixOS system:

```bash
sudo nixos-generate-config --show-hardware-config > hosts/iceflake/hardware-configuration.nix
git add -A
```

Alternatively, copy that machine's existing generated
`/etc/nixos/hardware-configuration.nix` into the same destination. Do not copy
another host's hardware file. The configuration refuses to build without it.

`system.stateVersion` starts at `25.11`; if the Framework's existing installation
uses a different value, preserve that value in `default.nix` before rebuilding.
This host assumes a UEFI installation using systemd-boot.

The documented `rebuild` command selects the current hostname. Ensure the
Framework's hostname is `iceflake` first (if necessary, run
`sudo hostnamectl set-hostname iceflake` on the Framework), then:

```bash
rebuild build
rebuild boot
```

Reboot to test the new generation. Keep the previous working generation available
in the boot menu for recovery. If `rebuild` is unavailable on that installation,
stop and arrange the documented helper before proceeding.

System secrets are disabled for bootstrap. Follow `secrets/README.md` to enroll
the host before enabling `sopsHostKeyPath` in its flake profile.

## Check graphics after reboot

```bash
lspci -nnk | rg -A3 'VGA|3D|Display'
ls -l /dev/dri/amd-integrated
glxinfo -B
vulkaninfo --summary
nvidia-smi

__NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only vulkaninfo --summary
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia glxinfo -B
```

Verify the normal desktop renderer is AMD and the offloaded commands report
NVIDIA. Without NixOS PRIME configuration, GPU selection still needs verification
on the actual hardware, particularly for Wayland applications and external
displays. The GLX check exercises Xwayland in a Wayland session.
