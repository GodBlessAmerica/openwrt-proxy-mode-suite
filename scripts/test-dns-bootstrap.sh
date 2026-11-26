#!/bin/sh
# Offline regression: mock only sing-box validation, never use real nodes.
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
D="$(mktemp -d)"
trap 'rm -rf "$D"' EXIT
mkdir "$D/bin"
printf '#!/bin/sh\nexit 0\n' > "$D/bin/sing-box"
chmod +x "$D/bin/sing-box"
PATH="$D/bin:$PATH"; export PATH
cat > "$D/raw" <<'JSON'
{"dns":{"servers":[{"type":"https","tag":"remote","server":"1.1.1.1","detour":"b"}]},"inbounds":[{"type":"tun","auto_route":true,"route_exclude_address":["192.0.2.1/32"]}],"outbounds":[{"type":"vless","tag":"a","server":"node.example.com"},{"type":"vless","tag":"b","server":"198.51.100.1","detour":"a"},{"type":"direct","tag":"direct"}],"route":{"final":"b"}}
JSON
cp "$D/raw" "$D/chain"
sh "$ROOT/scripts/dns-bootstrap.sh" "$D/chain" --backup
jq -e '.dns.final=="remote" and .dns.strategy=="ipv4_only" and .outbounds[0].domain_resolver.server=="dns-bootstrap" and .route.default_domain_resolver.server=="dns-bootstrap" and .outbounds[1].detour=="a" and .dns.servers[0].detour=="b" and (.inbounds[0]|has("route_exclude_address")|not)' "$D/chain" >/dev/null
cp "$D/chain" "$D/once"
sh "$ROOT/scripts/dns-bootstrap.sh" "$D/chain"
cmp "$D/once" "$D/chain"
for addr in 192.0.2.2 2001:db8::1; do
 jq --arg a "$addr" '.outbounds[0].server=$a' "$D/raw" > "$D/literal"
 cp "$D/literal" "$D/before"
 sh "$ROOT/scripts/dns-bootstrap.sh" "$D/literal"
 cmp "$D/before" "$D/literal"
done
jq '.outbounds |= map(select(.tag!="b")) | .route.final="a" | .dns.servers[0].detour="a"' "$D/raw" > "$D/single"
sh "$ROOT/scripts/dns-bootstrap.sh" "$D/single"
jq -e '.outbounds[0].domain_resolver.server=="dns-bootstrap"' "$D/single" >/dev/null
jq '.inbounds[0].route_exclude_address += ["10.0.0.0/8"]' "$D/raw" > "$D/custom"
sh "$ROOT/scripts/dns-bootstrap.sh" "$D/custom"
jq -e '(.inbounds[0].route_exclude_address|length)==2' "$D/custom" >/dev/null
printf '#!/bin/sh\nexit 1\n' > "$D/bin/sing-box"
cp "$D/raw" "$D/fail"
if sh "$ROOT/scripts/dns-bootstrap.sh" "$D/fail"; then exit 1; fi
cmp "$D/raw" "$D/fail"
echo 'DNS bootstrap regression: PASS (offline; sing-box check mocked)'
