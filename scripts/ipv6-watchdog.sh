#!/bin/sh
# Reconcile missing exceptions without restarting sing-box.
# Never remove the independent guard in the watchdog.
umask 077
HELPER=/usr/libexec/proxy-mode-ipv6-upstream
last=''
while :; do
    cfg="$(uci -q get sing-box.main.conffile 2>/dev/null)"
    case "$cfg" in /etc/sing-box/mode[0-9]*.json) ;; *) cfg='';; esac
    if [ -n "$cfg" ] && [ "$(uci -q get sing-box.main.enabled)" = 1 ] &&
        [ ! -d /tmp/proxy-mode-recover.lock ] &&
        pgrep -af "^/usr/bin/sing-box run " | grep -F -- " -c $cfg " >/dev/null 2>&1; then
        if mkdir /tmp/proxy-mode-switch.lock 2>/dev/null; then
            if [ "$(uci -q get sing-box.main.conffile)" = "$cfg" ]; then
                "$HELPER" bootstrap >/dev/null 2>&1 || true
            fi
            rmdir /tmp/proxy-mode-switch.lock
        fi
    fi
    if [ -n "$cfg" ] && [ "$(uci -q get sing-box.main.enabled)" = 1 ] &&
        [ "$(jsonfilter -i "$cfg" -e '@.outbounds[0].type' 2>/dev/null)" = vless ]; then
        case "$(jsonfilter -i "$cfg" -e '@.outbounds[0].server' 2>/dev/null)" in
            *:*)
                if [ ! -d /tmp/proxy-mode-recover.lock ] &&
                    [ ! -d /tmp/proxy-mode-switch.lock ] &&
                    pgrep -af "^/usr/bin/sing-box run " | grep -F -- " -c $cfg " >/dev/null 2>&1; then
                    a="$(nft list chain inet sing-box output 2>/dev/null | grep -c 'comment "proxy-mode-v6"')"
                    b="$(nft list chain inet sing-box output_udp_icmp 2>/dev/null | grep -c 'comment "proxy-mode-v6"')"
                    if [ "$a" != 3 ] || [ "$b" != 2 ] || ! nft list table inet proxy_mode_v6 >/dev/null 2>&1; then
                        if mkdir /tmp/proxy-mode-switch.lock 2>/dev/null; then
                            if [ "$(uci -q get sing-box.main.conffile)" = "$cfg" ] &&
                                "$HELPER" "$cfg" guard >/dev/null 2>&1 &&
                                "$HELPER" "$cfg" apply >/dev/null 2>&1; then
                                logger -t proxy-mode-v6 'Missing IPv6 exceptions restored'
                                last=''
                            elif [ "$last" != failed ]; then
                                logger -t proxy-mode-v6 'IPv6 reconciliation pending; will retry'
                                last=failed
                            fi
                            rmdir /tmp/proxy-mode-switch.lock
                        fi
                    fi
                fi
                ;;
        esac
    fi
    sleep 3
done
