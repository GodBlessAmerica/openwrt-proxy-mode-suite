#!/bin/sh
# Unified source installation / upgrade for OpenWrt 25.12 APK systems.
set -eu
umask 077
[ "$(id -u)" = 0 ] || { echo 'Root required' >&2; exit 1; }
[ -f /etc/openwrt_release ] || { echo 'OpenWrt required' >&2; exit 1; }
command -v apk >/dev/null || { echo 'APK-based OpenWrt required' >&2; exit 1; }
D="$(mktemp -d /tmp/proxy-mode-suite-XXXXXX)"
# Prefer an explicitly selected source ref; default is the maintained main.
REF="main"
URL="https://github.com/GodBlessAmerica/openwrt-proxy-mode-suite/archive/refs/heads/$REF.tar.gz"
if command -v curl >/dev/null; then
  curl -fL --retry 2 --connect-timeout 20 -o "$D/source.tar.gz" "$URL"
else
  wget -T 60 -O "$D/source.tar.gz" "$URL"
fi
tar -xzf "$D/source.tar.gz" -C "$D"
ROOT="$D/openwrt-proxy-mode-suite-$REF"
[ "$(cat "$ROOT/VERSION")" = 1.1.2 ] || { echo 'Unexpected source version' >&2; exit 1; }
# Do not replace an existing sing-box binary or force dependency upgrades.
missing=''
for dep in sing-box jq nftables; do
  case "$dep" in nftables) cmd=nft;; *) cmd="$dep";; esac
  command -v "$cmd" >/dev/null || missing="$missing $dep"
done
[ -d /usr/share/luci ] || missing="$missing luci"
if [ -n "$missing" ]; then apk update; apk add $missing; fi
sh "$ROOT/scripts/test-dns-bootstrap.sh"
sh "$ROOT/scripts/install.sh"
echo "Source retained: $ROOT"
