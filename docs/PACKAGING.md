# Packaging and Releases

This project uses standard OpenWrt package Makefiles. The same source tree can produce `.apk` packages on newer OpenWrt releases and `.ipk` packages on older releases, depending on the SDK selected for the build.

## Packages

Two packages are built:

- `proxy-mode-core` — runtime shell code, UCI defaults, export/import helpers.
- `luci-app-proxy-mode` — LuCI JavaScript view, RPC ACL and UI backend.

`luci-app-proxy-mode` depends on `proxy-mode-core`.

The sing-box binary is intentionally **not bundled**. Install the official OpenWrt `sing-box` package on the target router first.

The LuCI package also intentionally avoids hard-selecting the full LuCI dependency tree during an SDK package-only build. It expects the target router to already have LuCI, `rpcd` and `uhttpd`.

## Verified reference build

A successful local build has been completed using:

```text
OpenWrt: 25.12.5
Target: mediatek
Subtarget: filogic
Architecture: aarch64_cortex-a53
Toolchain: GCC 14.3.0 / musl
Package format: APK
```

Verified outputs from that build were:

```text
proxy-mode-core-1.0.0-r8.apk
luci-app-proxy-mode-1.0.0-r5.apk
```

Package revisions may increase in later commits, so users should treat those filenames as a reference, not as fixed permanent names.

## Local SDK build

Start with a clean official SDK and a repository checkout. Then run:

```sh
cd openwrt-proxy-mode-suite
sh scripts/prepare-sdk.sh /path/to/sdk

cd /path/to/sdk
make package/proxy-mode-suite/proxy-mode-core/compile V=s -j1
make package/proxy-mode-suite/luci-app-proxy-mode/compile V=s -j1
```

The helper intentionally avoids installing every feed package into the SDK. Installing an entire feed can import unrelated Kconfig/prerequisite trees such as nginx or U-Boot and cause failures unrelated to Proxy Mode Suite.

For the reference APK SDK, successful output appears under a path similar to:

```text
bin/packages/aarch64_cortex-a53/base/
```

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

The workflow downloads the official SDK, prepares the package tree, compiles both suite packages, calculates SHA-256 hashes and collects the generated artifacts.

## Where binaries belong

Do **not** commit generated `.apk`, `.ipk` or `SHA256SUMS` files into the source tree on `main`.

Use:

- source files and documentation in the Git repository;
- temporary/test builds as GitHub Actions artifacts;
- tested distributable binaries as GitHub Release assets.

This keeps source history small and avoids stale binaries being mistaken for current builds.

## Publishing a release

After the generated packages pass installation and runtime smoke tests on the reference router, publish a semantic release such as:

```text
v1.0.0
```

A release should contain:

```text
proxy-mode-core-<version>.apk
luci-app-proxy-mode-<version>.apk
SHA256SUMS
```

or the equivalent `.ipk` files for an older OPKG-based OpenWrt SDK.

Verify downloaded release assets with:

```sh
sha256sum -c SHA256SUMS
```

## Installing release packages

APK-based OpenWrt:

```sh
apk add ./proxy-mode-core-*.apk
apk add ./luci-app-proxy-mode-*.apk
```

OPKG-based OpenWrt:

```sh
opkg install ./proxy-mode-core_*.ipk
opkg install ./luci-app-proxy-mode_*.ipk
```

Install core first, then the GUI package.

## Why package-only builds avoid hard runtime dependency trees

OpenWrt's package metadata can expose provider/variant relationships and large transitive dependency trees that are useful for full firmware builds but problematic for tiny SDK package-only builds.

This project therefore keeps two boundaries explicit:

1. `proxy-mode-core` requires the official sing-box runtime on the target device, but does not hard-select the sing-box full/tiny provider variants during package build.
2. `luci-app-proxy-mode` requires an existing LuCI/rpcd/uhttpd runtime on the target device, but does not force the SDK to rebuild the complete LuCI/lucihttp stack merely to package static JavaScript, ACL and shell helper files.

Runtime post-install checks protect against installing onto an unsuitable target.

## Architecture note

The package output may be emitted inside an architecture-specific SDK output directory even though the suite is implemented in shell/config/JavaScript and declares `PKGARCH:=all`. The exact package metadata and output naming are controlled by the selected OpenWrt SDK/package manager.

`sing-box` remains an external architecture-specific package supplied by OpenWrt.

## Before publishing a stable release

1. Both packages build successfully with the intended SDK.
2. Both packages install successfully on the reference router.
3. `proxy-mode status` works.
4. Switching at least two known-good modes succeeds.
5. IPv6 block/allow can be toggled and restored.
6. LuCI opens without JavaScript or RPC errors.
7. Editing an invalid mode is rejected by `sing-box check`.
8. Current mode cannot be deleted.
9. Export/import is tested with a disposable backup.
10. Release includes `SHA256SUMS`.
11. No credentials, UUIDs, private keys, node URLs or production mode files are present in source history or release assets.

## Version policy

Recommended scheme:

- `0.x` — experimental GUI/runtime iterations.
- `1.0.0` — first reproducible and router-tested package release.
- Patch release — bug fixes that do not change backup/config format.
- Minor release — new UI/protocol/template functionality with backward-compatible configs.
- Major release — incompatible runtime or migration-format changes.
