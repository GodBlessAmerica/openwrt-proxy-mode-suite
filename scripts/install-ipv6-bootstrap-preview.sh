#!/bin/sh
# Incremental preview only. Preserve configuration and running sing-box.
set -eu
umask 077
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
[ "$(id -u)" = 0 ] && [ -f /etc/openwrt_release ] || exit 1
[ -x /etc/init.d/proxy-mode-watchdog ] && [ -x /usr/libexec/proxy-mode-dns-bootstrap ] || { echo 'Existing v1.1.1 installation required'; exit 1; }
for f in ipv6-upstream ipv6-watchdog proxy-mode-wrapper; do sh -n "$ROOT/scripts/$f.sh"; done
B="$(mktemp -d /root/proxy-mode-v112-preview.XXXXXX)"
cp -p /usr/libexec/proxy-mode-ipv6-upstream "$B/upstream"
cp -p /usr/libexec/proxy-mode-ipv6-watchdog "$B/watchdog"
cp -p /usr/bin/proxy-mode "$B/wrapper"
cat > "$B/rollback.sh" <<'EOF'
#!/bin/sh
set -eu
B="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
/etc/init.d/proxy-mode-watchdog stop
cp -p "$B/upstream" /usr/libexec/proxy-mode-ipv6-upstream
cp -p "$B/watchdog" /usr/libexec/proxy-mode-ipv6-watchdog
cp -p "$B/wrapper" /usr/bin/proxy-mode
T="$(mktemp)"
trap 'rm -f "$T"' EXIT
for c in output output_udp_icmp; do
    nft -a list chain inet sing-box "$c" 2>/dev/null | awk -v c="$c" '/comment "proxy-mode-v6-bootstrap"/{print "delete rule inet sing-box " c " handle " $NF}' >> "$T"
done
[ ! -s "$T" ] || nft -f "$T"
/etc/init.d/proxy-mode-watchdog start
EOF
chmod 700 "$B/rollback.sh"
echo "Rollback: sh $B/rollback.sh"
/etc/init.d/proxy-mode-watchdog stop
if ! (
    set -e
    cp "$ROOT/scripts/ipv6-upstream.sh" /usr/libexec/proxy-mode-ipv6-upstream
    cp "$ROOT/scripts/ipv6-watchdog.sh" /usr/libexec/proxy-mode-ipv6-watchdog
    cp "$ROOT/scripts/proxy-mode-wrapper.sh" /usr/bin/proxy-mode
    chmod 755 /usr/libexec/proxy-mode-ipv6-upstream /usr/libexec/proxy-mode-ipv6-watchdog /usr/bin/proxy-mode
    /etc/init.d/proxy-mode-watchdog start
); then
    sh "$B/rollback.sh"
    exit 1
fi
echo 'Preview installed; sing-box was not restarted.'
echo "Rollback: sh $B/rollback.sh"
