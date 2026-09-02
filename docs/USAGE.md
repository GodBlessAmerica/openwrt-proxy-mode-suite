# Usage Guide

## Open the LuCI page

Open **LuCI → Services → Proxy Mode**.

The dashboard shows service state, current mode, active config path, IPv6 leak protection, firewall/DNS health, configured modes and recent logs.

If the page looks stale after an upgrade, hard-refresh or use a private/incognito window.

## Quick reference

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

## Fresh router

With no managed `modeN.json`, rc3 reports:

```text
当前模式：未配置
配置文件：未设置
运行状态：已停止
```

The official default `/etc/sing-box/config.json` is not treated as a Proxy Mode configuration.

## Add a mode in LuCI

In **Mode Manager**:

1. Click **Add Mode**.
2. Enter an explicit **Mode Number** from 1 to 999.
3. Use **Custom JSON** for a new configuration, or clone an existing mode.
4. Enter a descriptive name.
5. Create the mode.

Example: Mode Number `6` creates `/etc/sing-box/mode6.json`.

The backend validates custom JSON with `sing-box check` before creating the file.

## Switch mode

```sh
proxy-mode 6
```

The wrapper waits for the configured upstream/default route, enables sing-box when activating the first real managed mode, starts the candidate, checks DNS and rolls back when appropriate.

## Restart current mode

```sh
proxy-mode restart
```

## WWAN recovery

Configure the upstream interface:

```sh
uci set sing-box.main.ifaces='wwan'
uci commit sing-box
```

Proxy Mode disables unconditional sing-box rc.d autostart. After boot, the selected mode is started only after the configured upstream is ready.

When `wwan` comes up, the hotplug hook schedules serialized recovery. Duplicate triggers are skipped while a recovery is already running.

Diagnostics:

```sh
ubus call network.interface.wwan status
ip -4 route
proxy-mode status
pgrep -af sing-box
cat /tmp/proxy-mode-recover.log 2>/dev/null
logread | grep -Ei 'proxy-mode|sing-box|wwan' | tail -100
```

## IPv6 leak protection

Block IPv6:

```sh
proxy-mode ipv6 block
```

Allow it again:

```sh
proxy-mode ipv6 allow
```

When protection is active, Proxy Mode generates a `modeN-ipv6-block.json` variant and reports firewall, DNS-strategy and sing-box IPv6-rule health.

Edit the base `modeN.json`, not the generated protected variant.

Validate manually:

```sh
sing-box check -c /etc/sing-box/mode6.json
```

## Mode files

```text
/etc/sing-box/mode1.json
/etc/sing-box/mode6.json
/etc/sing-box/mode6-ipv6-block.json
```

Names are stored in `/etc/config/proxy-mode`; the numeric ID controls the filename and switching command.

## Export/import

Export:

```sh
/usr/libexec/proxy-mode-export
```

Import:

```sh
/usr/libexec/proxy-mode-import /tmp/proxy-mode-backup-YYYYMMDD-HHMMSS.tar.gz
```

## Security

Do not publish real mode files or export archives. They may contain server addresses, UUIDs, passwords, private keys, short IDs, subscription URLs or other credentials.
