#!/bin/sh
# Read-only readiness check for a literal IPv6 upstream.
# Never prints the node address, credentials, or local addresses.
set -eu
cfg="${1:-}"
[ -r "$cfg" ] || { echo 'Configuration unavailable' >&2; exit 2; }
server="$(jsonfilter -i "$cfg" -e '@.outbounds[0].server' 2>/dev/null || true)"
case "$server" in
    *:*) ;;
    *) echo 'IPv6 literal upstream not detected in first outbound'; exit 2 ;;
esac
case "$server" in
    *[!0-9a-fA-F:]*) echo 'Unsupported IPv6 literal format' >&2; exit 2 ;;
esac
# A source-specific default route may make an unbound route lookup fail
# even when an actual TCP connection works. Try each usable global source.
for src in $(ip -6 addr show scope global | awk '/inet6 [23]/{if ($0 !~ /tentative|dadfailed|deprecated/) {split($2,a,"/"); print a[1]}}'); do
    if ip -6 route get "$server" from "$src" >/dev/null 2>&1; then
        echo 'IPv6 source-specific route available (TCP connectivity not tested)'
        exit 0
    fi
done
echo 'No usable IPv6 source-specific route found' >&2
exit 1
