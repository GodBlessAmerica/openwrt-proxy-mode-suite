#!/bin/sh
set -eu

# Prepare an OpenWrt SDK for building Proxy Mode Suite from this checkout.
# Usage: scripts/prepare-sdk.sh /path/to/openwrt-sdk

SDK_DIR="${1:-}"
if [ -z "$SDK_DIR" ]; then
  echo "Usage: $0 /path/to/openwrt-sdk" >&2
  exit 2
fi

case "$SDK_DIR" in
  /*) ;;
  *) SDK_DIR="$(cd "$SDK_DIR" 2>/dev/null && pwd)" ;;
esac

if [ ! -f "$SDK_DIR/rules.mk" ] || [ ! -x "$SDK_DIR/scripts/feeds" ]; then
  echo "Not an OpenWrt SDK/buildroot: $SDK_DIR" >&2
  exit 2
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
SUITE_DIR="$SDK_DIR/package/proxy-mode-suite"

printf '%s\n' "Preparing SDK: $SDK_DIR"
printf '%s\n' "Suite source:  $REPO_ROOT"

cd "$SDK_DIR"

# Update only the feeds this project actually needs. Do NOT install every feed
# package into the SDK: doing so imports unrelated package Kconfig and prereqs
# (nginx modules, many U-Boot variants, etc.) and can create irrelevant recursive
# dependency warnings or host-tool failures before our packages are even built.
./scripts/feeds update packages luci

# Install only the package definitions needed by Proxy Mode Suite and LuCI.
# OpenWrt SDK already provides the base system package definitions. These calls
# add the external feed packages we directly need without selecting the whole feed.
./scripts/feeds install luci-base

# Critical: never layer new symlinks over an old suite directory. Old package
# Makefiles can survive and generate impossible Kconfig relationships such as
# a package depending on itself.
rm -rf "$SUITE_DIR"
mkdir -p "$SUITE_DIR"

ln -s "$REPO_ROOT/package/proxy-mode-core" "$SUITE_DIR/proxy-mode-core"
ln -s "$REPO_ROOT/package/luci-app-proxy-mode" "$SUITE_DIR/luci-app-proxy-mode"
ln -s "$REPO_ROOT/core" "$SUITE_DIR/core"
ln -s "$REPO_ROOT/luci-app-proxy-mode" "$SUITE_DIR/luci-app-proxy-mode-src"
ln -s "$REPO_ROOT/scripts" "$SUITE_DIR/scripts"

# Kconfig/package metadata is generated from Makefiles. Purge it after replacing
# the suite so stale dependency expressions cannot remain in tmp/.config-package.in.
rm -rf tmp
mkdir -p tmp

# Remove stale selections left by previous broad feed installs/build attempts.
if [ -f .config ]; then
  sed -i \
    -e '/^CONFIG_PACKAGE_proxy-mode-core=/d' \
    -e '/^CONFIG_PACKAGE_luci-app-proxy-mode=/d' \
    -e '/^CONFIG_PACKAGE_sing-box-tiny=/d' \
    -e '/^CONFIG_PACKAGE_liblucihttp-lua=/d' \
    .config
fi

make defconfig

printf '%s\n' 'SDK preparation complete.'
printf '%s\n' "Build core: make package/proxy-mode-suite/proxy-mode-core/compile V=s -j1"
printf '%s\n' "Build LuCI: make package/proxy-mode-suite/luci-app-proxy-mode/compile V=s -j1"
