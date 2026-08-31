#!/bin/sh
set -eu

BACKUP=''
[ ! -f /etc/proxy-mode-suite-last-backup ] || BACKUP="$(cat /etc/proxy-mode-suite-last-backup)"
rm -f /usr/libexec/proxy-mode-ui
rm -f /usr/share/luci/menu.d/luci-app-proxy-mode.json
rm -f /usr/share/rpcd/acl.d/luci-app-proxy-mode.json
rm -f /www/luci-static/resources/view/proxy-mode.js

if [ -n "$BACKUP" ] && [ -d "$BACKUP" ]; then
  for f in /usr/bin/proxy-mode /etc/config/proxy-mode /etc/init.d/sing-box /etc/config/sing-box; do
    if [ -e "$BACKUP$f" ]; then mkdir -p "$(dirname "$f")"; cp -p "$BACKUP$f" "$f"; fi
  done
  echo "Restored available original files from $BACKUP"
else
  echo 'No installer backup found; core files and mode data were left in place.'
fi
rm -f /tmp/luci-indexcache
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
echo 'LuCI integration removed. /etc/sing-box mode data was not deleted.'
