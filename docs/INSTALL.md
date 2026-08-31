# Installation

## Supported design

This project targets standard OpenWrt systems with sing-box and, for the graphical interface, LuCI. The reference build environment is OpenWrt 25.12.5 with apk-tools. The suite itself does not bundle the sing-box binary.

## Prerequisites

Before installing `proxy-mode-core`, the router should have:

- OpenWrt
- official `sing-box` installed as `/usr/bin/sing-box`
- `uci`
- `jsonfilter`
- TUN/kernel support required by your sing-box configuration

Before installing `luci-app-proxy-mode`, the router should additionally already have:

- LuCI
- `rpcd`
- `uhttpd`

Modern LuCI installations normally provide the RPC/uhttpd integration they require. The GUI package intentionally does not hard-select the complete LuCI dependency tree during SDK package-only builds; its post-install check verifies the runtime is present on the router.

## Preferred installation: GitHub Release packages

Do not commit locally built APK/IPK binaries into the source branch. Release binaries should be distributed through **GitHub Releases** together with `SHA256SUMS`.

Download packages built for a compatible OpenWrt release/target family.

### APK-based OpenWrt

Copy both packages to the router:

```sh
scp proxy-mode-core-*.apk root@ROUTER_IP:/tmp/
scp luci-app-proxy-mode-*.apk root@ROUTER_IP:/tmp/
```

Verify the files if `SHA256SUMS` is supplied:

```sh
sha256sum -c SHA256SUMS
```

Install core first, then GUI:

```sh
apk add /tmp/proxy-mode-core-*.apk
apk add /tmp/luci-app-proxy-mode-*.apk
```

### OPKG-based OpenWrt

```sh
opkg install ./proxy-mode-core_*.ipk
opkg install ./luci-app-proxy-mode_*.ipk
```

Do not assume a package produced by one OpenWrt release SDK is appropriate for an unrelated OpenWrt release.

## Existing router: back up first

If the router already runs sing-box modes, preserve the existing working configuration before the first package installation.

At minimum back up:

```text
/etc/config/sing-box
/etc/sing-box/
```

If Proxy Mode Suite is already installed from source, use:

```sh
/usr/libexec/proxy-mode-export
```

or from a repository checkout:

```sh
scripts/export-config.sh
```

The package does not ship production `modeN.json` files and does not intentionally replace existing mode files.

## Verify prerequisites before installation

Useful checks:

```sh
command -v sing-box
sing-box version
command -v uci
command -v jsonfilter
```

For the GUI:

```sh
[ -d /usr/share/luci ] && echo LuCI-present
[ -x /etc/init.d/rpcd ] && echo rpcd-present
[ -x /etc/init.d/uhttpd ] && echo uhttpd-present
```

## Verify after installation

Run:

```sh
proxy-mode status
proxy-mode ipv6 status
```

Restart RPC/web services if needed:

```sh
rm -rf /tmp/luci-* /tmp/.uci 2>/dev/null
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

Then open:

**LuCI → Services → Proxy Mode**

## First mode on a fresh router

The suite intentionally does not ship a real production `mode1.json`, because mode files normally contain private node information.

Create `/etc/sing-box/mode1.json` from your own known-good sing-box configuration and validate it:

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

## Source installation

For development or recovery, clone/copy the repository to the router and use the source installer:

```sh
cd openwrt-proxy-mode-suite
chmod +x scripts/*.sh core/usr/bin/proxy-mode luci-app-proxy-mode/usr/libexec/proxy-mode-ui
./scripts/install.sh
```

The source installer creates a timestamped backup before replacing suite-owned files.

## Building locally with the official SDK

Prepare a clean SDK with:

```sh
cd openwrt-proxy-mode-suite
sh scripts/prepare-sdk.sh /path/to/sdk
```

Then build:

```sh
cd /path/to/sdk
make package/proxy-mode-suite/proxy-mode-core/compile V=s -j1
make package/proxy-mode-suite/luci-app-proxy-mode/compile V=s -j1
```

For the verified OpenWrt 25.12.5 mediatek/filogic SDK, the APK files are emitted under a path similar to:

```text
bin/packages/aarch64_cortex-a53/base/
```

See [`PACKAGING.md`](PACKAGING.md) for release and CI details.
