# Installation

## Reference environment

- OpenWrt 25.12.5
- target `mediatek/filogic`
- `aarch64_cortex-a53`
- RAX3000M reference router
- sing-box 1.13.18

The suite manages the official OpenWrt sing-box package; it does not replace it.

## Prerequisites

Install the official package first:

```sh
apk update
apk add sing-box
```

The GUI additionally requires LuCI, `rpcd` and `uhttpd`.

## Optional: change the LAN subnet

Proxy Mode does not require a specific LAN address. Change it only if you want a different local subnet or need to avoid a conflict with the upstream network.

Example: change the LAN address to `10.88.0.1/24`:

```sh
uci set network.lan.ipaddr='10.88.0.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network
/etc/init.d/network restart
```

The current SSH/LuCI session will normally disconnect after the network restart. Reconnect using the new address, for example:

```sh
ssh root@10.88.0.1
```

Choose a LAN subnet that does not overlap the upstream network. For example, if the uplink is `192.168.71.0/24`, `10.88.0.0/24` is a non-overlapping example.

You can also change the LAN address from LuCI under **Network → Interfaces → LAN**.

## Preferred installation: GitHub Release APKs

For rc3, install:

```text
proxy-mode-core-1.0.0-r13.apk
luci-app-proxy-mode-1.0.0-r7.apk
SHA256SUMS
```

### Direct download on the router

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

`-4` forces IPv4 and `-T 60` allows extra time for GitHub and its Release CDN on router connections. If the first HTTPS attempt times out, retry the same command.

Expected verification:

```text
luci-app-proxy-mode-1.0.0-r7.apk: OK
proxy-mode-core-1.0.0-r13.apk: OK
```

Install:

```sh
apk add --allow-untrusted /tmp/proxy-mode-core-1.0.0-r13.apk
apk add --allow-untrusted /tmp/luci-app-proxy-mode-1.0.0-r7.apk
```

The Release APKs are not signed by an OpenWrt repository key, so `--allow-untrusted` is expected here. Only use it after downloading from this project's Release page and verifying `SHA256SUMS`.

### Copy from another computer

If the router cannot download directly from GitHub Release, download the same three files on another computer and copy them to `/tmp`:

```sh
scp proxy-mode-core-*.apk root@ROUTER_IP:/tmp/
scp luci-app-proxy-mode-*.apk root@ROUTER_IP:/tmp/
scp SHA256SUMS root@ROUTER_IP:/tmp/
```

Then on the router:

```sh
cd /tmp
sha256sum -c SHA256SUMS
apk add --allow-untrusted /tmp/proxy-mode-core-*.apk
apk add --allow-untrusted /tmp/luci-app-proxy-mode-*.apk
```

## Fresh-router behavior

The official sing-box package may create `/etc/sing-box/config.json`; Proxy Mode does not treat that file as a managed mode.

On a fresh router with no valid `/etc/sing-box/modeN.json`:

- Proxy Mode remains unconfigured;
- `sing-box.main.enabled` remains `0`;
- no managed mode is invented;
- unconditional sing-box `rc.d` autostart is disabled;
- the official `/etc/init.d/sing-box` implementation remains intact.

Typical fresh status:

```text
当前模式：未配置
配置文件：未设置
运行状态：已停止
```

## Add the first mode in LuCI

Open:

**LuCI → Services → Proxy Mode**

Then:

1. Click **Add Mode**.
2. Enter a Mode Number from `1` to `999`, for example `6`.
3. Choose **Custom JSON**.
4. Enter a name, for example `Mode 6`.
5. Paste a complete known-good sing-box JSON configuration.
6. Click **Create**.

The backend validates it with `sing-box check` before creating the mode. A Mode Number of `6` creates:

```text
/etc/sing-box/mode6.json
```

Validate manually if desired:

```sh
sing-box check -c /etc/sing-box/mode6.json
```

Then switch/start it:

```sh
proxy-mode 6
```

The first activation automatically changes `sing-box.main.enabled` to `1`.

## Upstream interface pinning is optional

