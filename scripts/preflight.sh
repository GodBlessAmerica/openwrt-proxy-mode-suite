#!/bin/sh
set -u

ok=1
pass() { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*"; ok=0; }

printf '%s\n' 'OpenWrt Proxy Mode Suite - Preflight'
printf '%s\n' '===================================='

if [ -f /etc/openwrt_release ]; then
  . /etc/openwrt_release
  pass "OpenWrt detected: ${DISTRIB_RELEASE:-unknown} (${DISTRIB_TARGET:-unknown})"
else
  fail '/etc/openwrt_release not found'
fi

arch="$(uname -m 2>/dev/null || echo unknown)"
printf 'Architecture: %s\n' "$arch"

if command -v apk >/dev/null 2>&1; then
  pass "Package manager: apk ($(apk --version 2>/dev/null | head -n1))"
elif command -v opkg >/dev/null 2>&1; then
  pass 'Package manager: opkg'
else
  fail 'Neither apk nor opkg found'
fi

for cmd in uci jsonfilter ubus; do
  if command -v "$cmd" >/dev/null 2>&1; then pass "$cmd found"; else fail "$cmd missing"; fi
done

if command -v sing-box >/dev/null 2>&1; then
  ver="$(sing-box version 2>/dev/null | head -n1 || true)"
  pass "sing-box found: ${ver:-version unknown}"
else
  fail 'sing-box missing'
fi

[ -x /etc/init.d/sing-box ] && pass 'official sing-box init script found' || fail '/etc/init.d/sing-box missing'
[ -f /etc/config/sing-box ] && pass 'sing-box UCI config found' || fail '/etc/config/sing-box missing'

if [ -d /usr/share/luci ]; then pass 'LuCI found'; else fail 'LuCI missing'; fi
command -v rpcd >/dev/null 2>&1 && pass 'rpcd found' || warn 'rpcd command not found in PATH'
[ -e /usr/libexec/rpcd ] && pass 'rpcd runtime found' || warn '/usr/libexec/rpcd not found'
[ -f /usr/share/rpcd/acl.d/luci-base.json ] && pass 'LuCI RPC ACL directory available' || warn 'LuCI RPC ACL baseline not found'

if [ -c /dev/net/tun ]; then
  pass '/dev/net/tun available'
elif [ -e /dev/net/tun ]; then
  warn '/dev/net/tun exists but is not a character device'
else
  fail '/dev/net/tun missing (TUN modes will not work)'
fi

if grep -qw tun /proc/modules 2>/dev/null; then
  pass 'tun kernel module loaded'
else
  warn 'tun module not listed; it may be built into the kernel'
fi

if command -v nft >/dev/null 2>&1; then
  pass 'nftables command found'
else
  warn 'nft command missing; firewall integration may depend on the firmware build'
fi

printf '\nCurrent sing-box UCI state:\n'
uci -q show sing-box.main 2>/dev/null || warn 'sing-box.main UCI section not readable'

printf '\nExisting Proxy Mode configs:\n'
found=0
for f in /etc/sing-box/mode[0-9]*.json; do
  [ -f "$f" ] || continue
  case "$f" in *-ipv6-block.json) continue ;; esac
  found=1
  if sing-box check -c "$f" >/dev/null 2>&1; then
    pass "$f"
  else
    fail "$f fails sing-box check"
  fi
done
[ "$found" -eq 1 ] || warn 'No base modeN.json files found yet'

printf '\n'
if [ "$ok" -eq 1 ]; then
  pass 'Preflight completed: compatible baseline detected'
  exit 0
fi
fail 'Preflight completed with blocking problems'
exit 1
