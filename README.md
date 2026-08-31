# OpenWrt Proxy Mode Suite

Portable sing-box mode manager for OpenWrt with a LuCI GUI, dynamic modes, IPv6 leak protection, safe configuration validation, and migration-oriented tooling.

> Status: **v0.3 codebase / v1.0 packaging work in progress**. The repository is structured so the runtime core, LuCI UI, protocol templates, migration docs, and future APK/IPK packages can evolve independently.

## What this project contains

- `proxy-mode` runtime wrapper for switching sing-box configurations.
- Dynamic numeric modes (`mode1.json`, `mode2.json`, ... up to 999).
- LuCI page at **Services → Proxy Mode**.
- Add / edit / clone / rename / delete modes.
- Protocol-template creation plus **Custom JSON** fallback.
- `sing-box check` validation before accepting generated or edited configuration.
- IPv6 leak-protection mode that generates `modeN-ipv6-block.json` from the base `modeN.json`.
- Firewall rules that block LAN and router-originated IPv6 when protection is enabled.
- Safe deletion by moving removed modes to `/root/proxy-mode-deleted/`.
- Migration documentation for moving the suite to a new OpenWrt installation.

## Repository layout

```text
.
├── README.md
├── .gitignore
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
├── scripts/
│   ├── install.sh
│   ├── uninstall.sh
│   ├── export-config.sh
│   └── import-config.sh
└── docs/
    ├── ARCHITECTURE.md
    ├── INSTALL.md
    ├── MIGRATION.md
    ├── SECURITY.md
    └── TROUBLESHOOTING.md
```

## Important design rule

The repository contains **software and templates only**. Do not commit real node credentials, UUIDs, passwords, private keys, subscription URLs, complete production `modeN.json` files, or SSH keys.

Base configurations live on the router under `/etc/sing-box/modeN.json`. IPv6-block variants are generated files and should not be edited directly.

## Quick install on a compatible OpenWrt system

Clone or copy this repository to the router, then run:

```sh
chmod +x scripts/install.sh
./scripts/install.sh
```

The installer checks for OpenWrt, LuCI, `sing-box`, `uci`, `jsonfilter`, `rpcd`, and the package manager (`apk` or `opkg`). It backs up files it is about to replace.

After installation open:

**LuCI → Services → Proxy Mode**

See [`docs/INSTALL.md`](docs/INSTALL.md) before using this on a new router.

## Migrating to a new router

The long-term migration model is deliberately split into two pieces:

1. Install the public suite code from this repository.
2. Restore your private runtime data from an export archive.

Use:

```sh
scripts/export-config.sh
```

and on the new router:

```sh
scripts/import-config.sh /tmp/proxy-mode-backup-YYYYMMDD-HHMMSS.tar.gz
```

See [`docs/MIGRATION.md`](docs/MIGRATION.md).

## Known reference environment

The original deployment that this project was generalized from used:

- OpenWrt 25.12.5
- `mediatek/filogic`
- `aarch64_cortex-a53`
- apk-tools 3.x
- LuCI 26.180
- `rpcd-mod-file`
- `uhttpd-mod-ubus`
- sing-box running under procd

The code is intentionally written with POSIX shell and LuCI JS so it can be adapted to other standard OpenWrt targets. Package availability and kernel features can still differ between OpenWrt releases and device builds.

## Safety

- Current mode cannot be deleted from the GUI.
- Invalid JSON is rejected before it replaces a working configuration.
- Successful edits make timestamped backups.
- Deleted modes are moved rather than immediately destroyed.
- Install/import operations back up the previous state before replacing it.
- Keep the repository private if you ever decide to store real configurations here; the recommended approach is to never commit secrets at all.

## Roadmap

- [ ] Split runtime into formal `proxy-mode-core` package.
- [ ] Build `luci-app-proxy-mode` as a proper OpenWrt package.
- [ ] Produce APK package for current OpenWrt releases.
- [ ] Produce IPK package for older OpenWrt releases.
- [ ] Add CI package builds and release artifacts.
- [ ] Add richer protocol forms for Reality, WebSocket, gRPC, Hysteria2 obfs, TUIC and advanced TLS settings.
- [ ] Add GUI-based export/import.

