# OpenWrt Proxy Mode Suite

Portable sing-box mode manager for OpenWrt with a LuCI GUI, dynamic modes, IPv6 leak protection, safe configuration validation, migration tooling, runtime health checks, upstream recovery, and reproducible OpenWrt package builds.

> Status: **v1.0.0 release candidate**. `proxy-mode-core` and `luci-app-proxy-mode` have been successfully built as APK packages with the official OpenWrt 25.12.5 `mediatek/filogic` SDK and installed on a RAX3000M reference router. Core/LuCI installation, saved-mode preservation, IPv6 block state, WWAN recovery, DNS resolution and Internet access have all been exercised on real hardware. Additional mode-switch regression testing remains before the first public Release.

## Ownership boundary

The suite intentionally **does not replace the official OpenWrt sing-box package**.

The official `sing-box` package owns:

- `/usr/bin/sing-box`
- `/etc/init.d/sing-box`
- `/etc/config/sing-box`
- `/etc/sing-box/`

Proxy Mode Suite owns only its management layer:

- `/usr/bin/proxy-mode` (runtime safety wrapper)
- `/usr/libexec/proxy-mode-core` (mode-management core)
- `/etc/config/proxy-mode`
- `/etc/hotplug.d/iface/99-proxy-mode`
- `/usr/libexec/proxy-mode-*`
- LuCI menu / ACL / JavaScript view
- Mode lifecycle, IPv6 policy, validation, export/import

This separation avoids package-file conflicts and lets OpenWrt update sing-box normally.

## Features

- Dynamic numeric modes (`mode1.json`, `mode2.json`, ... up to 999).
- LuCI page at **Services → Proxy Mode**.
- Add / edit / clone / rename / delete modes.
- Custom JSON creation as a permanent fallback for future sing-box protocols.
- `sing-box check` validation before edited/generated configs replace working files.
- IPv6 leak-protection mode generating `modeN-ipv6-block.json` from the base mode.
- Firewall protection for LAN and router-originated IPv6.
- Runtime health output for upstream route and local DNS.
- Wait for configured upstream interface/default route before manual start/restart/switch.
- Interface hotplug recovery when the configured WAN/WWAN becomes ready after boot.
- DNS health check after mode switches with rollback to the previous configuration on failure.
- Automatic synchronization of a simple single-host `route_exclude_address` with the selected mode's first outbound IPv4 server.
- Safe mode deletion by moving files to `/root/proxy-mode-deleted/`.
- Export/import tools for migration to a new OpenWrt installation.
- Standard OpenWrt package definitions for `proxy-mode-core` and `luci-app-proxy-mode`.
- GitHub Actions builds with selectable OpenWrt release, target and subtarget.
- Optional GitHub Release publishing with package files and `SHA256SUMS`.

## RAX3000M runtime findings

The reference router uses a 5 GHz STA uplink (`wwan`) while also serving AP clients. Real-hardware testing exposed two important operational details:

1. **Boot timing:** sing-box may start before the Wi-Fi STA has DHCP/default route. The package now includes an iface hotplug recovery hook and a runtime wrapper that waits for upstream readiness before manual start/restart/switch operations.
2. **Multiple STA profiles:** enabling multiple 5 GHz STA interfaces on the same radio and assigning both to the same `wwan` can leave `wwan` unavailable. On the reference router, keeping the intended uplink enabled and disabling the unused backup STA restored DHCP, DNS and the default route.

The tested working chain was:

```text
5 GHz STA uplink → wwan DHCP → default route → sing-box TUN → DNS hijack → selected mode
```

## Repository layout

```text
.
├── README.md
├── VERSION
├── LICENSE
├── core/
├── luci-app-proxy-mode/
├── package/
│   ├── proxy-mode-core/Makefile
│   └── luci-app-proxy-mode/Makefile
├── scripts/
│   ├── proxy-mode-wrapper.sh
│   ├── 99-proxy-mode
│   ├── prepare-sdk.sh
│   ├── install.sh
│   ├── uninstall.sh
│   ├── export-config.sh
│   └── import-config.sh
├── docs/
└── .github/workflows/build-openwrt-packages.yml
```

## Security rule

This repository should contain **software and templates only**. Do not commit real node credentials, UUIDs, passwords, private keys, subscription URLs, production `modeN.json` files, SSH keys, or locally built APK/IPK binaries into the source tree.

Release binaries belong in **GitHub Releases**, not in `main`.

## Install from release/test packages

The preferred distribution contains two files:

- `proxy-mode-core-*.apk`
- `luci-app-proxy-mode-*.apk`

The target router must already have the official `sing-box` package. For the GUI it must also already have a working LuCI installation with `rpcd` and `uhttpd`.

Copy the packages to the router, for example:

