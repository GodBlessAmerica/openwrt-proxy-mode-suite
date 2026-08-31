#!/bin/sh
set -eu

OUT_DIR="${1:-/tmp}"
TS="$(date +%Y%m%d-%H%M%S)"
WORK="/tmp/proxy-mode-export-$TS"
ARCHIVE="$OUT_DIR/proxy-mode-backup-$TS.tar.gz"
mkdir -p "$WORK/etc/sing-box" "$WORK/etc/config"

[ -f /etc/config/sing-box ] && cp -p /etc/config/sing-box "$WORK/etc/config/"
[ -f /etc/config/proxy-mode ] && cp -p /etc/config/proxy-mode "$WORK/etc/config/"
for f in /etc/sing-box/mode*.json; do
  [ -f "$f" ] || continue
  case "$f" in *-ipv6-block.json) continue ;; esac
  cp -p "$f" "$WORK/etc/sing-box/"
done

cat > "$WORK/MANIFEST.txt" <<EOF
Proxy Mode Suite configuration export
Created: $(date)
Source: $(cat /etc/openwrt_release 2>/dev/null | tr '\n' ' ')
Includes: UCI config + base mode JSON files
Excludes by default: generated IPv6-block files and SSH/private key files
EOF

tar -C "$WORK" -czf "$ARCHIVE" .
rm -rf "$WORK"
chmod 600 "$ARCHIVE"
echo "$ARCHIVE"
echo 'NOTE: SSH/private keys are intentionally excluded. Copy them separately only when necessary.'
