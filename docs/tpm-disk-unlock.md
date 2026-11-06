# TPM disk unlock on iceflake

## Boot behavior and security

The disk stays LUKS2-encrypted. The TPM unlocks it during boot, then SDDM asks
for the normal user login password. Automatic desktop login is not enabled.
The existing disk passphrase remains available if TPM unlock fails.

This setup intentionally runs without Secure Boot. It favors convenience over
protection against modified boot files. A modified boot environment can obtain
the disk key; the desktop login password does not prevent that attack. PCR 7
binding alone does not authenticate the kernel or initrd while Secure Boot is
disabled. Do not treat this as equivalent to authenticated boot with TPM unlock.

## Configuration ownership

`hosts/iceflake/default.nix` enables the systemd initrd and TPM support:

```nix
boot.initrd.systemd.enable = true;
boot.initrd.systemd.tpm2.enable = true;
boot.initrd.luks.devices."luks-4b2d6b8c-2939-4c01-8b5c-7ff4cefcc833".crypttabExtraOpts = [
  "tpm2-device=auto"
];
```

`hosts/iceflake/hardware-configuration.nix` declares the encrypted device and
filesystems. Do not edit this generated file manually. The UUID above belongs
to iceflake; do not copy it to another machine.

The Nix configuration installs the unlock support, but TPM enrollment is a
separate, machine-local operation. Its token lives in the LUKS header, not in
Git. No disk passphrase or TPM key belongs in the repository.

## Set up the machine

1. Check the boot security state and available TPM:

   ```bash
   sudo bootctl status
   systemd-cryptenroll --tpm2-device=list
   ```

   This setup used `/dev/tpmrm0` and reported Secure Boot disabled. Confirm that
   you know the existing disk passphrase before changing enrollment.

2. From the repository root, install the configuration for the current host:

   ```bash
   git add -A
   rebuild
   ```

   Use the repository's `rebuild` command. It detects the current hostname.
   Do not substitute a hardcoded host build command.

3. Enroll the TPM once, entering the existing disk passphrase locally:

   ```bash
   sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-uuid/4b2d6b8c-2939-4c01-8b5c-7ff4cefcc833
   ```

   This adds a TPM keyslot without removing the existing passphrase slot.
   Do not repeat enrollment on every rebuild. Do not paste the passphrase into
   chat, shell arguments, scripts, or repository files.

4. Inspect the enrolled token:

   ```bash
   sudo cryptsetup luksDump /dev/disk/by-uuid/4b2d6b8c-2939-4c01-8b5c-7ff4cefcc833
   ```

   The initial setup retained passphrase keyslot 0 and added TPM keyslot 1,
   referenced by a `systemd-tpm2` token. Slot numbers may differ after later
   enrollment changes.

5. Save your work and reboot:

   ```bash
   reboot
   ```

   Verify that boot skips the disk passphrase prompt but SDDM still requires
   your login password. Keep the disk passphrase available during this check.

## Test TPM unlock without rebooting

A token-only passphrase check exercises TPM unsealing without creating another
device mapping or changing the mounted filesystem:

```bash
systemd_store="$(dirname "$(dirname "$(readlink -f /run/current-system/sw/lib/systemd/systemd-cryptsetup)")")"
sudo env LD_LIBRARY_PATH="$systemd_store/lib/cryptsetup" \
  cryptsetup open --test-passphrase --token-only \
  /dev/disk/by-uuid/4b2d6b8c-2939-4c01-8b5c-7ff4cefcc833
```

Exit status 0 means an enrolled token successfully unlocked the disk key.
The library path supplies systemd's TPM token plugin, which the standalone
`cryptsetup` command may otherwise fail to find. This check does not prove that
the next boot's initrd can unlock the disk; the reboot check is still required.

During initial setup, `rebuild` succeeded, the generated initrd crypttab included
`tpm2-device=auto`, and a token-only check passed. Reboot behavior was not yet
verified at that point.

## Recovery and changes

If automatic unlock fails, enter the original disk passphrase at boot. Once
logged in, inspect `sudo cryptsetup luksDump` for the device above and check
`sudo journalctl -b` for TPM and cryptsetup errors. Keep the previous working
NixOS generation available in the boot menu.

Firmware updates, TPM resets, motherboard replacement, or Secure Boot policy
changes can invalidate TPM access. PCR 7 tracks Secure Boot policy. Keep the
passphrase outside this machine and available before making these changes.
Ordinary kernel updates do not change this enrollment's PCR 7 binding, but
boot behavior still depends on the installed initrd and TPM support.

After a policy change, boot using the passphrase and enroll against the new
state using the enrollment command above. Verify the new token before removing
obsolete TPM slots. Never remove the last working passphrase slot. Do not clear
the TPM or wipe LUKS slots as a first troubleshooting step.

To return to passphrase-based boot, remove the `crypttabExtraOpts` TPM setting
from `hosts/iceflake/default.nix`, then run `git add -A && rebuild`. The TPM token
can remain enrolled while unused; removing it is a separate LUKS header change.

Enabling Secure Boot later requires a separate boot-signing and firmware-key
enrollment setup, followed by TPM re-enrollment if PCR 7 changes. Windows boot
entries exist on this machine. Preserve any Windows BitLocker recovery key
before changing firmware security settings.
