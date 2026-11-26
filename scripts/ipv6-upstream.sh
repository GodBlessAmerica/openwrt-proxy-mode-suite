#!/bin/sh
# Persistent IPv6 literal VLESS guard. No node or source addresses in logs.
set -eu
set -f
TABLE=proxy_mode_v6
# Maintain only link-local control traffic on explicitly configured DHCPv6
# uplinks. No public endpoint exception and no modification of LAN forwarding.
if [ "${1:-}" = bootstrap ]; then
    tmp="$(mktemp /tmp/proxy-v6-bootstrap.XXXXXX)"
    trap 'rm -f "$tmp"' EXIT
    devices=''
    lan="$(ubus call network.interface.lan status 2>/dev/null | jsonfilter -e '@.l3_device')"
    [ -n "$lan" ] || exit 1
    for iface in $(uci show network | sed -n "s/^network\.\([a-zA-Z0-9_]*\)\.proto='dhcpv6'$/\1/p"); do
        dev="$(ubus call "network.interface.$iface" status 2>/dev/null | jsonfilter -e '@.device')"
        case "$dev" in ''|*[!a-zA-Z0-9_.-]*) continue;; esac
        [ "$dev" != "$lan" ] || continue
        # Restrict to the current IPv4 default uplink.
        ip -4 route show default | awk -v d="$dev" '{for(i=1;i<NF;i++)if($i=="dev" && $(i+1)==d)ok=1} END{exit !ok}' || continue
        case " $devices " in *" $dev "*) continue;; esac
        devices="$devices $dev"
    done
    for chain in output output_udp_icmp; do
        rules="$(nft -a list chain inet sing-box "$chain" 2>/dev/null)" || exit 1
        # Only touch our own tagged rules. Avoid churn when exact rules already exist.
        desired=0
        for dev in $devices; do desired=$((desired+2)); done
        actual="$(printf '%s\n' "$rules" | grep -c 'comment "proxy-mode-v6-bootstrap"' || true)"
        good=1
        [ "$actual" = "$desired" ] || good=0
        for dev in $devices; do
            n="$(printf '%s\n' "$rules" | grep -F "oifname \"$dev\"" | grep -c 'comment "proxy-mode-v6-bootstrap"' || true)"
            [ "$n" = 2 ] || good=0
        done
        [ "$good" = 0 ] || continue
        printf '%s\n' "$rules" | awk -v c="$chain" '/comment "proxy-mode-v6-bootstrap"/{print "delete rule inet sing-box " c " handle " $NF}' >> "$tmp"
        for dev in $devices; do
            printf 'insert rule inet sing-box %s oifname "%s" ip6 hoplimit 255 icmpv6 type { nd-router-solicit, nd-neighbor-solicit, nd-neighbor-advert } counter return comment "proxy-mode-v6-bootstrap"\n' "$chain" "$dev" >> "$tmp"
            printf 'insert rule inet sing-box %s oifname "%s" ip6 daddr { fe80::/10, ff02::1:2 } udp sport 546 udp dport 547 counter return comment "proxy-mode-v6-bootstrap"\n' "$chain" "$dev" >> "$tmp"
        done
    done
    [ ! -s "$tmp" ] || nft -f "$tmp"
    exit
fi
cfg="$1"
action="$2"
server="$(jsonfilter -i "$cfg" -e '@.outbounds[0].server' 2>/dev/null || true)"
case "$server" in *:*) ;; *) exit 2;; esac
case "$server" in *[!0-9a-fA-F:]*) exit 1;; esac
port="$(jsonfilter -i "$cfg" -e '@.outbounds[0].server_port')"
case "$port" in ''|*[!0-9]*) exit 1;; esac
[ "$port" -ge 1 ] && [ "$port" -le 65535 ] || exit 1
[ "$(jsonfilter -i "$cfg" -e '@.outbounds[0].type')" = vless ] || exit 1
jq -e '([.inbounds[] | select(.type=="tun")] | length==1) and ([.inbounds[] | select(.type=="tun" and .auto_route==true and .auto_redirect==true) | select(.address|type=="array") | select([.address[] | contains(":")] | any | not)] | length==1)' "$cfg" >/dev/null || exit 1
lan="$(ubus call network.interface.lan status | jsonfilter -e '@.l3_device')"
case "$lan" in ''|*[!a-zA-Z0-9_.-]*) exit 1;; esac
dev=""
for src in $(ip -6 addr show scope global | awk '/inet6 [23]/{if ($0 !~ /tentative|dadfailed|deprecated/) {split($2,a,"/");print a[1]}}'); do
    dev="$(ip -6 route get "$server" from "$src" 2>/dev/null | awk '{for(i=1;i<NF;i++)if($i=="dev"){print $(i+1);exit}}')"
    [ -z "$dev" ] || break
done
case "$dev" in ''|*[!a-zA-Z0-9_.-]*) echo 'IPv6 upstream route unavailable' >&2; exit 1;; esac
[ "$lan" != "$dev" ] || exit 1
if [ "$action" = guard ]; then
    del=''
    if nft list table inet "$TABLE" >/dev/null 2>&1; then del="delete table inet $TABLE"; fi
    nft -f - <<EOF
$del
table inet $TABLE {
 chain forward {
  type filter hook forward priority -160; policy accept;
  meta nfproto ipv6 counter drop
 }
 chain output {
  type filter hook output priority -160; policy accept;
  meta nfproto ipv6 oifname { "lo", "$lan" } accept
  oifname "$dev" ip6 daddr $server tcp dport $port counter accept
  oifname "$dev" icmpv6 type { nd-router-solicit, nd-neighbor-solicit, nd-neighbor-advert } accept
  oifname "$dev" meta nfproto ipv6 udp sport 546 udp dport 547 accept
  meta nfproto ipv6 counter drop
 }
}
EOF
    exit
fi
[ "$action" = apply ] || exit 1
nft list table inet "$TABLE" >/dev/null 2>&1 || exit 1
# Replace only our own exceptions atomically, including after procd respawn.
tmp="$(mktemp /tmp/proxy-v6-rules.XXXXXX)"
trap 'rm -f "$tmp"' EXIT
for chain in output output_udp_icmp; do
    rules="$(nft -a list chain inet sing-box "$chain")" || exit 1
    printf '%s\n' "$rules" | awk -v c="$chain" '/comment "proxy-mode-v6"/{print "delete rule inet sing-box " c " handle " $NF}' >> "$tmp"
    printf 'insert rule inet sing-box %s oifname "%s" icmpv6 type { nd-router-solicit, nd-neighbor-solicit, nd-neighbor-advert } counter return comment "proxy-mode-v6"\n' "$chain" "$dev" >> "$tmp"
    printf 'insert rule inet sing-box %s oifname "%s" meta nfproto ipv6 udp sport 546 udp dport 547 counter return comment "proxy-mode-v6"\n' "$chain" "$dev" >> "$tmp"
done
printf 'insert rule inet sing-box output oifname "%s" ip6 daddr %s tcp dport %s counter return comment "proxy-mode-v6"\n' "$dev" "$server" "$port" >> "$tmp"
nft -f "$tmp"
