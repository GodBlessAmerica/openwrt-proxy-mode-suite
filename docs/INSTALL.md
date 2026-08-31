# Installation

## Supported design

This project targets standard OpenWrt systems with LuCI and sing-box. The reference system is OpenWrt 25.12.5 with apk-tools, but the suite itself is architecture independent because it does not bundle a sing-box binary.

## Prerequisites

Before installing the suite, the router should have:

- OpenWrt
- LuCI
- sing-box installed as `/usr/bin/sing-box`
- `uci`
- `jsonfilter`
- `rpcd`
- `uhttpd`
- TUN/kernel support required by your sing-box configuration

For the GUI, modern builds should also provide:

- `rpcd-mod-file`
- `uhttpd-mod-ubus`

The formal LuCI package declares these dependencies.

## Preferred installation: release packages

Download the package files built for the same OpenWrt release/target family from GitHub Actions or a GitHub Release.

### APK-based OpenWrt

```sh
apk add ./proxy-mode-core_*.apk
apk add ./luci-app-proxy-mode_*.apk
```

If `sing-box` is not installed yet, install it from the matching OpenWrt repository first.

### OPKG-based OpenWrt

```sh
opkg install ./proxy-mode-core_*.ipk
opkg install ./luci-app-proxy-mode_*.ipk
```

Do not assume a package produced by one OpenWrt release SDK is appropriate for an unrelated OpenWrt release.

## Source installation

For development, recovery or before a release package exists, copy/clone the repository to the router and run:

```sh
cd openwrt-proxy-mode-suite
chmod +x scripts/*.sh core/usr/bin/proxy-mode core/etc/init.d/sing-box luci-app-proxy-mode/usr/libexec/proxy-mode-ui
./scripts/install.sh
```

The source installer backs up existing files to:

```text
/root/proxy-mode-suite-backup-YYYYMMDD-HHMMSS/
```

before replacing them.

After either installation method, open:

**LuCI → Services → Proxy Mode**

## First mode on a fresh router

The suite intentionally does not ship a real production `mode1.json`, because mode files normally contain private node information.

Create `/etc/sing-box/mode1.json` from your own known-good sing-box configuration, then validate it:

```sh
sing-box check -c /etc/sing-box/mode1.json
```

Set the active configuration if necessary:

```sh
uci set sing-box.main.conffile='/etc/sing-box/mode1.json'
uci commit sing-box
proxy-mode 1
```

Once one working mode exists, the LuCI Mode Manager can clone it to create additional modes or accept complete Custom JSON.

## Existing router upgrade

If the router already has `/etc/sing-box/modeN.json` files, the source installer leaves those files untouched. Package upgrades treat `/etc/config/proxy-mode` and `/etc/config/sing-box` as configuration files.

Before the first package-based upgrade of an important router, create a migration backup:

```sh
/usr/libexec/proxy-mode-export
```

or, from a repository checkout:

```sh
scripts/export-config.sh
```

## Verify after installation

Run:

```sh
proxy-mode status
proxy-mode ipv6 status
```

Then confirm LuCI opens and shows your mode list.

If the page does not appear immediately, restart the web/RPC services or clear the LuCI cache:

```sh
rm -rf /tmp/luci-* /tmp/.uci 2>/dev/null
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

## Building for another OpenWrt target

Use **Actions → Build OpenWrt packages → Run workflow** and specify:

- OpenWrt version
- target
- subtarget

Leave `release_tag` blank for an artifact-only test build. Supply a semantic tag such as `v1.0.0` only when you intend to publish a GitHub Release.

See [`PACKAGING.md`](PACKAGING.md) for details.
