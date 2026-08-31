# Installation

## Supported design

This project targets standard OpenWrt systems with sing-box and, for the graphical interface, LuCI. The reference build/runtime environment is OpenWrt 25.12.5 on `mediatek/filogic` with apk-tools and a RAX3000M reference router. The suite itself does not bundle the sing-box binary.

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

## Preferred installation: GitHub Release packages

Release binaries should be distributed through **GitHub Releases** together with `SHA256SUMS`; do not commit locally built APK/IPK binaries into `main`.

Copy both packages to the router:

```sh
scp proxy-mode-core-*.apk root@ROUTER_IP:/tmp/
scp luci-app-proxy-mode-*.apk root@ROUTER_IP:/tmp/
```

For signed Release packages, install normally:

```sh
apk add /tmp/proxy-mode-core-*.apk
apk add /tmp/luci-app-proxy-mode-*.apk
```

For locally built development APKs, OpenWrt may reject the developer signature and may also attempt to refresh remote repositories. For an intentional local/offline test, use:

```sh
apk add --simulate --no-network --allow-untrusted /tmp/proxy-mode-core-*.apk
apk add --no-network --allow-untrusted /tmp/proxy-mode-core-*.apk
apk add --simulate --no-network --allow-untrusted /tmp/luci-app-proxy-mode-*.apk
apk add --no-network --allow-untrusted /tmp/luci-app-proxy-mode-*.apk
```

`--allow-untrusted` is for trusted self-built development artifacts, not arbitrary downloaded packages.

### OPKG-based OpenWrt

```sh
opkg install ./proxy-mode-core_*.ipk
opkg install ./luci-app-proxy-mode_*.ipk
```

Do not assume a package produced by one OpenWrt release SDK is appropriate for an unrelated OpenWrt release.

## Existing router: back up first

If the router already runs sing-box modes, preserve the working configuration before the first package installation:

```text
/etc/config/sing-box
/etc/config/proxy-mode
/etc/sing-box/
```

The package treats `/etc/config/proxy-mode` as a conffile and preserves an existing valid `sing-box.main.conffile`. It does not intentionally replace production `modeN.json` files.

## Verify after installation

Run:

```sh
proxy-mode status
proxy-mode health
```

Expected status includes the saved mode plus upstream/default-route and DNS health.

For the GUI:

```sh
rm -rf /tmp/luci-* /tmp/.uci 2>/dev/null
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

Then open **LuCI → Services → Proxy Mode**.

## Boot and WWAN recovery

`proxy-mode-core` r10+ installs:

```text
/usr/bin/proxy-mode                runtime safety wrapper
/usr/libexec/proxy-mode-core       mode-management core
/etc/hotplug.d/iface/99-proxy-mode upstream recovery hook
```

When a configured upstream interface such as `wwan` comes up after boot, the hotplug hook schedules `proxy-mode recover`. Recovery waits for an IPv4 default route before regenerating/restarting the saved mode.

Useful checks:

```sh
ubus call network.interface.wwan status
ip -4 route
proxy-mode status
nslookup www.google.com 127.0.0.1
```

A Wi-Fi STA uplink should show `up: true`, an IPv4 lease and a `default via ...` route before the proxy is considered healthy.

### Multiple STA profiles on one radio

On the RAX3000M reference setup, enabling two 5 GHz STA profiles simultaneously and assigning both to the same `wwan` caused `wwan` to remain unavailable. If using backup STA profiles, keep only the intended uplink enabled during normal operation unless you have explicitly designed/tested failover behavior.

## Safe switching behavior

For numeric mode switches, r10+:

1. waits for the configured upstream/default route;
2. validates the candidate sing-box configuration;
3. synchronizes a simple single-host `route_exclude_address` with the selected mode's first outbound IPv4 server when applicable;
4. starts the candidate mode;
5. tests local DNS resolution;
6. restores the previous configuration if the DNS health check fails.

Complex/manual `route_exclude_address` lists are left unchanged rather than rewritten automatically.

## First mode on a fresh router

The suite intentionally does not ship a real production `mode1.json`, because mode files normally contain private node information.

Create `/etc/sing-box/mode1.json` from your own known-good sing-box configuration and validate it:

```sh
sing-box check -c /etc/sing-box/mode1.json
```

Then:

```sh
uci set sing-box.main.conffile='/etc/sing-box/mode1.json'
uci commit sing-box
proxy-mode 1
```

## Source installation

For development or recovery, clone/copy the repository to the router and use the source installer:

```sh
cd openwrt-proxy-mode-suite
chmod +x scripts/*.sh core/usr/bin/proxy-mode luci-app-proxy-mode/usr/libexec/proxy-mode-ui
./scripts/install.sh
```

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

For the verified OpenWrt 25.12.5 mediatek/filogic SDK, APK files are emitted under a path similar to:

```text
bin/packages/aarch64_cortex-a53/base/
```

See [`PACKAGING.md`](PACKAGING.md) for release and CI details.
