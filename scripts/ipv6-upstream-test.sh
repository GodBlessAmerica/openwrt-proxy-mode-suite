#!/bin/sh
# Reversible IPv6 VLESS TUN preview; credentials stay on the router.
set -eu
set -f
umask 077
SERVICE=/etc/init.d/sing-box
LOCK=/tmp/proxy-mode-recover.lock
TABLE=proxy_mode_v6_test
fail() { echo "ERROR: $*" >&2; exit 1; }
for cmd in jq nft ip jsonfilter sing-box uci ubus; do
    command -v "$cmd" >/dev/null 2>&1 || fail "Missing dependency: $cmd"
done
[ -t 0 ] || fail 'Run interactively in SSH.'
[ "$(uci -q get sing-box.main.ipv6_mode || true)" != block ] || fail 'Preview requires existing allow mode; firewall configuration is not changed.'
[ "$(uci -q get sing-box.main.enabled || true)" = 1 ] || fail 'Start an existing managed mode first.'
base="$(uci -q get sing-box.main.conffile)"
case "$base" in /etc/sing-box/mode[0-9]*.json) ;; *) fail 'No active managed base mode';; esac
[ -r "$base" ] || fail 'Base mode unavailable'
jq -e '(.outbounds[0].tag | type=="string") and ([.inbounds[] | select(.type=="tun")] | length==1) and ([.inbounds[] | select(.type=="tun") | select(.auto_route==true and .auto_redirect==true and (.address|type=="array") and ([.address[] | contains(":")] | any | not))] | length==1)' "$base" >/dev/null || fail 'Requires one IPv4-only auto-redirect TUN and tagged first outbound'
if nft list table inet "$TABLE" >/dev/null 2>&1; then fail 'Test guard already exists; recover previous test first.'; fi
printf 'Paste IPv6 VLESS Reality URI and press Enter (hidden): '
stty -echo
trap 'stty echo 2>/dev/null || true' EXIT
trap 'exit 130' HUP INT TERM
IFS= read -r uri
stty echo
printf '\n'
case "$uri" in vless://*@\[*\]:*\?*) ;; *) fail 'Expected vless://UUID@[IPv6]:PORT?...';; esac
authority="${uri#vless://}"
uuid="${authority%%@*}"
rest="${authority#*@}"
hostport="${rest%%\?*}"
query="${rest#*\?}"
query="${query%%#*}"
server="${hostport%%]*}"
server="${server#\[}"
port="${hostport##*:}"
case "$uuid" in ''|*[!0-9a-fA-F-]*) fail 'Invalid UUID';; esac
case "$server" in ''|*[!0-9a-fA-F:]*) fail 'Invalid IPv6 literal';; esac
case "$server" in *:*) ;; *) fail 'IPv6 literal required';; esac
case "$port" in ''|*[!0-9]*) fail 'Invalid port';; esac
[ "$port" -ge 1 ] && [ "$port" -le 65535 ] || fail 'Invalid port'
sni= pbk= sid= flow= security= transport= fp= encryption=
oldifs="$IFS"; IFS='&'
for item in $query; do
    key="${item%%=*}"; val="${item#*=}"
    case "$key" in
        sni) sni="$val";; pbk) pbk="$val";; sid) sid="$val";;
        flow) flow="$val";; security) security="$val";;
        type) transport="$val";; fp) fp="$val";; encryption) encryption="$val";;
    esac
done
IFS="$oldifs"
[ "$security" = reality ] && [ "$transport" = tcp ] && [ "$flow" = xtls-rprx-vision ] && [ "$encryption" = none ] || fail 'Only TCP Reality Vision supported'
[ "$fp" = chrome ] || fail 'Requires chrome fingerprint'
case "$sni" in ''|*[!a-zA-Z0-9.-]*) fail 'Invalid SNI';; esac
case "$pbk" in ''|*[!a-zA-Z0-9_-]*) fail 'Invalid public key';; esac
case "$sid" in *[!a-fA-F0-9]*) fail 'Invalid short ID';; esac
unset uri authority rest query hostport item val
dev=""
for src in $(ip -6 addr show scope global | awk '/inet6 [23]/{if ($0 !~ /tentative|dadfailed|deprecated/) {split($2,a,"/");print a[1]}}'); do
    dev="$(ip -6 route get "$server" from "$src" 2>/dev/null | awk '{for(i=1;i<NF;i++)if($i=="dev"){print $(i+1);exit}}')"
    [ -z "$dev" ] || break
