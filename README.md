# OpenWrt Proxy Mode Suite

Portable sing-box mode manager for OpenWrt with a LuCI GUI, dynamic modes, IPv6 leak protection, safe validation/rollback, upstream recovery, migration tools and reproducible OpenWrt package builds.

> Current version: **v1.1.1 release candidate**. Reference environment: OpenWrt 25.12.5 on mediatek/filogic (RAX3000M), sing-box 1.13.18. The operator confirmed basic IPv6 upstream operation and working hostname-based A-B proxy operation on the RAX3000M. v1.1.1 adds independent bootstrap DNS for eligible single-hop and two-hop IPv4 hostname VLESS profiles, including legacy mode migration and compatibility with jq builds without Oniguruma. Full IPv4 regression, UDP end-to-end, reboot/reconnect and leak testing remain pending.

## 一键安装 / 升级

For an existing compatible installation or a fresh APK-based OpenWrt router, connect by trusted LAN SSH as root, review the installer, and run:

```sh
curl -fL -o /tmp/proxy-mode-install.sh https://raw.githubusercontent.com/GodBlessAmerica/openwrt-proxy-mode-suite/main/install.sh
sh /tmp/proxy-mode-install.sh
```

The source installer installs missing official dependencies (including sing-box and LuCI), backs up existing suite files, preserves existing mode JSON and settings, and installs the IPv6 guard and watchdog. It does not flash firmware. Existing managed modes are preserved; a fresh installation without a managed mode stays unconfigured. RPC/LuCI services are restarted; keep LAN SSH available. This unified source entry point has not yet received separate fresh-device verification. Do not mix source upgrades with APK package management without considering file ownership.

For reproducible APKs, see the [v1.1.1 candidate release](https://github.com/GodBlessAmerica/openwrt-proxy-mode-suite/releases/tag/v1.1.1) (build completed successfully). Verify SHA256SUMS before installing; the official sing-box package must be installed first.

## Automatic DNS bootstrap (v1.1.1)

For eligible single-hop or A-B VLESS configurations with an IPv4-resolvable first-hop hostname, one proxied HTTPS DNS server and no custom resolver/rules, the suite adds direct AliDNS HTTPS bootstrap (223.5.5.5, TLS dns.alidns.com), sets the first-hop and default domain resolvers, and keeps ordinary DNS on the existing proxied DoH. A-B detour is preserved. New/edited profiles and legacy modes prepared during switching/start/restart/recovery are normalized. A singleton IPv4 /32 TUN exclusion is treated as legacy and removed on eligible profiles; multiple exclusions are preserved. Literal addresses and custom resolvers are not automatically rewritten. AAAA-only first-hop hostnames are not supported by this normalization. Bootstrap and other default-resolver lookups can leave directly; this is not a zero-leak guarantee. Configuration validation and offline regression are not substitutes for device testing.

## IPv6 upstream

A supported profile has a literal IPv6 VLESS first outbound and an IPv4-only TUN with auto_route and auto_redirect enabled. The router must already have a working IPv6 WAN/WWAN route; this suite does not provision WAN6. The IPv6 upstream path sets DNS strategy to ipv4_only if needed, installs an independent IPv6 guard, permits the configured upstream TCP endpoint, and reconciles missing sing-box nftables exceptions using a watchdog. This is not dual-stack LAN interception. Existing IPv4 profiles retain the original switching path. Use the existing allow policy for this IPv6 upstream mode; the independent guard still blocks forwarded IPv6. The temporary interactive ipv6-test command is intended for diagnostics, not ordinary mode switching.

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
sh scripts/test-dns-bootstrap.sh
sh scripts/install.sh
```

The unified source installer above is the current source installation entry; historical rc3 APKs remain available for recovery.

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
