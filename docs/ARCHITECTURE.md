# Architecture

## Layers

### 1. sing-box runtime

`/usr/bin/sing-box` is supplied by the OpenWrt package ecosystem or another trusted installation method. This repository does not bundle the binary so the project is not tied to one CPU architecture.

### 2. proxy-mode core

`core/usr/bin/proxy-mode` is the control plane. It owns:

- active mode selection;
- `sing-box check` before activation;
- IPv6 allow/block state;
- generation of `modeN-ipv6-block.json`;
- firewall synchronization;
- restart and rollback behavior;
- status and logs.

The CLI and LuCI intentionally use the same core logic so there is no separate GUI-only networking implementation.

### 3. Mode registry

`/etc/config/proxy-mode` stores human-readable metadata such as Mode names. The actual sing-box configuration remains in `/etc/sing-box/modeN.json`.

Mode IDs are numeric, 1..999. `modeN-ipv6-block.json` is derived data and should never be treated as the authoritative configuration.

### 4. LuCI UI

The UI consists of:

- `menu.d` registration;
- rpcd ACL;
- `/usr/libexec/proxy-mode-ui` safe filesystem/config manager;
- LuCI JavaScript view.

The backend validates IDs, validates sing-box JSON, creates timestamped backups on edits, prevents deletion of the active mode, and moves deleted modes to `/root/proxy-mode-deleted/`.

## Protocol extensibility

The core does not need to know whether a mode uses VLESS, VMess, Trojan, Hysteria2, TUIC, SOCKS, HTTP or a future sing-box outbound protocol. A mode is ultimately a complete sing-box JSON document.

This is the compatibility escape hatch: even when the GUI has no dedicated form for a new protocol, Custom JSON can still create a mode as long as the installed sing-box version accepts it.

Protocol-specific GUI templates should be treated as conveniences, not as the source of truth.

## IPv6 protection

When `sing-box.main.ipv6_mode=block`, `proxy-mode` derives an IPv6-block variant from the base mode, verifies it with `sing-box check`, and also adds OpenWrt firewall rules that reject IPv6 from LAN to WAN and from the router itself to WAN.

This is deliberately defense-in-depth: sing-box routing rules alone are not assumed to be sufficient to prevent a non-proxied IPv6 path.

## Packaging direction

The intended v1.0 package split is:

```text
proxy-mode-core          portable shell/UCI/procd runtime
luci-app-proxy-mode      mostly noarch LuCI application
sing-box                 external architecture-specific dependency
proxy-mode-suite         optional meta-package depending on the above
```

Modern OpenWrt can use APK packages; older releases may require IPK. The source tree stays package-manager-neutral so packaging can be generated per release.
