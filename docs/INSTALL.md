# Installation

## Supported design

This project targets standard OpenWrt systems with LuCI and sing-box. The reference system is OpenWrt 25.12.5 with apk-tools, but the installer itself does not require a particular CPU architecture because it does not bundle a sing-box binary.

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

For the GUI, `rpcd-mod-file` and `uhttpd-mod-ubus` are recommended/expected on modern LuCI builds.

## Install

Copy or clone this repository to the router, then:

```sh
cd openwrt-proxy-mode-suite
chmod +x scripts/*.sh core/usr/bin/proxy-mode core/etc/init.d/sing-box luci-app-proxy-mode/usr/libexec/proxy-mode-ui
./scripts/install.sh
```

The installer backs up existing files to `/root/proxy-mode-suite-backup-YYYYMMDD-HHMMSS/` before replacing them.

Then open:

**LuCI → Services → Proxy Mode**

## First mode on a fresh router

The suite intentionally does not ship a real production `mode1.json`, because those files normally contain private node information.

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

## Existing router upgrade

If the router already has `/etc/sing-box/modeN.json` files, the installer leaves those files untouched. It also leaves an existing `/etc/config/proxy-mode` registry intact.

## Package manager notes

The current repository stores portable source/install scripts. Formal `.apk` and `.ipk` packages are a roadmap item. Do not assume an APK built for one OpenWrt release can be safely installed on an unrelated release or architecture.
