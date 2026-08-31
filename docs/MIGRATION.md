# Migration to a new OpenWrt router

The migration model separates **software** from **private configuration**.

## Recommended workflow

On the old router:

```sh
cd /path/to/openwrt-proxy-mode-suite
chmod +x scripts/export-config.sh
./scripts/export-config.sh /tmp
```

Copy the resulting `proxy-mode-backup-*.tar.gz` to a trusted computer or directly to the new router.

The default export includes:

- `/etc/config/sing-box`
- `/etc/config/proxy-mode`
- base `/etc/sing-box/modeN.json` files

It deliberately excludes:

- generated `modeN-ipv6-block.json` files
- SSH private keys
- unrelated files in `/etc/sing-box`

If a mode relies on an SSH key, copy that key separately over a trusted channel and restore its original path and permissions (`chmod 600`). Never commit it to this repository.

## New router

1. Install a compatible sing-box build and required OpenWrt kernel/network dependencies.
2. Install this suite with `scripts/install.sh`.
3. Copy the private export archive to the router.
4. Import it:

```sh
chmod +x scripts/import-config.sh
./scripts/import-config.sh /tmp/proxy-mode-backup-YYYYMMDD-HHMMSS.tar.gz
```

The importer validates every base mode with `sing-box check` before replacing the current configuration. It creates a rollback snapshot under `/root/` first.

## Hardware/interface differences

A configuration can be syntactically valid but still need adaptation when moving to different hardware. Check especially:

- UCI interface name (`wan`, `wwan`, `wwan-home`, etc.)
- TUN interface settings
- LAN subnet and route exclusions
- firewall zones
- DNS listening addresses
- architecture-specific sing-box package
- kernel modules and nftables/firewall4 behavior

After import run:

```sh
proxy-mode status
proxy-mode restart
logread -l 100 -e sing-box
```

Then verify the public IPv4/IPv6 and DNS behavior from a LAN client before considering the migration complete.

## Disaster recovery

The migration scripts are not a substitute for a complete OpenWrt backup. For an important router, keep both:

- an OpenWrt system backup for device-specific settings;
- a Proxy Mode export for portable sing-box mode data.
