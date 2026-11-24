#!/bin/sh
# Read-only IPv6 upstream diagnostics. No firewall or network changes.
set -u
section() { printf '\n===== %s =====\n' "$1"; }
section "IPv6 upstream addresses"
ip -6 addr show scope global
section "IPv6 routes"
ip -6 route show table all
section "IPv6 policy routing"
ip -6 rule show
section "IPv6 route lookup (no packets sent)"
ip -6 route get 2606:4700:4700::1111 2>&1 || :
section "IPv6 interface controls"
for d in /proc/sys/net/ipv6/conf/*; do
    [ -d "$d" ] || continue
    printf '%s ' "${d##*/}"
    for k in disable_ipv6 accept_ra forwarding; do
        printf '%s=%s ' "$k" "$(cat "$d/$k" 2>/dev/null || echo unavailable)"
    done
    printf '\n'
done
section "OpenWrt WAN/WWAN IPv6 state"
for i in wan wan6 wwan wwan6; do
    printf '%s: ' "$i"
    uci -q get "network.$i.proto" || echo unconfigured
    for k in up l3_device; do
        printf '  %s=' "$k"
        ubus call "network.interface.$i" status 2>/dev/null | jsonfilter -e "@.$k" 2>/dev/null || :
        printf '\n'
    done
done
section "DHCPv6 client"
pidof odhcp6c 2>/dev/null || echo "not running"
section "IPv6 guard rules and chain context"
nft list ruleset 2>/dev/null | awk '/^table / {t=$0} /^[[:space:]]*chain / {c=$0} /hook (output|forward)|nfproto ipv6|ip6 |icmpv6/ {print t " / " c " / " $0}'
section "Proxy configuration metadata"
printf 'guard='
uci -q get sing-box.main.ipv6_mode || :
printf 'upstream interfaces='
uci -q get sing-box.main.ifaces || :
sing-box version 2>/dev/null | head -n 2