Basic proxy operation and manual mode switching do not require `sing-box.main.ifaces` when a usable IPv4 default route already exists.

For a router with a known WAN/WWAN interface, setting it is recommended because recovery after boot or reconnect can then wait for the intended interface rather than any default route.

Example for a Wi-Fi STA uplink named `wwan`:

```sh
uci set sing-box.main.ifaces='wwan'
uci commit sing-box
```

With this setting, recovery waits for `wwan` plus an IPv4 default route. Without it, the wrapper falls back to default-route readiness.

## Existing-router reinstall behavior

The suite preserves production mode files. Selection order is:

1. valid managed configuration used by a running sing-box process;
2. otherwise a valid saved managed `sing-box.main.conffile`;
3. otherwise a valid `/etc/sing-box/mode1.json` fallback when present;
4. otherwise remain unconfigured.

Back up important routers before upgrades:

```text
/etc/config/sing-box
/etc/config/proxy-mode
/etc/sing-box/
```

## Source installation from GitHub

For development/recovery using the latest `main`:

```sh
cd /tmp
rm -rf openwrt-proxy-mode-suite openwrt-proxy-mode-suite-main proxy-mode-suite.tar.gz
wget -4 -T 60 -O proxy-mode-suite.tar.gz \
  https://github.com/GodBlessAmerica/openwrt-proxy-mode-suite/archive/refs/heads/main.tar.gz

tar -xzf proxy-mode-suite.tar.gz
mv openwrt-proxy-mode-suite-main openwrt-proxy-mode-suite
cd openwrt-proxy-mode-suite
sh scripts/install.sh
```

Expected fresh-install output includes:

```text
Proxy Mode owns sing-box boot sequencing; unconditional sing-box autostart is disabled.
Fresh install: no managed mode found; Proxy Mode remains unconfigured.
```

For ordinary users, the tested Release APKs are preferred over installing the latest `main` source.

## Verify after installation

```sh
proxy-mode status
proxy-mode health
uci -q show sing-box
pgrep -af sing-box
ls -l /etc/rc.d/*sing-box* 2>/dev/null || echo "sing-box rc.d autostart disabled"
```

On a fresh unconfigured router, there should be no sing-box process and no `Sxxsing-box` rc.d link.

If LuCI looks stale after upgrading:

```sh
rm -f /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache/* 2>/dev/null || true
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

Then hard-refresh or use a private/incognito browser window.

## Boot and WWAN recovery

Proxy Mode deliberately disables unconditional sing-box `rc.d` startup. The selected mode is started by Proxy Mode only after upstream readiness is confirmed.

When a configured interface such as `wwan` emits `ifup`, `/etc/hotplug.d/iface/99-proxy-mode` schedules recovery. Recovery is serialized with a lock so duplicate interface events do not create concurrent restart races. The wrapper waits for interface readiness and an IPv4 default route before restarting the selected mode.

Useful checks:

```sh
ubus call network.interface.wwan status
ip -4 route
proxy-mode status
pgrep -af sing-box
cat /tmp/proxy-mode-recover.log 2>/dev/null
logread | grep -Ei 'proxy-mode|sing-box|wwan' | tail -100
```

On the RAX3000M reference setup, multiple enabled 5 GHz STA profiles assigned to the same `wwan` caused availability problems. Keep only the intended uplink enabled unless failover has been explicitly tested.

## Safe switching

For numeric mode switches, the wrapper:

1. waits for the configured upstream/default route;
2. synchronizes a simple host `route_exclude_address` when applicable;
3. enables sing-box if this is the first managed-mode activation;
4. starts the candidate mode;
5. tests local DNS;
6. restores the previous configuration if the health check fails.

## Build locally

```sh
sh scripts/prepare-sdk.sh /path/to/sdk
cd /path/to/sdk
make package/proxy-mode-suite/proxy-mode-core/compile V=s -j1
make package/proxy-mode-suite/luci-app-proxy-mode/compile V=s -j1
```

See [`USAGE.md`](USAGE.md) and [`PACKAGING.md`](PACKAGING.md).
