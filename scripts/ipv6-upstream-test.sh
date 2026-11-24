#!/bin/sh
# Test-only IPv6 upstream support. Keep all forwarded IPv6 blocked.
set -eu
cfg="${1:?configuration required}"
server="$(jsonfilter -i "$cfg" -e '@.outbounds[0].server')"
case "$server" in *:*) ;; *) exit 0;; esac
case "$server" in *[!0-9a-fA-F:]*) exit 1;; esac
port="$(jsonfilter -i "$cfg" -e '@.outbounds[0].server_port')"
case "$port" in ''|*[!0-9]*) exit 1;; esac
[ "$port" -ge 1 ] && [ "$port" -le 65535 ] || exit 1
[ "$(jsonfilter -i "$cfg" -e '@.outbounds[0].type')" = vless ] || exit 1
dev=""
for src in $(ip -6 addr show scope global | awk '/inet6 [23]/{if ($0 !~ /tentative|dadfailed|deprecated/) {split($2,a,"/");print a[1]}}'); do
    dev="$(ip -6 route get "$server" from "$src" 2>/dev/null | awk '{for(i=1;i<NF;i++)if($i=="dev"){print $(i+1);exit}}')"
    [ -z "$dev" ] || break
done
case "$dev" in ''|*[!a-zA-Z0-9_.-]*) echo 'IPv6 upstream route unavailable' >&2; exit 1;; esac
# Separate table persists across sing-box restarts; fail closed for forwarded IPv6.
# Allow only the selected upstream TCP endpoint and link control traffic on WAN.
nft list table inet proxy_mode_v6_test >/dev/null 2>&1 && del='delete table inet proxy_mode_v6_test' || del=''
nft -f - <<EOF
$del
table inet proxy_mode_v6_test {
 chain forward {
  type filter hook forward priority -150; policy accept;
  meta nfproto ipv6 drop
 }
 chain output {
  type filter hook output priority -150; policy accept;
  oifname "$dev" meta nfproto ipv6 ip6 daddr $server tcp dport $port accept
  oifname "$dev" icmpv6 type { nd-router-solicit, nd-neighbor-solicit, nd-neighbor-advert } accept
  oifname "$dev" ip6 daddr ff02::1:2 udp sport 546 udp dport 547 accept
  oifname "$dev" meta nfproto ipv6 drop
 }
}
EOF
# sing-box output chains are recreated on restart. Reinsert exceptions only
# after the chains exist; never add exceptions to prerouting.
for chain in output output_udp_icmp; do
    nft list chain inet sing-box "$chain" >/dev/null 2>&1 || exit 1
    nft insert rule inet sing-box "$chain" oifname "$dev" ip6 daddr "$server" tcp dport "$port" counter return
    nft insert rule inet sing-box "$chain" oifname "$dev" icmpv6 type '{ nd-router-solicit, nd-neighbor-solicit, nd-neighbor-advert }' counter return
    nft insert rule inet sing-box "$chain" oifname "$dev" ip6 daddr ff02::1:2 udp sport 546 udp dport 547 counter return
done
echo 'IPv6 upstream test rules installed'
