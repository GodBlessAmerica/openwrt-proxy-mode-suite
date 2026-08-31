# OpenWrt Proxy Mode Suite

Portable sing-box mode manager for OpenWrt with a LuCI GUI, dynamic modes, IPv6 leak protection, safe configuration validation, migration tooling, and reproducible OpenWrt package builds.

> Status: **v1.0 packaging candidate**. Runtime and LuCI are split into standard OpenWrt packages; CI builds against a selected official OpenWrt SDK and can publish GitHub Releases.

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
- Automatic GitHub Release publishing for version tags or a manual `release_tag`.

## Repository layout

```text
.
├── README.md
├── LICENSE
├── core/
│   ├── etc/config/proxy-mode
│   ├── etc/config/sing-box.example
│   ├── etc/init.d/sing-box
│   └── usr/bin/proxy-mode
├── luci-app-proxy-mode/
│   ├── usr/libexec/proxy-mode-ui
│   ├── usr/share/luci/menu.d/luci-app-proxy-mode.json
│   ├── usr/share/rpcd/acl.d/luci-app-proxy-mode.json
│   └── www/luci-static/resources/view/proxy-mode.js
├── package/
│   ├── proxy-mode-core/Makefile
│   └── luci-app-proxy-mode/Makefile
├── scripts/
│   ├── install.sh
│   ├── uninstall.sh
│   ├── export-config.sh
│   └── import-config.sh
├── docs/
│   ├── ARCHITECTURE.md
│   ├── INSTALL.md
│   ├── MIGRATION.md
│   ├── PACKAGING.md
│   ├── SECURITY.md
│   └── TROUBLESHOOTING.md
└── .github/workflows/build-openwrt-packages.yml
```

## Security rule

This repository should contain **software and templates only**. Do not commit real node credentials, UUIDs, passwords, private keys, subscription URLs, production `modeN.json` files, or SSH keys.

Base configurations live on the router under `/etc/sing-box/modeN.json`. Generated IPv6-block variants must not be edited directly.

## Install from source

On a compatible OpenWrt system with sing-box and LuCI already installed:

```sh
chmod +x scripts/install.sh
./scripts/install.sh
```

The source installer backs up files it is about to replace.

See [`docs/INSTALL.md`](docs/INSTALL.md).

## Install from packages

GitHub Actions builds two packages:

- `proxy-mode-core`
- `luci-app-proxy-mode`

On newer OpenWrt releases using APK, installation will look like:

```sh
apk add ./proxy-mode-core_*.apk
apk add ./luci-app-proxy-mode_*.apk
```

On older OpenWrt releases using OPKG:

```sh
opkg install ./proxy-mode-core_*.ipk
opkg install ./luci-app-proxy-mode_*.ipk
```

The exact output format and filename are controlled by the selected OpenWrt SDK.

## Build packages in GitHub Actions

Open **Actions → Build OpenWrt packages → Run workflow**.

Default reference values:

```text
OpenWrt version: 25.12.5
Target: mediatek
Subtarget: filogic
Release tag: (empty)
```

Leaving `release_tag` empty builds an Actions artifact only.

To publish a release, enter for example:

```text
release_tag: v1.0.0
```

The workflow builds both packages, generates `SHA256SUMS`, creates the GitHub Release if needed, and uploads the package files.

See [`docs/PACKAGING.md`](docs/PACKAGING.md).

## Migration

On the old router:

```sh
scripts/export-config.sh
```

On the new router, after installing the suite:

```sh
scripts/import-config.sh /tmp/proxy-mode-backup-YYYYMMDD-HHMMSS.tar.gz
```

See [`docs/MIGRATION.md`](docs/MIGRATION.md).

## Reference environment

The project was generalized from a working installation using:

- OpenWrt 25.12.5
- `mediatek/filogic`
- `aarch64_cortex-a53`
- apk-tools 3.x
- LuCI 26.180
- `rpcd-mod-file`
- `uhttpd-mod-ubus`
- sing-box managed by procd

The suite code itself is POSIX shell, UCI and LuCI JavaScript and is packaged as architecture independent. The sing-box package remains an architecture-specific external dependency supplied by the selected OpenWrt feed.

## Release checklist

Before calling a build stable:

- `proxy-mode status` works.
- Switching between known-good modes works.
- IPv6 block/allow works and restores correctly.
- LuCI opens without JS/RPC errors.
- Invalid JSON is rejected.
- Current mode cannot be deleted.
- Export/import is tested on disposable data.
- CI successfully produces package files.
- No secrets are present in Git history.

## Remaining roadmap

- [ ] Confirm first successful APK build on OpenWrt 25.12.5 / mediatek / filogic.
- [ ] Test package installation on a disposable OpenWrt device/container.
- [ ] Test an older SDK to confirm IPK output.
- [ ] Add richer graphical forms for Reality, WebSocket, gRPC, Hysteria2 obfs, TUIC and advanced TLS.
- [ ] Add GUI-based export/import.
- [ ] Add automated runtime smoke tests where practical.