```sh
scp proxy-mode-core-*.apk root@ROUTER_IP:/tmp/
scp luci-app-proxy-mode-*.apk root@ROUTER_IP:/tmp/
```

Officially signed Release packages can be installed normally. During local development, self-built packages may need offline/untrusted flags:

```sh
apk add --no-network --allow-untrusted /tmp/proxy-mode-core-*.apk
apk add --no-network --allow-untrusted /tmp/luci-app-proxy-mode-*.apk
```

After installation:

```sh
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
proxy-mode status
```

Open **LuCI → Services → Proxy Mode**.

Before installing on an important existing router, back up `/etc/sing-box/`, `/etc/config/sing-box` and `/etc/config/proxy-mode`.

## Build locally with the official SDK

Reference SDK:

```text
OpenWrt 25.12.5
Target: mediatek
Subtarget: filogic
Toolchain: GCC 14.3.0 / musl
```

Clone the repository next to your SDK and run:

```sh
cd openwrt-proxy-mode-suite
git pull
sh scripts/prepare-sdk.sh /path/to/sdk

cd /path/to/sdk
make package/proxy-mode-suite/proxy-mode-core/compile V=s -j1
make package/proxy-mode-suite/luci-app-proxy-mode/compile V=s -j1
```

Successful APKs are placed under a path similar to:

```text
bin/packages/aarch64_cortex-a53/base/
```

The current package Makefiles intentionally avoid hard-selecting the full `sing-box` and LuCI dependency trees during SDK package-only builds. Those runtimes are checked on the target router instead.

## Runtime commands

```sh
proxy-mode status
proxy-mode health
proxy-mode recover
proxy-mode <number>
proxy-mode ipv6 block
proxy-mode ipv6 allow
proxy-mode restart
```

`proxy-mode status` now reports both sing-box state and upstream/DNS health. `proxy-mode recover` waits for the configured upstream interface/default route and then regenerates the active IPv6-block variant if needed before restarting the saved mode.

## GitHub Actions and Releases

Open **Actions → Build OpenWrt packages → Run workflow**.

Default reference values:

```text
OpenWrt version: 25.12.5
Target: mediatek
Subtarget: filogic
Release tag: (empty)
```

Leave `release_tag` empty for a test artifact. After a build has been installed and smoke-tested on the reference router, publish a semantic release tag such as `v1.0.0` so users can download the packages from GitHub Releases.

Release assets should include both packages and `SHA256SUMS`.

## Migration

On the old router:

```sh
/usr/libexec/proxy-mode-export
```

On the new router, after installing the suite:

```sh
/usr/libexec/proxy-mode-import /tmp/proxy-mode-backup-YYYYMMDD-HHMMSS.tar.gz
```

## Reference environment

Successfully package-built and runtime-tested with:

- OpenWrt 25.12.5
- `mediatek/filogic`
- `aarch64_cortex-a53`
- RAX3000M
- apk-tools 3.x
- GCC 14.3.0 / musl
- sing-box 1.13.x

Target runtime expects:

- official OpenWrt `sing-box`
- LuCI for the GUI package
- `rpcd`
- `uhttpd`
- `uci`
- `jsonfilter`
- TUN/kernel support required by the selected sing-box mode

## Release checklist

- [x] `proxy-mode-core` builds successfully as APK with the reference SDK.
- [x] `luci-app-proxy-mode` builds successfully as APK with the reference SDK.
- [x] Both APKs install successfully on the RAX3000M reference router.
- [x] Existing saved mode and IPv6-block UCI state survive package installation.
- [x] `proxy-mode status` works after package installation.
- [x] LuCI opens and can invoke the installed management layer.
- [x] WWAN DHCP/default route/DNS recovery was verified on real hardware after correcting the active STA profile.
- [ ] Rebuild and install `proxy-mode-core` r10, then verify hotplug recovery after a cold reboot.
- [ ] Switch between at least two known-good modes and verify DNS-health rollback behavior.
- [ ] IPv6 block/allow toggles and restores correctly after r10 upgrade.
- [ ] Invalid JSON is rejected by `sing-box check`.
- [ ] Current mode cannot be deleted.
- [ ] Export/import is tested with a disposable backup.
- [ ] Release contains package files plus `SHA256SUMS`.
- [ ] No secrets are present in Git history or release assets.

## Remaining roadmap

- [ ] Complete r10 cold-boot/hotplug regression test on RAX3000M.
- [ ] Publish the first tested GitHub Release.
- [ ] Test an older SDK to confirm IPK output.
- [ ] Add richer graphical forms for Reality, WebSocket, gRPC, Hysteria2 obfs, TUIC and advanced TLS.
- [ ] Add GUI-based export/import.
- [ ] Add automated runtime smoke tests where practical.
