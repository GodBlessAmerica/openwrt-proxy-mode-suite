#!/bin/sh
set -eu

ARCHIVE="${1:-}"
[ -n "$ARCHIVE" ] && [ -f "$ARCHIVE" ] || { echo "Usage: $0 /path/proxy-mode-backup-*.tar.gz" >&2; exit 1; }
command -v sing-box >/dev/null 2>&1 || { echo 'ERROR: sing-box not installed' >&2; exit 1; }

TS="$(date +%Y%m%d-%H%M%S)"
WORK="/tmp/proxy-mode-import-$TS"
ROLLBACK="/root/proxy-mode-import-rollback-$TS"
mkdir -p "$WORK" "$ROLLBACK/etc/sing-box" "$ROLLBACK/etc/config"
tar -C "$WORK" -xzf "$ARCHIVE"

[ -f "$WORK/etc/config/sing-box" ] || { echo 'ERROR: backup has no etc/config/sing-box' >&2; rm -rf "$WORK"; exit 2; }

for f in "$WORK"/etc/sing-box/mode*.json; do
  [ -f "$f" ] || continue
  echo "Checking $(basename "$f")..."
  sing-box check -c "$f" || { echo "ERROR: invalid configuration in $f" >&2; rm -rf "$WORK"; exit 3; }
done

[ -f /etc/config/sing-box ] && cp -p /etc/config/sing-box "$ROLLBACK/etc/config/"
[ -f /etc/config/proxy-mode ] && cp -p /etc/config/proxy-mode "$ROLLBACK/etc/config/"
for f in /etc/sing-box/mode*.json; do [ -f "$f" ] && cp -p "$f" "$ROLLBACK/etc/sing-box/"; done

mkdir -p /etc/sing-box
cp -p "$WORK/etc/config/sing-box" /etc/config/sing-box
[ ! -f "$WORK/etc/config/proxy-mode" ] || cp -p "$WORK/etc/config/proxy-mode" /etc/config/proxy-mode
for f in "$WORK"/etc/sing-box/mode*.json; do [ -f "$f" ] && cp -p "$f" /etc/sing-box/; done
chmod 600 /etc/sing-box/mode*.json 2>/dev/null || true
rm -f /etc/sing-box/mode*-ipv6-block.json

if ! /usr/bin/proxy-mode restart; then
  echo "ERROR: imported configuration failed to start. Rollback copy is at $ROLLBACK" >&2
  exit 4
fi
rm -rf "$WORK"
echo "Import complete. Rollback snapshot: $ROLLBACK"
