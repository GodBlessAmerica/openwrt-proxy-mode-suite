# OpenWrt Proxy Mode Suite

Portable sing-box mode manager for OpenWrt with a LuCI GUI, dynamic modes, IPv6 leak protection, safe configuration validation, migration tooling, and reproducible OpenWrt package builds.

> Status: **v1.0.0 release candidate**. Both `proxy-mode-core` and `luci-app-proxy-mode` have been successfully built as APK packages with the official OpenWrt 25.12.5 `mediatek/filogic` SDK. Router installation and runtime smoke testing remain the final release gate.

## Ownership boundary

The suite intentionally **does not replace the official OpenWrt sing-box package**.

The official `sing-box` package owns:

- `/usr/bin/sing-box`
- `/etc/init.d/sing-box`
- `/etc/config/sing-box`
- `/etc/sing-box/`

Proxy Mode Suite owns only its management layer:

- `/usr/bin/proxy-mode`
- `/etc/config/proxy-mode`
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
- Safe mode deletion by moving files to `/root/proxy-mode-deleted/`.
- Export/import tools for migration to a new OpenWrt installation.
- Standard OpenWrt package definitions for `proxy-mode-core` and `luci-app-proxy-mode`.
- GitHub Actions builds with selectable OpenWrt release, target and subtarget.
- Optional GitHub Release publishing with package files and `SHA256SUMS`.

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

## Install from release packages

The preferred distribution contains two files:

- `proxy-mode-core-*.apk`
- `luci-app-proxy-mode-*.apk`

The target router must already have the official `sing-box` package. For the GUI it must also already have a working LuCI installation with `rpcd` and `uhttpd`.

Copy the packages to the router, for example:

```sh
scp proxy-mode-core-*.apk root@ROUTER_IP:/tmp/
scp luci-app-proxy-mode-*.apk root@ROUTER_IP:/tmp/
```

Then install core first and GUI second:

```sh
apk add /tmp/proxy-mode-core-*.apk
apk add /tmp/luci-app-proxy-mode-*.apk
```

After installation:

```sh
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
proxy-mode status
```

Open **LuCI → Services → Proxy Mode**.

Before installing on an important existing router, back up `/etc/sing-box/` and `/etc/config/sing-box` or use the included export tool.

See [`docs/INSTALL.md`](docs/INSTALL.md).

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

Release assets should include both packages and `SHA256SUMS`. Verify them after download with:

```sh
sha256sum -c SHA256SUMS
```

See [`docs/PACKAGING.md`](docs/PACKAGING.md).

## Migration

On the old router:

```sh
/usr/libexec/proxy-mode-export
```

On the new router, after installing the suite:

```sh
/usr/libexec/proxy-mode-import /tmp/proxy-mode-backup-YYYYMMDD-HHMMSS.tar.gz
```

See [`docs/MIGRATION.md`](docs/MIGRATION.md).

## Reference environment

Successfully package-built with:

- OpenWrt 25.12.5
- `mediatek/filogic`
- `aarch64_cortex-a53`
- apk-tools 3.x
- GCC 14.3.0 / musl

Target runtime expects:

- official OpenWrt `sing-box`
- LuCI for the GUI package
- `rpcd`
- `uhttpd`
- `uci`
- `jsonfilter`
- TUN/kernel support required by the selected sing-box mode

## Release checklist

Before calling the build stable:

- [x] `proxy-mode-core` builds successfully as APK with the reference SDK.
- [x] `luci-app-proxy-mode` builds successfully as APK with the reference SDK.
- [ ] Both APKs install successfully on the reference router.
- [ ] `proxy-mode status` works after package installation.
- [ ] Switching at least two known-good modes succeeds.
- [ ] IPv6 block/allow toggles and restores correctly.
- [ ] LuCI opens without JavaScript or RPC errors.
- [ ] Invalid JSON is rejected by `sing-box check`.
- [ ] Current mode cannot be deleted.
- [ ] Export/import is tested with a disposable backup.
- [ ] Release contains package files plus `SHA256SUMS`.
- [ ] No secrets are present in Git history or release assets.

## Remaining roadmap

- [ ] Complete RAX3000M runtime smoke test.
- [ ] Publish the first tested GitHub Release.
- [ ] Test an older SDK to confirm IPK output.
- [ ] Add richer graphical forms for Reality, WebSocket, gRPC, Hysteria2 obfs, TUIC and advanced TLS.
- [ ] Add GUI-based export/import.
- [ ] Add automated runtime smoke tests where practical.
