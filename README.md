# OpenWrt Proxy Mode Suite

Portable sing-box mode manager for OpenWrt with a LuCI GUI, dynamic modes, IPv6 leak protection, safe validation/rollback, upstream recovery, migration tools and reproducible OpenWrt package builds.

> Current version: **v1.0.0-rc2**. Reference build/runtime validation is OpenWrt 25.12.5 on `mediatek/filogic` with a RAX3000M reference router.

## What it does

- Manage numeric sing-box modes such as `mode1.json`, `mode2.json`, ...
- Switch modes from CLI or LuCI.
- Add, clone, edit, rename and delete modes from **LuCI → Services → Proxy Mode**.
- Validate configuration with `sing-box check` before replacing a working file.
- Generate `modeN-ipv6-block.json` variants for IPv6 leak protection.
- Block IPv6 from LAN clients and router-originated traffic when protection is enabled.
- Wait for WAN/WWAN/default-route readiness before start/restart/switch.
- Recover automatically when the configured upstream interface comes up after boot.
- Test local DNS after a mode switch and roll back when the new mode fails health checks.
- Export/import configuration when migrating to another OpenWrt router.

## Ownership boundary

The suite **does not replace the official OpenWrt sing-box package**.

Official `sing-box` owns:

```text
/usr/bin/sing-box
/etc/init.d/sing-box
/etc/config/sing-box
/etc/sing-box/
```

Proxy Mode Suite owns its management layer:

```text
/usr/bin/proxy-mode
/usr/libexec/proxy-mode-core
/usr/libexec/proxy-mode-export
/usr/libexec/proxy-mode-import
/etc/config/proxy-mode
/etc/hotplug.d/iface/99-proxy-mode
LuCI menu / ACL / JavaScript view
```

This separation avoids package-file conflicts and lets OpenWrt update sing-box normally.

## rc2 changes

- New LuCI status dashboard with clear service, current-mode and IPv6/DNS health indicators.
- Browser-side cache troubleshooting documented for LuCI upgrades.
- Source installer now preserves the **actually running valid sing-box config** first during reinstall.
- `proxy-mode-core` package post-install logic now follows the same preservation rule.
- Fresh routers with no valid mode remain unconfigured instead of inventing a default proxy mode.
- Expanded installation and day-to-day usage documentation.

Package revisions for rc2:

```text
proxy-mode-core-1.0.0-r11.apk
luci-app-proxy-mode-1.0.0-r6.apk
```

## Install

The preferred method is to download the two APKs plus `SHA256SUMS` from GitHub Releases.

The router must already have the official OpenWrt `sing-box` package. The GUI additionally requires LuCI, `rpcd` and `uhttpd`.

Install:

```sh
apk add /tmp/proxy-mode-core-*.apk
apk add /tmp/luci-app-proxy-mode-*.apk
```

Then verify:

```sh
proxy-mode status
proxy-mode health
```

Open:

**LuCI → Services → Proxy Mode**

Detailed instructions: [`docs/INSTALL.md`](docs/INSTALL.md)

## Use

Common commands:

```sh
proxy-mode status
proxy-mode health
proxy-mode recover
proxy-mode <number>
proxy-mode ipv6 block
proxy-mode ipv6 allow
proxy-mode start
proxy-mode restart
proxy-mode stop
```

Example, switch to mode 6:

```sh
proxy-mode 6
```

Detailed guide: [`docs/USAGE.md`](docs/USAGE.md)

## Fresh-router behavior

The repository intentionally contains no real production `modeN.json` files because those files often contain private server information and credentials.

On a fresh router:

1. if a valid sing-box config is already running, reinstall preserves it;
2. otherwise a valid saved `sing-box.main.conffile` is preserved;
3. otherwise a valid `/etc/sing-box/mode1.json` may be used as the initial mode;
4. if none exists, Proxy Mode remains unconfigured until you add a mode.

## Existing-router reinstall behavior

rc2 prioritizes the configuration actually used by the running sing-box process. This avoids a reinstall changing UCI to an older mode while sing-box continues running a different one.

You can compare saved and actual runtime state with:

```sh
uci -q get sing-box.main.conffile
pgrep -af sing-box
```

## IPv6 leak protection

Enable:

```sh
proxy-mode ipv6 block
```

Disable:

```sh
proxy-mode ipv6 allow
```

When enabled, the status page/CLI reports firewall state, DNS strategy and sing-box IPv6 reject-rule health.

## WWAN recovery

The reference RAX3000M uses a 5 GHz STA uplink (`wwan`). Real-hardware testing showed sing-box can start before Wi-Fi STA DHCP/default-route readiness. The suite includes an iface hotplug recovery hook and runtime readiness checks.

Useful diagnostics:

```sh
ubus call network.interface.wwan status
ip -4 route
nslookup www.google.com 127.0.0.1
proxy-mode status
```

If multiple STA profiles are assigned to the same `wwan`, test carefully; on the reference router, two enabled 5 GHz STA profiles on the same radio caused `wwan` to remain unavailable.

## Source installation

For development/recovery using the latest `main`:

```sh
cd /tmp
wget -O proxy-mode-suite.tar.gz \
  https://github.com/GodBlessAmerica/openwrt-proxy-mode-suite/archive/refs/heads/main.tar.gz

tar -xzf proxy-mode-suite.tar.gz
mv openwrt-proxy-mode-suite-main openwrt-proxy-mode-suite
cd openwrt-proxy-mode-suite
sh scripts/install.sh
```

If the router needs its current proxy to reach GitHub, download the new source **before** stopping/replacing the current proxy management layer.

## Build locally

Reference SDK:

```text
OpenWrt 25.12.5
Target: mediatek
Subtarget: filogic
Toolchain: GCC 14.3.0 / musl
```

Build:

```sh
sh scripts/prepare-sdk.sh /path/to/sdk
cd /path/to/sdk
make package/proxy-mode-suite/proxy-mode-core/compile V=s -j1
make package/proxy-mode-suite/luci-app-proxy-mode/compile V=s -j1
```

See [`docs/PACKAGING.md`](docs/PACKAGING.md).

## Migration

Export on the old router:

```sh
/usr/libexec/proxy-mode-export
```

Import on the new router after installation:

```sh
/usr/libexec/proxy-mode-import /tmp/proxy-mode-backup-YYYYMMDD-HHMMSS.tar.gz
```

See [`docs/MIGRATION.md`](docs/MIGRATION.md).

## Security

This repository should contain **software and templates only**. Do not commit or publish:

- production `modeN.json` files
- node/server credentials
- UUIDs or passwords
- private keys / short IDs
- subscription URLs
- SSH keys
- access tokens
- exported production configuration archives

Release binaries belong in GitHub Releases rather than the source tree.

See [`docs/SECURITY.md`](docs/SECURITY.md).

## Repository layout

```text
.
├── README.md
├── VERSION
├── core/
├── luci-app-proxy-mode/
├── package/
├── scripts/
├── docs/
│   ├── INSTALL.md
│   ├── USAGE.md
│   ├── MIGRATION.md
│   ├── PACKAGING.md
│   ├── ARCHITECTURE.md
│   └── SECURITY.md
└── .github/workflows/
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

## License

MIT
