# Installation

## Supported design

OpenWrt Proxy Mode Suite manages sing-box modes and provides a LuCI frontend. It does **not** bundle or replace the official OpenWrt sing-box package.

Reference environment:

- OpenWrt 25.12.5
- target `mediatek/filogic`
- `aarch64_cortex-a53`
- apk-tools 3.x
- RAX3000M reference router
- sing-box 1.13.x

Other compatible OpenWrt targets may work, but Release packages are built and validated against the reference SDK above.

## Prerequisites

Before installing `proxy-mode-core`, the router should already have:

- OpenWrt
- official `sing-box` at `/usr/bin/sing-box`
- `uci`
- `jsonfilter`
- TUN/kernel support needed by the selected sing-box configuration

Before installing `luci-app-proxy-mode`, the router should additionally have:

- LuCI
- `rpcd`
- `uhttpd`

## Preferred installation: GitHub Release APKs

Download both Release assets plus `SHA256SUMS`:

```text
proxy-mode-core-1.0.0-r11.apk
luci-app-proxy-mode-1.0.0-r6.apk
SHA256SUMS
```

Copy the APKs to the router:

```sh
scp proxy-mode-core-*.apk root@ROUTER_IP:/tmp/
scp luci-app-proxy-mode-*.apk root@ROUTER_IP:/tmp/
```

Install them:

```sh
apk add /tmp/proxy-mode-core-*.apk
apk add /tmp/luci-app-proxy-mode-*.apk
```

If you intentionally install trusted self-built development APKs, OpenWrt may require:

```sh
apk add --no-network --allow-untrusted /tmp/proxy-mode-core-*.apk
apk add --no-network --allow-untrusted /tmp/luci-app-proxy-mode-*.apk
```

Do not use `--allow-untrusted` for arbitrary third-party packages.

### OPKG-based OpenWrt

For compatible IPK builds:

```sh
opkg install ./proxy-mode-core_*.ipk
opkg install ./luci-app-proxy-mode_*.ipk
```

Do not assume a package built for one OpenWrt release/target is appropriate for an unrelated release/target.

## Existing router behavior

The suite is designed to preserve existing production mode files under `/etc/sing-box/`.

For rc2, package/source reinstall selection is:

1. preserve the valid configuration actually used by a running sing-box process;
2. otherwise preserve a valid saved `sing-box.main.conffile`;
3. otherwise, on a fresh installation only, use a valid `/etc/sing-box/mode1.json` if it exists;
4. if none exists, leave the proxy unconfigured instead of inventing a mode.

The installer/package does not intentionally replace production `modeN.json` files.

For important routers, keeping your own backup of these files is still recommended:

```text
/etc/config/sing-box
/etc/config/proxy-mode
/etc/sing-box/
```

## Fresh router: first mode

The project intentionally ships no real production `mode1.json`, because real sing-box mode files often contain private credentials.

Create your own known-good mode, for example:

```text
/etc/sing-box/mode1.json
```

Validate it:

```sh
sing-box check -c /etc/sing-box/mode1.json
```

Then start/switch to it:

```sh
proxy-mode 1
```

On a completely fresh router with no valid mode file, the suite remains unconfigured until you add one.

## Source installation from GitHub

For development, recovery, or testing the latest `main` branch:

```sh
cd /tmp
rm -rf openwrt-proxy-mode-suite openwrt-proxy-mode-suite-main proxy-mode-suite.tar.gz
wget -O proxy-mode-suite.tar.gz \
  https://github.com/GodBlessAmerica/openwrt-proxy-mode-suite/archive/refs/heads/main.tar.gz

tar -xzf proxy-mode-suite.tar.gz
mv openwrt-proxy-mode-suite-main openwrt-proxy-mode-suite
cd openwrt-proxy-mode-suite
chmod +x scripts/install.sh
sh scripts/install.sh
```

Important: if the router itself needs the currently running proxy to reach GitHub, download the new source **before** stopping/replacing the old proxy management layer.

## Verify after installation

Run:

```sh
proxy-mode status
proxy-mode health
pgrep -af sing-box
```

The saved configuration and the `-c` path shown by the running sing-box process should agree.

For the GUI:

```sh
rm -f /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache/* 2>/dev/null || true
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

Then open:

**LuCI → Services → Proxy Mode**

If the page still looks old after an upgrade, use `Ctrl+Shift+R` or an incognito/private browser window. Browser-side LuCI JavaScript caching can keep the old page visible even when the router already has the new file.

## Boot and WWAN recovery

`proxy-mode-core` installs:

```text
/usr/bin/proxy-mode                 runtime safety wrapper
/usr/libexec/proxy-mode-core        mode-management core
/usr/libexec/proxy-mode-export      export helper
/usr/libexec/proxy-mode-import      import helper
/etc/hotplug.d/iface/99-proxy-mode  upstream recovery hook
```

When the configured WAN/WWAN becomes ready after boot, the hotplug hook calls recovery logic. Recovery waits for an IPv4 default route before restarting/regenerating the saved mode.

Useful checks:

```sh
ubus call network.interface.wwan status
ip -4 route
proxy-mode status
nslookup www.google.com 127.0.0.1
```

A Wi-Fi STA uplink should normally show `up: true`, an IPv4 lease, and a default route before the proxy is considered healthy.

### Multiple STA profiles on one radio

On the RAX3000M reference setup, enabling multiple 5 GHz STA profiles and assigning them to the same `wwan` caused `wwan` to remain unavailable. Keep only the intended uplink enabled during normal operation unless you have explicitly designed and tested failover.

## Safe switching behavior

For numeric mode switches, the runtime wrapper:

1. waits for the configured upstream/default route;
2. validates the candidate sing-box configuration;
3. synchronizes a simple single-host `route_exclude_address` with the selected mode's first outbound IPv4 server when applicable;
4. starts the candidate mode;
5. tests local DNS resolution;
6. restores the previous configuration if the DNS health check fails.

Complex/manual `route_exclude_address` lists are left unchanged rather than rewritten automatically.

## Build locally with the official SDK

Prepare a clean SDK:

```sh
cd openwrt-proxy-mode-suite
sh scripts/prepare-sdk.sh /path/to/sdk
```

Build:

```sh
cd /path/to/sdk
make package/proxy-mode-suite/proxy-mode-core/compile V=s -j1
make package/proxy-mode-suite/luci-app-proxy-mode/compile V=s -j1
```

For the verified OpenWrt 25.12.5 `mediatek/filogic` SDK, APKs are emitted under a path similar to:

```text
bin/packages/aarch64_cortex-a53/base/
```

See [`USAGE.md`](USAGE.md) for day-to-day operation and [`PACKAGING.md`](PACKAGING.md) for build/release details.
