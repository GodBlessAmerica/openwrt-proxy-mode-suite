#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
[ -f /etc/openwrt_release ] || { echo 'ERROR: OpenWrt not detected' >&2; exit 1; }
command -v sing-box >/dev/null 2>&1 || { echo 'ERROR: sing-box is not installed' >&2; exit 1; }
command -v uci >/dev/null 2>&1 || { echo 'ERROR: uci not found' >&2; exit 1; }
command -v jsonfilter >/dev/null 2>&1 || { echo 'ERROR: jsonfilter not found' >&2; exit 1; }
[ -d /usr/share/luci ] || { echo 'ERROR: LuCI not installed' >&2; exit 1; }

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/proxy-mode-suite-backup-$TS"
mkdir -p "$BACKUP"
FILES='/usr/bin/proxy-mode /usr/libexec/proxy-mode-ui /usr/share/luci/menu.d/luci-app-proxy-mode.json /usr/share/rpcd/acl.d/luci-app-proxy-mode.json /www/luci-static/resources/view/proxy-mode.js /etc/config/proxy-mode /etc/init.d/sing-box /etc/config/sing-box'
for f in $FILES; do
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
[ -f /etc/init.d/sing-box ] || { cp "$ROOT/core/etc/init.d/sing-box" /etc/init.d/sing-box; chmod 755 /etc/init.d/sing-box; }
[ -f /etc/config/sing-box ] || cp "$ROOT/core/etc/config/sing-box.example" /etc/config/sing-box
mkdir -p /etc/sing-box

rm -f /tmp/luci-indexcache
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart

echo "Installed OpenWrt Proxy Mode Suite."
echo "Backup: $BACKUP"
echo "LuCI: Services -> Proxy Mode"