done
case "$dev" in ''|*[!a-zA-Z0-9_.-]*) fail 'No IPv6 upstream route; WAN6/WWAN6 must already be up';; esac
lan="$(ubus call network.interface.lan status | jsonfilter -e '@.l3_device')"
case "$lan" in ''|*[!a-zA-Z0-9_.-]*) fail 'Cannot identify LAN interface';; esac
[ "$lan" != "$dev" ] || fail 'Upstream and LAN must differ'
workdir="$(uci -q get sing-box.main.workdir || true)"
workdir="${workdir:-/usr/share/sing-box}"
mkdir "$LOCK" 2>/dev/null || fail 'Another recovery operation active'
tmp=""
pid=""
stopped=0
guard=0
cleanup() {
    trap - EXIT HUP INT TERM
    stty echo 2>/dev/null || true
    if [ -n "$pid" ]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
    restored=1
    if [ "$stopped" -eq 1 ]; then
        echo 'Restoring original mode...'
        if "$SERVICE" start; then
            sleep 3
            if ! pgrep -f '/usr/bin/sing-box run' >/dev/null 2>&1; then restored=0; fi
        else restored=0; fi
    fi
    if [ "$guard" -eq 1 ] && [ "$restored" -eq 1 ]; then
        nft delete table inet "$TABLE" || true
    elif [ "$guard" -eq 1 ]; then
        echo 'Original service not restored; IPv6 guard retained.' >&2
    fi
    [ -z "$tmp" ] || rm -rf "$tmp"
    rmdir "$LOCK" 2>/dev/null || true
    [ "$restored" -eq 1 ] || exit 1
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM
tmp="$(mktemp -d /tmp/proxy-mode-v6.XXXXXX)"
oldserver="$(jq -r '.outbounds[0].server // ""' "$base")"
jq --arg server "$server" --argjson port "$port" --arg uuid "$uuid" --arg sni "$sni" --arg pbk "$pbk" --arg sid "$sid" --arg old "$oldserver/32" '
 .outbounds[0] = {type:"vless",tag:.outbounds[0].tag,server:$server,server_port:$port,uuid:$uuid,flow:"xtls-rprx-vision",packet_encoding:"xudp",tls:{enabled:true,server_name:$sni,utls:{enabled:true,fingerprint:"chrome"},reality:{enabled:true,public_key:$pbk,short_id:$sid}}}
 | (.inbounds[] | select(.type=="tun")) |= (if (.route_exclude_address|type)=="array" then .route_exclude_address |= map(select(.!=$old)) else . end)
 | .route.auto_detect_interface=true
' "$base" > "$tmp/config.json"
unset uuid pbk sid sni
sing-box check -c "$tmp/config.json" -D "$workdir" >/dev/null || fail 'Temporary config failed validation'
nft -f - <<EOF
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
guard=1
stopped=1
"$SERVICE" stop || fail 'Cannot stop original service'
sleep 2
if pgrep -f '/usr/bin/sing-box run' >/dev/null 2>&1; then fail 'Original process did not stop'; fi
/usr/bin/sing-box run -c "$tmp/config.json" -D "$workdir" > "$tmp/sing-box.log" 2>&1 &
pid=$!
i=0
while [ "$i" -lt 15 ]; do
    kill -0 "$pid" 2>/dev/null || fail 'Temporary TUN failed to start'
    if nft list chain inet sing-box output >/dev/null 2>&1 && nft list chain inet sing-box output_udp_icmp >/dev/null 2>&1; then break; fi
    sleep 1; i=$((i+1))
done
[ "$i" -lt 15 ] || fail 'Expected sing-box nftables chains missing'
nft -f - <<EOF
insert rule inet sing-box output oifname "$dev" ip6 daddr $server tcp dport $port counter return
insert rule inet sing-box output oifname "$dev" icmpv6 type { nd-router-solicit, nd-neighbor-solicit, nd-neighbor-advert } counter return
insert rule inet sing-box output oifname "$dev" meta nfproto ipv6 udp sport 546 udp dport 547 counter return
insert rule inet sing-box output_udp_icmp oifname "$dev" icmpv6 type { nd-router-solicit, nd-neighbor-solicit, nd-neighbor-advert } counter return
insert rule inet sing-box output_udp_icmp oifname "$dev" meta nfproto ipv6 udp sport 546 udp dport 547 counter return
EOF
kill -0 "$pid" 2>/dev/null || fail 'Temporary sing-box exited'
echo 'IPv6 upstream TUN preview active; independent IPv6 guard installed.'
echo 'Keep SSH open. Test Internet from a LAN client.'
echo 'Do not switch modes or restart networking during this test.'
echo 'Press Enter to stop preview and restore original mode.'
IFS= read -r _
echo 'Test IPv6 guard counters:'
nft list chain inet "$TABLE" forward || true
echo 'Test completed.'
