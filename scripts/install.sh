#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
[ -f /etc/openwrt_release ] || { echo 'ERROR: OpenWrt not detected' >&2; exit 1; }
command -v sing-box >/dev/null 2>&1 || { echo 'ERROR: sing-box is not installed' >&2; exit 1; }
command -v uci >/dev/null 2>&1 || { echo 'ERROR: uci not found' >&2; exit 1; }
command -v jsonfilter >/dev/null 2>&1 || { echo 'ERROR: jsonfilter not found' >&2; exit 1; }
[ -x /etc/init.d/sing-box ] || { echo 'ERROR: official /etc/init.d/sing-box not found' >&2; exit 1; }
[ -f /etc/config/sing-box ] || { echo 'ERROR: official /etc/config/sing-box not found' >&2; exit 1; }
[ -d /usr/share/luci ] || { echo 'ERROR: LuCI not installed' >&2; exit 1; }

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/proxy-mode-suite-backup-$TS"
mkdir -p "$BACKUP"
FILES='/usr/bin/proxy-mode /usr/libexec/proxy-mode-ui /usr/share/luci/menu.d/luci-app-proxy-mode.json /usr/share/rpcd/acl.d/luci-app-proxy-mode.json /www/luci-static/resources/view/proxy-mode.js /etc/config/proxy-mode'
for f in $FILES; do
  if [ -e "$f" ]; then mkdir -p "$BACKUP$(dirname "$f")"; cp -p "$f" "$BACKUP$f"; fi
done
# Keep a copy of official sing-box UCI state for rollback/reference, but never replace
# the official package-owned init script or config file from this repository.
for f in /etc/config/sing-box; do
  if [ -e "$f" ]; then mkdir -p "$BACKUP$(dirname "$f")"; cp -p "$f" "$BACKUP$f"; fi
done
printf '%s\n' "$BACKUP" > /etc/proxy-mode-suite-last-backup

mkdir -p /usr/bin /usr/libexec /usr/share/luci/menu.d /usr/share/rpcd/acl.d /www/luci-static/resources/view
cp "$ROOT/core/usr/bin/proxy-mode" /usr/bin/proxy-mode
cp "$ROOT/luci-app-proxy-mode/usr/libexec/proxy-mode-ui" /usr/libexec/proxy-mode-ui
cp "$ROOT/luci-app-proxy-mode/usr/share/luci/menu.d/luci-app-proxy-mode.json" /usr/share/luci/menu.d/luci-app-proxy-mode.json
cp "$ROOT/luci-app-proxy-mode/usr/share/rpcd/acl.d/luci-app-proxy-mode.json" /usr/share/rpcd/acl.d/luci-app-proxy-mode.json
cp "$ROOT/luci-app-proxy-mode/www/luci-static/resources/view/proxy-mode.js" /www/luci-static/resources/view/proxy-mode.js
chmod 755 /usr/bin/proxy-mode /usr/libexec/proxy-mode-ui

[ -f /etc/config/proxy-mode ] || cp "$ROOT/core/etc/config/proxy-mode" /etc/config/proxy-mode
mkdir -p /etc/sing-box

# Preserve the live mode during reinstall. A running sing-box process is the strongest
# source of truth, followed by the saved UCI path. Only fall back to mode1 on a fresh
# installation where neither of those points to a valid configuration.
RUNTIME_CONFIG="$(pgrep -af '/usr/bin/sing-box run' 2>/dev/null | sed -n 's#.*[[:space:]]-c[[:space:]]\([^[:space:]]*\).*#\1#p' | head -n 1 || true)"
SAVED_CONFIG="$(uci -q get sing-box.main.conffile 2>/dev/null || true)"
SELECTED_CONFIG=''

if [ -n "$RUNTIME_CONFIG" ] && [ -f "$RUNTIME_CONFIG" ] && sing-box check -c "$RUNTIME_CONFIG" >/dev/null 2>&1; then
  SELECTED_CONFIG="$RUNTIME_CONFIG"
elif [ -n "$SAVED_CONFIG" ] && [ -f "$SAVED_CONFIG" ] && sing-box check -c "$SAVED_CONFIG" >/dev/null 2>&1; then
  SELECTED_CONFIG="$SAVED_CONFIG"
elif [ -f /etc/sing-box/mode1.json ] && sing-box check -c /etc/sing-box/mode1.json >/dev/null 2>&1; then
  SELECTED_CONFIG='/etc/sing-box/mode1.json'
fi

uci set sing-box.main.user='root'
uci -q get sing-box.main.ipv6_mode >/dev/null 2>&1 || uci set sing-box.main.ipv6_mode='allow'
if [ -n "$SELECTED_CONFIG" ]; then
  uci set sing-box.main.conffile="$SELECTED_CONFIG"
  uci set sing-box.main.enabled='1'
fi
uci commit sing-box

rm -f /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache/* 2>/dev/null || true
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart

echo "Installed OpenWrt Proxy Mode Suite."
echo "Official sing-box service files were preserved."
[ -z "$SELECTED_CONFIG" ] || echo "Preserved active config: $SELECTED_CONFIG"
echo "Backup: $BACKUP"
echo "LuCI: Services -> Proxy Mode"
