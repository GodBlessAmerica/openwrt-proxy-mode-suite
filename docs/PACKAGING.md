# Packaging and Releases

This project uses standard OpenWrt package Makefiles. The same source tree can produce `.apk` packages on newer OpenWrt releases and `.ipk` packages on older releases, depending on the SDK selected for the build.

## Packages

Two packages are built:

- `proxy-mode-core` — runtime shell code, UCI defaults, procd service, export/import helpers.
- `luci-app-proxy-mode` — LuCI JavaScript view, RPC ACL and UI backend.

`luci-app-proxy-mode` depends on `proxy-mode-core`.

The sing-box binary is intentionally **not bundled**. The target OpenWrt feed should provide the architecture-specific `sing-box` package.

## GitHub Actions

Workflow:

```text
.github/workflows/build-openwrt-packages.yml
```

Default reference target:

```text
OpenWrt 25.12.5
Target: mediatek
Subtarget: filogic
```

This matches the original RAX3000M reference installation.

The workflow can also be launched manually with another release/target/subtarget. It downloads the corresponding official OpenWrt SDK, installs the required feeds, compiles both packages, calculates SHA-256 hashes, and uploads the results as a workflow artifact.

## Tagged releases

For a tagged build such as:

```text
v1.0.0
```

the workflow is configured to create/update a GitHub Release and upload the generated package files plus `SHA256SUMS`.

A release should contain files similar to:

```text
proxy-mode-core_1.0.0-r1_all.apk
luci-app-proxy-mode_1.0.0-r1_all.apk
SHA256SUMS
```

or on an older SDK:

```text
proxy-mode-core_1.0.0-1_all.ipk
luci-app-proxy-mode_1.0.0-1_all.ipk
SHA256SUMS
```

Exact package naming is controlled by the selected OpenWrt SDK.

## Installing release packages

Newer OpenWrt / APK example:

```sh
apk add ./proxy-mode-core_*.apk
apk add ./luci-app-proxy-mode_*.apk
```

Older OpenWrt / OPKG example:

```sh
opkg install ./proxy-mode-core_*.ipk
opkg install ./luci-app-proxy-mode_*.ipk
```

Install `sing-box` from the correct OpenWrt feed first if it is not already present.

## Why packages are architecture independent

The suite's own runtime consists of POSIX shell, UCI configuration and LuCI JavaScript. The project packages therefore use `PKGARCH:=all`.

`sing-box` itself is architecture dependent and remains an external dependency. This prevents one RAX3000M-specific binary from being accidentally installed on x86_64, armv7, mipsel or another target.

## Before publishing a release

Check the following:

1. `proxy-mode status` works on the reference router.
2. Switching at least two modes succeeds.
3. IPv6 block/allow can be toggled and restored.
4. LuCI opens without JavaScript or RPC errors.
5. Editing an invalid mode is rejected by `sing-box check`.
6. Current mode cannot be deleted.
7. Export/import has been tested with a disposable backup.
8. No real UUID, password, node hostname, subscription URL or private key is present in Git history.

## Version policy

Recommended scheme:

- `0.x` — experimental GUI/runtime iterations.
- `1.0.0` — first reproducible package release.
- Patch release — bug fixes that do not change backup/config format.
- Minor release — new UI/protocol/template functionality with backward-compatible configs.
- Major release — incompatible runtime or migration-format changes.
