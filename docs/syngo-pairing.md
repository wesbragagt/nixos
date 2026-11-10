# Pair Syngo devices

Use this guide to sync `~/p2p` between two devices on your Tailscale network.
Run each pairing and folder-grant command on both devices. Pairing alone does not grant access to files.

## 1. Enable the service on both devices

On Linux hosts managed by this repository, add this line under `features:` in `/etc/nixos/features.yaml`, preserving the other flags:

```yaml
features:
  syngo: true
```

Apply the configuration from the repository:

```bash
git add -A
rebuild
systemctl --user status syngo --no-pager
syngo status --json
```

The configuration installs Syngo from the public `wesbragagt/syngo` repository on GitHub. Fetching the source does not require an SSH key.
It initializes an identity under `~/.local/share/syngo`, creates `~/p2p`, and registers that directory with folder ID `p2p`.
The service binds TCP port 22001 on `tailscale0`. Port 22000 remains available for existing Syngo instances.

Both devices must be connected to Tailscale. Tailnet access rules and host firewalls must allow TCP 22001 between them. Do not expose this port to the public internet.

Existing files in `~/p2p` remain in place. The default folder mode is `sendreceive` and the delete policy is `propagate`, so edits and deletions can reach the other device once access is granted. Back up files you cannot replace before pairing.

## 2. Exchange addresses and device IDs

On each device, run:

```bash
tailscale ip -4
syngo status --json
```

Record the Tailscale IPv4 address and `device.id` for each device. Verify `daemon.running` is `true` and `daemon.listener.address` ends in `:22001`.
Exchange the IDs through a trusted channel. Do not copy identity keys or the Syngo data directory between devices. Each device needs its own identity.

Commands below use the default Syngo data directory. If you also run a notes-sync instance, do not pass its `--data-dir` or export its `SYNGO_DATA_DIR` for these commands.

## 3. Pair and grant access in both directions

On device A, replace the values with device B's address and ID:

```bash
syngo peer add DEVICE_B_TAILSCALE_IP:22001 --device-id DEVICE_B_ID
syngo folder grant p2p DEVICE_B_ID
```

On device B, replace the values with device A's address and ID:

```bash
syngo peer add DEVICE_A_TAILSCALE_IP:22001 --device-id DEVICE_A_ID
syngo folder grant p2p DEVICE_A_ID
```

`--device-id` pins the expected identity. Syngo refuses a device that presents another ID.
Both devices must use folder ID `p2p`, know each other as peers, and grant each other access to that folder.

## 4. Verify a file transfers

On device A, create a new file with a unique name:

```bash
probe="$(mktemp "$HOME/p2p/pairing-check.XXXXXX")"
printf 'Syngo pairing check\n' > "$probe"
printf 'Check this file on device B: %s\n' "$(basename "$probe")"
syngo status
```

On device B, read that filename under `~/p2p` after synchronization. Repeat with a different new file on device B and check it on device A.
Delete the probe files when finished. With the default delete policy, those deletions also propagate.

## Troubleshooting

Inspect the service and current configuration:

```bash
systemctl --user status syngo --no-pager
journalctl --user -u syngo -n 50 --no-pager
syngo peer list
syngo folder list
syngo folder devices p2p
syngo status --json
```

- Connection refused or unreachable: verify the remote service is running, both devices are on Tailscale, and TCP 22001 is allowed.
- Identity mismatch: compare the remote `device.id` through your trusted channel. Do not bypass the check with an unverified ID.
- Connected but no files: verify both devices use folder ID `p2p` and each lists the other under `syngo folder devices p2p`. Hidden files and symlinks are skipped by default.
- Address already in use: inspect `sudo ss -ltnp 'sport = :22001'` before changing or stopping another service.
- Setup fails on a folder conflict: inspect `syngo folder list`. The module does not replace an existing folder ID or path that conflicts with `p2p`.

To revoke one device's access without deleting local files:

```bash
syngo folder revoke p2p PEER_DEVICE_ID
```

Revocation does not remove copies already stored on the other device.
