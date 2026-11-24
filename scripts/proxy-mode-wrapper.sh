#!/bin/sh

CORE="/usr/libexec/proxy-mode-core"
SERVICE="/etc/init.d/sing-box"
UCI_KEY="sing-box.main.conffile"
HEALTH_HOST="openwrt.org"
WAIT_SECONDS=45

is_ipv4() {
    printf '%s\n' "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
}

configured_ifaces() {
    uci -q get sing-box.main.ifaces 2>/dev/null || true
}

iface_is_up() {
    iface="$1"
    [ -n "$iface" ] || return 1
    [ "$(ubus call "network.interface.$iface" status 2>/dev/null | jsonfilter -e '@.up' 2>/dev/null)" = "true" ]
}

upstream_ready() {
    ip -4 route 2>/dev/null | grep -q '^default ' || return 1
    ifaces="$(configured_ifaces)"
    [ -n "$ifaces" ] || return 0
    for iface in $ifaces; do
        iface_is_up "$iface" && return 0
    done
    return 1
}

wait_upstream() {
    waited=0
    while [ "$waited" -lt "$WAIT_SECONDS" ]; do
        upstream_ready && return 0
        sleep 1
        waited=$((waited + 1))
    done
    return 1
}

dns_healthy() {
    upstream_ready || return 1
    nslookup "$HEALTH_HOST" 127.0.0.1 >/dev/null 2>&1
}

mode_number_from_config() {
    basename -- "$1" 2>/dev/null | sed -n 's/^mode\([0-9][0-9]*\)\(-ipv6-block\)\{0,1\}\.json$/\1/p'
}

enable_service() {
    [ "$(uci -q get sing-box.main.enabled 2>/dev/null)" = "1" ] || {
        uci set sing-box.main.enabled='1'
        uci commit sing-box
    }
    # Proxy Mode owns boot sequencing; keep the official service disabled from
    # unconditional rc.d boot while still using its start/restart implementation.
    "$SERVICE" disable >/dev/null 2>&1 || true
}

sync_route_exclude_for_mode() {
    number="$1"
    base="/etc/sing-box/mode${number}.json"
    [ -f "$base" ] || return 0

    server="$(jsonfilter -i "$base" -e '@.outbounds[0].server' 2>/dev/null)"
    is_ipv4 "$server" || return 0
    expected="${server}/32"

    if grep -Eq '"route_exclude_address"[[:space:]]*:[[:space:]]*\[[[:space:]]*"([0-9]{1,3}\.){3}[0-9]{1,3}/32"[[:space:]]*\]' "$base"; then
        current="$(sed -n 's/.*"route_exclude_address"[[:space:]]*:[[:space:]]*\[[[:space:]]*"\([0-9.]*\/32\)"[[:space:]]*\].*/\1/p' "$base" | head -n1)"
        [ "$current" = "$expected" ] && return 0
        tmp="${base}.route.$$"
        sed "s#\(\"route_exclude_address\"[[:space:]]*:[[:space:]]*\)\[[[:space:]]*\"[0-9.]*\/32\"[[:space:]]*\]#\1[\"$expected\"]#" "$base" > "$tmp" || return 1
        if sing-box check -c "$tmp" >/dev/null 2>&1; then
            chmod 600 "$tmp"
            mv "$tmp" "$base"
            rm -f "/etc/sing-box/mode${number}-ipv6-block.json"
            echo "路由排除已同步：${current:-未设置} → $expected"
        else
            rm -f "$tmp"
            echo "警告：自动同步 route_exclude_address 后配置校验失败，已保留原文件。" >&2
            return 1
        fi
    fi
}

