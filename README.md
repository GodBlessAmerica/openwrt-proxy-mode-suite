# OpenWrt Proxy Mode Suite

Portable sing-box mode manager for OpenWrt with a LuCI GUI, dynamic modes, IPv6 leak protection, safe validation/rollback, upstream recovery, migration tools and reproducible OpenWrt package builds.

> Current version: **v1.0.0-rc3**. Reference validation: OpenWrt 25.12.5 on `mediatek/filogic` with a CMCC RAX3000M and sing-box 1.13.18.

## Quick Start

Install the official OpenWrt sing-box package first:

```sh
apk update
apk add sing-box
```

Download the current rc3 Release packages:

```sh
cd /tmp
wget -4 -T 60 -O proxy-mode-core-1.0.0-r13.apk \
  https://github.com/GodBlessAmerica/openwrt-proxy-mode-suite/releases/download/v1.0.0-rc3/proxy-mode-core-1.0.0-r13.apk
wget -4 -T 60 -O luci-app-proxy-mode-1.0.0-r7.apk \
  https://github.com/GodBlessAmerica/openwrt-proxy-mode-suite/releases/download/v1.0.0-rc3/luci-app-proxy-mode-1.0.0-r7.apk
wget -4 -T 60 -O SHA256SUMS \
  https://github.com/GodBlessAmerica/openwrt-proxy-mode-suite/releases/download/v1.0.0-rc3/SHA256SUMS
sha256sum -c SHA256SUMS
```

`-4` forces IPv4 and `-T 60` gives GitHub/Release CDN connections more time on routers with slow or inconsistent HTTPS setup. If a first download attempt times out, retry the same command.

Install the verified packages:

```sh
apk add --allow-untrusted /tmp/proxy-mode-core-1.0.0-r13.apk
apk add --allow-untrusted /tmp/luci-app-proxy-mode-1.0.0-r7.apk
```

`--allow-untrusted` is required because the Release APKs are not signed by an OpenWrt repository key. Only use it for packages downloaded from this project's Release page and verified with `SHA256SUMS`.

Verify:

```sh
proxy-mode status
```

Then open:

**LuCI → Services → Proxy Mode**

On a fresh router, click **Add Mode**, enter a Mode Number such as `6`, choose **Custom JSON**, paste a complete known-good sing-box configuration, create it, then switch to it.

CLI example:

```sh
sing-box check -c /etc/sing-box/mode6.json
proxy-mode 6
```

## Highlights

- Manage numeric sing-box modes such as `mode1.json`, `mode6.json`, ...
- Add, clone, edit, rename, delete and switch modes from LuCI.
- LuCI **Add Mode** supports an explicit numeric Mode ID (1-999).
- Fresh routers with no managed mode remain **unconfigured** instead of inventing a default mode.
- First activation automatically enables the official sing-box service configuration.
- Validate configurations with `sing-box check` before replacing a working file.
- Generate `modeN-ipv6-block.json` variants for IPv6 leak protection.
- Block IPv6 from LAN clients and router-originated traffic when protection is enabled.
- Wait for WAN/WWAN/default-route readiness before start/restart/switch.
- Recover automatically when the configured upstream interface comes up after boot.
- Serialize hotplug recovery to avoid duplicate restart races.
- Test local DNS after a mode switch and roll back when the new mode fails health checks.
- Export/import configuration when migrating to another OpenWrt router.

## Ownership boundary

The suite does **not** replace the official OpenWrt sing-box package.

Official sing-box owns:

```text
/usr/bin/sing-box
/etc/init.d/sing-box
/etc/config/sing-box
/etc/sing-box/
```

Proxy Mode Suite owns:

```text
/usr/bin/proxy-mode
/usr/bin/proxy-mode-preflight
/usr/libexec/proxy-mode-core
/usr/libexec/proxy-mode-export
/usr/libexec/proxy-mode-import
/usr/libexec/proxy-mode-ui
/etc/config/proxy-mode
/etc/hotplug.d/iface/99-proxy-mode
LuCI menu / ACL / JavaScript view
```

The official init script remains intact, but Proxy Mode disables unconditional `rc.d` autostart so sing-box does not race ahead of WWAN/DHCP/default-route readiness. Proxy Mode starts/restarts it only after the required upstream is ready.

## rc3 changes

