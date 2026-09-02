include $(TOPDIR)/rules.mk

PKG_NAME:=proxy-mode-core
PKG_VERSION:=1.0.0
PKG_RELEASE:=13
PKG_LICENSE:=MIT
PKG_MAINTAINER:=GodBlessAmerica
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

SUITE_ROOT:=$(abspath $(CURDIR)/../..)

define Package/proxy-mode-core
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=Dynamic sing-box mode manager for OpenWrt
  DEPENDS:=+jsonfilter +uci
endef

define Package/proxy-mode-core/description
 Portable sing-box mode manager with dynamic modes, IPv6 leak protection,
 configuration validation, rollback-oriented behavior and migration helpers.
 The suite requires the official OpenWrt sing-box package at runtime, but does
 not declare a hard Kconfig dependency on it because OpenWrt exposes sing-box
 as full/tiny variants and provider resolution can create a recursive Kconfig
 dependency in SDK package-only builds. Install the full sing-box package first.
endef

define Package/proxy-mode-core/conffiles
/etc/config/proxy-mode
endef

define Build/Compile
endef

define Package/proxy-mode-core/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(SUITE_ROOT)/scripts/proxy-mode-wrapper.sh $(1)/usr/bin/proxy-mode
	$(INSTALL_BIN) $(SUITE_ROOT)/scripts/preflight.sh $(1)/usr/bin/proxy-mode-preflight

	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) $(SUITE_ROOT)/core/usr/bin/proxy-mode $(1)/usr/libexec/proxy-mode-core
	$(INSTALL_BIN) $(SUITE_ROOT)/scripts/export-config.sh $(1)/usr/libexec/proxy-mode-export
	$(INSTALL_BIN) $(SUITE_ROOT)/scripts/import-config.sh $(1)/usr/libexec/proxy-mode-import

	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) $(SUITE_ROOT)/scripts/99-proxy-mode $(1)/etc/hotplug.d/iface/99-proxy-mode

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) $(SUITE_ROOT)/core/etc/config/proxy-mode $(1)/etc/config/proxy-mode
endef

define Package/proxy-mode-core/postinst
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] && exit 0
if ! command -v sing-box >/dev/null 2>&1; then
	echo "proxy-mode-core: sing-box is required; install the official OpenWrt sing-box package first" >&2
	exit 1
fi
mkdir -p /etc/sing-box
uci -q get sing-box.main >/dev/null 2>&1 || uci set sing-box.main='sing-box'
uci set sing-box.main.user='root'
uci -q get sing-box.main.ipv6_mode >/dev/null 2>&1 || uci set sing-box.main.ipv6_mode='allow'

runtime_conffile="$$(pgrep -af '/usr/bin/sing-box run' 2>/dev/null | sed -n 's#.*[[:space:]]-c[[:space:]]\([^[:space:]]*\).*#\1#p' | head -n 1 || true)"
saved_conffile="$$(uci -q get sing-box.main.conffile 2>/dev/null || true)"
selected_conffile=''

case "$$runtime_conffile" in
	/etc/sing-box/mode[0-9]*.json|/etc/sing-box/mode[0-9]*-ipv6-block.json)
		[ -f "$$runtime_conffile" ] && sing-box check -c "$$runtime_conffile" >/dev/null 2>&1 && selected_conffile="$$runtime_conffile"
		;;
esac

if [ -z "$$selected_conffile" ]; then
	case "$$saved_conffile" in
		/etc/sing-box/mode[0-9]*.json|/etc/sing-box/mode[0-9]*-ipv6-block.json)
			[ -f "$$saved_conffile" ] && sing-box check -c "$$saved_conffile" >/dev/null 2>&1 && selected_conffile="$$saved_conffile"
			;;
	esac
fi

if [ -z "$$selected_conffile" ] && [ -f /etc/sing-box/mode1.json ] && sing-box check -c /etc/sing-box/mode1.json >/dev/null 2>&1; then
	selected_conffile='/etc/sing-box/mode1.json'
fi

if [ -n "$$selected_conffile" ]; then
	uci set sing-box.main.conffile="$$selected_conffile"
	uci set sing-box.main.enabled='1'
else
	uci -q delete sing-box.main.conffile || true
	uci set sing-box.main.enabled='0'
	/etc/init.d/sing-box stop >/dev/null 2>&1 || true
fi
uci commit sing-box
# Proxy Mode owns boot sequencing and starts sing-box only after the configured
# WAN/WWAN is ready. Keep the official init implementation, disable rc.d autostart.
/etc/init.d/sing-box disable >/dev/null 2>&1 || true
exit 0
endef

$(eval $(call BuildPackage,proxy-mode-core))