show_health() {
    ifaces="$(configured_ifaces)"
    if upstream_ready; then
        echo "上游网络：正常（${ifaces:-default route}）"
        default_route="$(ip -4 route 2>/dev/null | grep '^default ' | head -n1)"
        [ -n "$default_route" ] && echo "默认路由：$default_route"
        if dns_healthy; then
            echo "DNS 健康：正常"
        else
            echo "DNS 健康：异常（本机 127.0.0.1:53 无法解析 $HEALTH_HOST）"
        fi
    else
        echo "上游网络：未就绪（等待 ${ifaces:-默认路由}）"
        echo "DNS 健康：未检测"
    fi

    current="$(uci -q get "$UCI_KEY" 2>/dev/null)"
    number="$(mode_number_from_config "$current")"
    [ -n "$number" ] || return 0
    base="/etc/sing-box/mode${number}.json"
    [ -f "$base" ] || return 0
    server="$(jsonfilter -i "$base" -e '@.outbounds[0].server' 2>/dev/null)"
    if is_ipv4 "$server"; then
        expected="${server}/32"
        exclude="$(sed -n 's/.*"route_exclude_address"[[:space:]]*:[[:space:]]*\[[[:space:]]*"\([0-9.]*\/32\)"[[:space:]]*\].*/\1/p' "$base" | head -n1)"
        if [ -n "$exclude" ] && [ "$exclude" != "$expected" ]; then
            echo "路由排除：异常（当前 $exclude，应为 $expected）"
        elif [ -n "$exclude" ]; then
            echo "路由排除：正常（$exclude）"
        fi
    fi
}


V6=/usr/libexec/proxy-mode-ipv6-upstream
is_v6_mode() {
    case "$(jsonfilter -i "$1" -e '@.outbounds[0].server' 2>/dev/null)" in *:*) return 0;; *) return 1;; esac
}
v6_apply() {
    i=0
    while [ "$i" -lt 15 ]; do
        "$V6" "$1" apply 2>/dev/null && return 0
        sleep 1
        i=$((i+1))
    done
    return 1
}
v6_clear() {
    if nft list table inet proxy_mode_v6 >/dev/null 2>&1; then
        nft delete table inet proxy_mode_v6
    fi
}
v6_restart() {
    cfg="$1"
    [ "$(uci -q get sing-box.main.ipv6_mode)" != block ] || {
        echo "IPv6 upstream requires allow policy; independent LAN IPv6 guard remains active." >&2
        return 1
    }
    # IPv4-only TUN must not prefer unreachable IPv6 destinations.
    if [ "$(jsonfilter -i "$cfg" -e '@.dns.strategy' 2>/dev/null)" != ipv4_only ]; then
        (
            umask 077
            tmp="$(mktemp "$cfg.dns.XXXXXX")" || exit 1
            trap 'rm -f "$tmp"' EXIT
            jq '.dns.strategy = "ipv4_only"' "$cfg" > "$tmp" &&
            sing-box check -c "$tmp" >/dev/null &&
            cp -p "$cfg" "$cfg.before-ipv6-dns" &&
            chmod 600 "$cfg.before-ipv6-dns" "$tmp" &&
            mv "$tmp" "$cfg"
        ) || return 1
    fi
    sing-box check -c "$cfg" >/dev/null || return 1
    "$V6" "$cfg" guard || return 1
    enable_service || return 1
    uci set "$UCI_KEY=$cfg" && uci commit sing-box || return 1
    "$SERVICE" restart || return 1
    v6_apply "$cfg" || return 1
    sleep 5
    "$V6" "$cfg" guard && v6_apply "$cfg" || return 1
    dns_healthy
}
v6_switch() {
    target="$1"
    previous="$(uci -q get "$UCI_KEY" 2>/dev/null)"
    if v6_restart "$target"; then
        echo "IPv6 upstream started; independent LAN IPv6 guard active."
        return 0
    fi
    echo "IPv6 upstream failed; restoring previous mode." >&2
    if [ -n "$previous" ] && [ -f "$previous" ] && [ "$previous" != "$target" ]; then
        if is_v6_mode "$previous"; then
            v6_restart "$previous" || return 1
        else
            uci set "$UCI_KEY=$previous" && uci commit sing-box &&
            "$SERVICE" restart && sleep 3 && dns_healthy && v6_clear
        fi
    fi
    return 1
}

