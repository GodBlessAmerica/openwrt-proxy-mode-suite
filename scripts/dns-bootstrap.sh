#!/bin/sh
# Normalize only simple single-hop or two-hop IPv4-domain VLESS profiles with one proxied DoH.
# No network requests; no credentials printed. Input/output are local files.
set -eu
umask 077
f="$1"
t="$(mktemp "$f.bootstrap.XXXXXX")"
trap 'rm -f "$t"' EXIT
jq '
  def eligible:
    ([.outbounds[]? | select(.type == "vless")] | length) as $n |
    (.outbounds[0].tag) as $a |
    (.route.final) as $final |
    (.outbounds | type == "array") and
    ($n == 1 or $n == 2) and
    (.outbounds[0] | .type == "vless" and (.detour // "") == "" and
      (.domain_resolver == null) and (.server | type == "string" and
        test("^[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)+$") and
        (test("^[0-9.]+$") | not))) and
    ($a != null and $final != null) and
    (if $n == 1 then $final == $a else
      $final != $a and
      ([.outbounds[] | select(.type == "vless" and .tag == $final and .detour == $a)] | length == 1)
    end) and
    (.route.default_domain_resolver == null) and
    (.dns.servers | type == "array" and length == 1) and
    (.dns.servers[0].type == "https") and
    (.dns.servers[0].detour == .route.final) and
    (.dns.servers[0].tag != "dns-bootstrap") and
    ((.dns.final // .dns.servers[0].tag) == .dns.servers[0].tag) and
    ((.dns.rules // []) | length == 0) and
    ((.dns.strategy // "ipv4_only") == "ipv4_only");
  if eligible then
    .dns.final = .dns.servers[0].tag |
    .dns.servers += [{"type":"https","tag":"dns-bootstrap","server":"223.5.5.5","server_port":443,"path":"/dns-query","tls":{"enabled":true,"server_name":"dns.alidns.com"}}] |
    .dns.strategy = "ipv4_only" |
    .outbounds[0].domain_resolver = {"server":"dns-bootstrap","strategy":"ipv4_only"} |
    .route.default_domain_resolver = {"server":"dns-bootstrap","strategy":"ipv4_only"} |
    .inbounds |= map(if .type == "tun" and .auto_route == true and
      ((.route_exclude_address // []) | length == 1 and (.[0] | type == "string" and test("^[0-9]+\\\\.[0-9]+\\\\.[0-9]+\\\\.[0-9]+/32$")))
      then del(.route_exclude_address) else . end)
  else . end
' "$f" > "$t"
# Preserve the original bytes when no semantic change was needed.
if jq -e --slurp '.[0] == .[1]' "$f" "$t" >/dev/null; then exit 0; fi
sing-box check -c "$t" >/dev/null || exit 1
mv "$t" "$f"
