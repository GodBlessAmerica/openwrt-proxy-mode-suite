# Packaging and Releases

This project uses standard OpenWrt package Makefiles and builds two packages:

- `proxy-mode-core`
- `luci-app-proxy-mode`

The official OpenWrt `sing-box` package is not bundled.

## rc3 reference

Reference environment:

```text
OpenWrt: 25.12.5
Target: mediatek
Subtarget: filogic
Architecture: aarch64_cortex-a53
Package format: APK
```

rc3 package revisions:

```text
proxy-mode-core-1.0.0-r13.apk
luci-app-proxy-mode-1.0.0-r7.apk
```

## Local SDK build

```sh
cd openwrt-proxy-mode-suite
sh scripts/prepare-sdk.sh /path/to/sdk

cd /path/to/sdk
make package/proxy-mode-suite/proxy-mode-core/compile V=s -j1
make package/proxy-mode-suite/luci-app-proxy-mode/compile V=s -j1
```

The generated packages are normally found under an SDK output directory similar to:

```text
bin/packages/aarch64_cortex-a53/base/
```

## GitHub Actions

Workflow:

```text
.github/workflows/build-openwrt-packages.yml
```

It is currently triggered manually with `workflow_dispatch` and defaults to:

```text
OpenWrt 25.12.5
mediatek/filogic
```

The workflow downloads the official SDK, prepares the package tree, builds both packages, creates `SHA256SUMS` and uploads the result as a GitHub Actions artifact.

## Release assets

A rc3 release should contain:

```text
proxy-mode-core-1.0.0-r13.apk
luci-app-proxy-mode-1.0.0-r7.apk
SHA256SUMS
```

Do not commit generated APK/IPK files to `main`; use Actions artifacts and GitHub Release assets instead.

Verify assets after downloading:

```sh
sha256sum -c SHA256SUMS
```

## Release smoke-test checklist

Before publishing rc3:

1. Fresh OpenWrt install has official sing-box but no Proxy Mode files.
2. Suite installs with zero modes and reports `未配置`.
3. `sing-box.main.enabled='0'` until the first managed mode is activated.
4. Unconditional sing-box rc.d autostart is disabled.
5. LuCI Add Mode can explicitly create `mode6.json` as Mode 6.
6. Custom JSON is validated with `sing-box check`.
7. First mode activation sets `sing-box.main.enabled='1'` and starts successfully.
8. IPv6 block mode generates and runs the protected variant.
9. WWAN hotplug recovery restores the selected mode after upstream returns.
10. Duplicate recovery triggers are serialized/skipped.
11. `proxy-mode status` and local DNS health are normal.
12. No real credentials, UUIDs, private keys or production mode files are present in source or release assets.

## Installing release packages

```sh
apk add ./proxy-mode-core-*.apk
apk add ./luci-app-proxy-mode-*.apk
```

Install the official OpenWrt sing-box package first.
