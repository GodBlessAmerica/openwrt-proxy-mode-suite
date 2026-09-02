# Usage Guide

This guide covers day-to-day use after OpenWrt Proxy Mode Suite is installed.

## Open the LuCI page

Open:

**LuCI → Services → Proxy Mode**

The dashboard shows:

- sing-box service state
- current mode
- active configuration path
- IPv6 leak-protection state
- IPv6 firewall state
- DNS strategy
- sing-box IPv6 reject-rule state
- configured modes
- recent log output

If the page still looks like an older version after an upgrade, hard-refresh the browser (`Ctrl+Shift+R`) or open a private/incognito window. LuCI JavaScript may be cached by the browser.

## Command-line quick reference

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

### Show current state

```sh
proxy-mode status
```

Typical output includes the current mode, configuration file, IPv6 protection, DNS policy and whether sing-box is running.

### Switch mode

To switch to mode 6:

```sh
proxy-mode 6
```

The wrapper waits for the upstream/default route, validates the candidate configuration, starts it, tests local DNS and rolls back if the DNS health check fails.

### Restart the current mode

```sh
proxy-mode restart
```

### Recover after WAN/WWAN comes back

```sh
proxy-mode recover
```

This is also called by the iface hotplug hook when the configured upstream becomes ready after boot.

## IPv6 leak protection

Block IPv6:

```sh
proxy-mode ipv6 block
```

Allow IPv6 again:

```sh
proxy-mode ipv6 allow
```

When IPv6 protection is enabled, the suite creates an `-ipv6-block.json` variant for the selected base mode, blocks LAN/router IPv6 egress and uses an IPv4-only DNS strategy where required.

Check it with:

```sh
proxy-mode status
```

A healthy blocked state should report the firewall, DNS strategy and sing-box IPv6 rule as normal.

## Mode files

Base mode files live under:

```text
/etc/sing-box/mode1.json
/etc/sing-box/mode2.json
/etc/sing-box/mode3.json
...
```

Generated IPv6-block variants use names such as:

```text
/etc/sing-box/mode6-ipv6-block.json
```

Do not treat generated `-ipv6-block.json` files as the canonical configuration. Edit the base `modeN.json`; the protected variant is regenerated automatically.

Validate a base mode manually with:

```sh
sing-box check -c /etc/sing-box/mode6.json
```

## Fresh-router behavior

The project intentionally does not ship real production mode JSON files because they normally contain private node credentials.

On a fresh router with no valid running config, no valid saved `sing-box.main.conffile`, and no `/etc/sing-box/mode1.json`, the suite leaves the proxy unconfigured instead of inventing a mode.

If a valid mode is already running during reinstall, rc2 preserves that actual runtime configuration first. If nothing is running, it preserves a valid saved UCI configuration. Only a fresh installation with a valid `mode1.json` falls back to mode 1.

## Adding a mode in LuCI

In **Services → Proxy Mode → Mode Manager**:

1. Click **Add Mode**.
2. Clone an existing working mode or choose custom JSON.
3. Give the mode a descriptive name.
4. Save the JSON.
5. The backend validates it with `sing-box check` before replacing a working configuration.

You can also edit, rename, switch and delete non-current modes from the same page.

## Useful diagnostics

Check upstream state:

```sh
ubus call network.interface.wwan status
ip -4 route
```

Check local DNS:

```sh
nslookup www.google.com 127.0.0.1
```

Check sing-box process and actual config:

```sh
pgrep -af sing-box
```

Check recent logs:

```sh
logread | grep -Ei 'proxy-mode|sing-box|wwan'
```

If UCI and the running process ever appear to disagree, compare:

```sh
uci -q get sing-box.main.conffile
pgrep -af sing-box
```

The rc2 installer/package logic is designed to preserve the actually running valid configuration during reinstall to avoid this mismatch.

## Export and import

Export from the old router:

```sh
/usr/libexec/proxy-mode-export
```

Copy the generated archive to the new router, install the suite, then import it:

```sh
/usr/libexec/proxy-mode-import /tmp/proxy-mode-backup-YYYYMMDD-HHMMSS.tar.gz
```

Review the restored configuration before switching traffic.

## Security

Do not publish real mode files or export archives. They may contain server addresses, UUIDs, passwords, private keys, short IDs, subscription URLs or other credentials.
