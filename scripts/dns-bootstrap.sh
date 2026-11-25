#!/bin/sh
# Normalize only simple IPv4-domain VLESS profiles with one proxied DoH.
# No network requests; no credentials printed. Input/output are local files.
set -eu
umask 077
f="$1"
t="$(mktemp "$f.bootstrap.XXXXXX")"
trap 'rm -f "$t"' EXIT
jq '
  def eligible:
    (.outbounds | type == "array") and
    ([.outbounds[] | select(.type == "vless")] | length == 1) and
    (.outbounds[0] | .type == "vless" and (.detour // "") == "" and
      (.domain_resolver == null) and (.server | type == "string" and
        test("^[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)+$") and
        (test("^[0-9.]+$") | not))) and
    (.route.final == .outbounds[0].tag) and
    (.route.default_domain_resolver == null) and
    (.dns.servers | type == "array" and length == 1) and
    (.dns.servers[0].type == "https") and
    (.dns.servers[0].detour == .outbounds[0].tag) and
    (.dns.servers[0].tag != "dns-bootstrap") and
    ((.dns.final // .dns.servers[0].tag) == .dns.servers[0].tag) and
    ((.dns.rules // []) | length == 0) and
    ((.dns.strategy // "ipv4_only") == "ipv4_only");
  if eligible then
    .dns.final = .dns.servers[0].tag |
    .dns.servers += [{"type":"https","tag":"dns-bootstrap","server":"223.5.5.5","server_port":443,"path":"/dns-query","tls":{"enabled":true,"server_name":"dns.alidns.com"}}] |
    .dns.strategy = "ipv4_only" |
    .outbounds[0].domain_resolver = {"server":"dns-bootstrap","strategy":"ipv4_only"} |
    .route.default_domain_resolver = {"server":"dns-bootstrap","strategy":"ipv4_only"}
  else . end
' "$f" > "$t"
# Preserve the original bytes when no semantic change was needed.
if jq -e --slurp '.[0] == .[1]' "$f" "$t" >/dev/null; then exit 0; fi
sing-box check -c "$t" >/dev/null || exit 1
mv "$t" "$f"
