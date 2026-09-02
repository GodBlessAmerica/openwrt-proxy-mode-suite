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
FILES='/usr/bin/proxy-mode /usr/bin/proxy-mode-preflight /usr/libexec/proxy-mode-core /usr/libexec/proxy-mode-export /usr/libexec/proxy-mode-import /usr/libexec/proxy-mode-ui /etc/hotplug.d/iface/99-proxy-mode /usr/share/luci/menu.d/luci-app-proxy-mode.json /usr/share/rpcd/acl.d/luci-app-proxy-mode.json /www/luci-static/resources/view/proxy-mode.js /etc/config/proxy-mode'
for f in $FILES; do
  if [ -e "$f" ]; then mkdir -p "$BACKUP$(dirname "$f")"; cp -p "$f" "$BACKUP$f"; fi
done
for f in /etc/config/sing-box; do
  if [ -e "$f" ]; then mkdir -p "$BACKUP$(dirname "$f")"; cp -p "$f" "$BACKUP$f"; fi
done
printf '%s\n' "$BACKUP" > /etc/proxy-mode-suite-last-backup

mkdir -p /usr/bin /usr/libexec /etc/hotplug.d/iface /usr/share/luci/menu.d /usr/share/rpcd/acl.d /www/luci-static/resources/view
cp "$ROOT/scripts/proxy-mode-wrapper.sh" /usr/bin/proxy-mode
cp "$ROOT/scripts/preflight.sh" /usr/bin/proxy-mode-preflight
cp "$ROOT/core/usr/bin/proxy-mode" /usr/libexec/proxy-mode-core
cp "$ROOT/scripts/export-config.sh" /usr/libexec/proxy-mode-export
cp "$ROOT/scripts/import-config.sh" /usr/libexec/proxy-mode-import
cp "$ROOT/scripts/99-proxy-mode" /etc/hotplug.d/iface/99-proxy-mode
cp "$ROOT/luci-app-proxy-mode/usr/libexec/proxy-mode-ui" /usr/libexec/proxy-mode-ui
cp "$ROOT/luci-app-proxy-mode/usr/share/luci/menu.d/luci-app-proxy-mode.json" /usr/share/luci/menu.d/luci-app-proxy-mode.json
cp "$ROOT/luci-app-proxy-mode/usr/share/rpcd/acl.d/luci-app-proxy-mode.json" /usr/share/rpcd/acl.d/luci-app-proxy-mode.json
cp "$ROOT/luci-app-proxy-mode/www/luci-static/resources/view/proxy-mode.js" /www/luci-static/resources/view/proxy-mode.js
chmod 755 /usr/bin/proxy-mode /usr/bin/proxy-mode-preflight /usr/libexec/proxy-mode-core /usr/libexec/proxy-mode-export /usr/libexec/proxy-mode-import /usr/libexec/proxy-mode-ui /etc/hotplug.d/iface/99-proxy-mode

[ -f /etc/config/proxy-mode ] || cp "$ROOT/core/etc/config/proxy-mode" /etc/config/proxy-mode
if [ ! -f /etc/sing-box/mode1.json ] && [ "$(uci -q get proxy-mode.mode1.name 2>/dev/null || true)" = "Example Mode 1" ]; then
  uci -q delete proxy-mode.mode1 || true
  uci commit proxy-mode
fi
mkdir -p /etc/sing-box

RUNTIME_CONFIG="$(pgrep -af '/usr/bin/sing-box run' 2>/dev/null | sed -n 's#.*[[:space:]]-c[[:space:]]\([^[:space:]]*\).*#\1#p' | head -n 1 || true)"
SAVED_CONFIG="$(uci -q get sing-box.main.conffile 2>/dev/null || true)"
SELECTED_CONFIG=''

case "$RUNTIME_CONFIG" in
  /etc/sing-box/mode[0-9]*.json|/etc/sing-box/mode[0-9]*-ipv6-block.json)
    [ -f "$RUNTIME_CONFIG" ] && sing-box check -c "$RUNTIME_CONFIG" >/dev/null 2>&1 && SELECTED_CONFIG="$RUNTIME_CONFIG"
    ;;
esac

if [ -z "$SELECTED_CONFIG" ]; then
  case "$SAVED_CONFIG" in
    /etc/sing-box/mode[0-9]*.json|/etc/sing-box/mode[0-9]*-ipv6-block.json)
      [ -f "$SAVED_CONFIG" ] && sing-box check -c "$SAVED_CONFIG" >/dev/null 2>&1 && SELECTED_CONFIG="$SAVED_CONFIG"
      ;;
  esac
fi

if [ -z "$SELECTED_CONFIG" ] && [ -f /etc/sing-box/mode1.json ] && sing-box check -c /etc/sing-box/mode1.json >/dev/null 2>&1; then
  SELECTED_CONFIG='/etc/sing-box/mode1.json'
fi

uci -q get sing-box.main >/dev/null 2>&1 || uci set sing-box.main='sing-box'
uci set sing-box.main.user='root'
uci -q get sing-box.main.ipv6_mode >/dev/null 2>&1 || uci set sing-box.main.ipv6_mode='allow'
if [ -n "$SELECTED_CONFIG" ]; then
  uci set sing-box.main.conffile="$SELECTED_CONFIG"
  uci set sing-box.main.enabled='1'
else
  uci -q delete sing-box.main.conffile || true
  uci set sing-box.main.enabled='0'
  /etc/init.d/sing-box stop >/dev/null 2>&1 || true
fi
uci commit sing-box

# Proxy Mode owns boot sequencing. The official init script remains intact and is
# still used for manual start/restart, but is not allowed to start before WAN/WWAN.
/etc/init.d/sing-box disable >/dev/null 2>&1 || true

rm -f /tmp/luci-indexcache
rm -rf /tmp/luci-modulecache/* 2>/dev/null || true
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart

echo "Installed OpenWrt Proxy Mode Suite."
echo "Official sing-box service files were preserved."
echo "Proxy Mode owns sing-box boot sequencing; unconditional sing-box autostart is disabled."
if [ -n "$SELECTED_CONFIG" ]; then
  echo "Preserved managed mode: $SELECTED_CONFIG"
else
  echo "Fresh install: no managed mode found; Proxy Mode remains unconfigured."
fi
echo "Backup: $BACKUP"
echo "LuCI: Services -> Proxy Mode"