- Fixed fresh-install source installer so all management components are installed.
- Removed placeholder `Example Mode 1` behavior.
- Fresh install now ignores the official default `/etc/sing-box/config.json` and stays unconfigured until a real managed mode exists.
- Added explicit Mode Number creation in LuCI (`mode6.json` really means mode 6).
- Zero-mode LuCI now defaults to **Custom JSON**.
- Fixed first managed-mode activation when `sing-box.main.enabled='0'`.
- Added boot sequencing ownership: unconditional sing-box `rc.d` autostart is disabled.
- Added serialized WWAN hotplug recovery to prevent duplicate recovery races.
- Improved zero-mode wording (`未配置` instead of `未知模式`).
- Fresh-router validation completed on OpenWrt 25.12.5 / RAX3000M with 5 GHz STA uplink `wwan`.

Package revisions for rc3:

```text
proxy-mode-core-1.0.0-r13.apk
luci-app-proxy-mode-1.0.0-r7.apk
```

## Fresh-router behavior

The repository intentionally contains no production `modeN.json` files because they commonly contain private server addresses and credentials.

After installation on a fresh router with no managed modes, expected status is:

```text
当前模式：未配置
配置文件：未设置
运行状态：已停止
```

The official default `/etc/sing-box/config.json` is not treated as a Proxy Mode mode.

## First mode on a fresh router

In LuCI:

1. Open **Services → Proxy Mode**.
2. Click **Add Mode**.
3. Enter the numeric Mode ID, for example `6`.
4. Choose **Custom JSON**.
5. Enter a name such as `Mode 6`.
6. Paste a complete known-good sing-box configuration.
7. Create the mode.
8. Switch/start it after validation.

A Mode Number of `6` creates `/etc/sing-box/mode6.json`.

## Optional upstream-interface pinning

Normal switching and proxy operation only require a usable IPv4 default route. Setting `sing-box.main.ifaces` is **not required for basic proxy use**.

For routers using a known WAN/WWAN interface, pinning it is recommended because it makes boot and reconnect recovery more precise. Example for a Wi-Fi STA uplink named `wwan`:

```sh
uci set sing-box.main.ifaces='wwan'
uci commit sing-box
```

With this setting, Proxy Mode waits for that interface plus an IPv4 default route before recovery. Without it, recovery falls back to default-route readiness.

## WWAN recovery

At boot, sing-box is not allowed to start unconditionally before the upstream is ready. When the configured upstream comes up, `/etc/hotplug.d/iface/99-proxy-mode` schedules serialized recovery.

Useful diagnostics:

```sh
ubus call network.interface.wwan status
ip -4 route
proxy-mode status
pgrep -af sing-box
cat /tmp/proxy-mode-recover.log 2>/dev/null
logread | grep -Ei 'proxy-mode|sing-box|wwan' | tail -100
```

If multiple STA profiles are assigned to the same radio/interface, test carefully. On the reference RAX3000M, multiple enabled 5 GHz STA profiles on the same `wwan` caused availability problems.

## IPv6 leak protection

Block IPv6:

```sh
proxy-mode ipv6 block
```

Allow IPv6 again:

```sh
proxy-mode ipv6 allow
```

Check status with:

```sh
proxy-mode status
```

## Source installation

For development/recovery using the latest `main`:

```sh
cd /tmp
rm -rf openwrt-proxy-mode-suite openwrt-proxy-mode-suite-main proxy-mode-suite.tar.gz
wget -O proxy-mode-suite.tar.gz \
  https://github.com/GodBlessAmerica/openwrt-proxy-mode-suite/archive/refs/heads/main.tar.gz

tar -xzf proxy-mode-suite.tar.gz
mv openwrt-proxy-mode-suite-main openwrt-proxy-mode-suite
cd openwrt-proxy-mode-suite
sh scripts/install.sh
```

For normal users, the tested Release APKs are preferred over `main` source installation.

## Common commands

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

## Security

Do not publish real `modeN.json` files or export archives. They may contain server addresses, UUIDs, passwords, private keys, short IDs, subscription URLs or other credentials.

See also:

- [`docs/INSTALL.md`](docs/INSTALL.md)
- [`docs/USAGE.md`](docs/USAGE.md)
- [`docs/PACKAGING.md`](docs/PACKAGING.md)
- [`docs/MIGRATION.md`](docs/MIGRATION.md)