recover_current() {
    active="$(uci -q get "$UCI_KEY" 2>/dev/null)"
    if is_v6_mode "$active"; then v6_restart "$active"; return $?; fi
    if ! wait_upstream; then
        echo "上游网络在 ${WAIT_SECONDS}s 内未就绪，暂不重启代理。" >&2
        return 1
    fi
    current="$(uci -q get "$UCI_KEY" 2>/dev/null)"
    number="$(mode_number_from_config "$current")"
    [ -n "$number" ] || { echo "当前没有已配置模式，跳过恢复。"; return 0; }
    sync_route_exclude_for_mode "$number"
    enable_service || return 1
    "$CORE" restart || return 1
    sleep 2
    if dns_healthy; then
        echo "代理已在上游网络就绪后恢复。"
        return 0
    fi
    echo "代理已启动，但 DNS 健康检查失败。" >&2
    return 1
}

switch_safely() {
    number="$1"
    target="/etc/sing-box/mode$number.json"
    if is_v6_mode "$target"; then v6_switch "$target"; return $?; fi
    if ! wait_upstream; then
        echo "错误：上游网络尚未就绪，取消模式切换。" >&2
        return 1
    fi

    old_config="$(uci -q get "$UCI_KEY" 2>/dev/null)"
    sync_route_exclude_for_mode "$number" || return 1
    enable_service || return 1
    "$CORE" "$number" || return 1
    sleep 2

    if dns_healthy; then
        v6_clear
        return 0
    fi

    echo "错误：新模式启动后 DNS 健康检查失败，正在回滚。" >&2
    if [ -n "$old_config" ] && [ -f "$old_config" ] && [ "$old_config" != "$(uci -q get "$UCI_KEY" 2>/dev/null)" ]; then
        uci set "$UCI_KEY=$old_config"
        uci commit sing-box
        if is_v6_mode "$old_config"; then v6_restart "$old_config" || return 1; else "$SERVICE" restart; sleep 3; fi
        echo "已恢复原配置：$old_config" >&2
    fi
    return 1
}

case "${1:-}" in
    ipv6-test)
        exec /usr/libexec/proxy-mode-ipv6-test
        ;;
    ipv6)
        active="$(uci -q get "$UCI_KEY" 2>/dev/null)"
        if is_v6_mode "$active"; then
            case "${2:-status}" in
                block|allow|status) echo "IPv6 upstream: LAN IPv6 blocked by independent guard; upstream endpoint allowed."; nft list table inet proxy_mode_v6 >/dev/null 2>&1; exit $?;;
            esac
        fi
        exec "$CORE" "$@"
        ;;
    status)
        if nft list table inet proxy_mode_v6 >/dev/null 2>&1; then echo "IPv6 upstream guard: active"; fi
        if [ -z "$(uci -q get "$UCI_KEY" 2>/dev/null)" ]; then
            "$CORE" status | sed 's/^当前模式：未知模式$/当前模式：未配置/'
        else
            "$CORE" status
        fi
        show_health
        ;;
    health)
        show_health
        dns_healthy
        ;;
    recover)
        recover_current
        ;;
    start|restart)
        active="$(uci -q get "$UCI_KEY" 2>/dev/null)"
        if is_v6_mode "$active"; then v6_restart "$active"; exit $?; fi
        if ! wait_upstream; then
            echo "错误：上游网络在 ${WAIT_SECONDS}s 内未就绪。" >&2
            exit 1
        fi
        current="$(uci -q get "$UCI_KEY" 2>/dev/null)"
        number="$(mode_number_from_config "$current")"
        [ -n "$number" ] || { echo "错误：当前没有已配置模式。" >&2; exit 1; }
        sync_route_exclude_for_mode "$number"
        enable_service || exit 1
        "$CORE" "$1"
        ;;
    ''|*[!0-9]*)
        exec "$CORE" "$@"
        ;;
    *)
        switch_safely "$1"
        ;;
esac
