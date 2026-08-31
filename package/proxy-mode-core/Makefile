include $(TOPDIR)/rules.mk

PKG_NAME:=proxy-mode-core
PKG_VERSION:=1.0.0
PKG_RELEASE:=3
PKG_LICENSE:=MIT
PKG_MAINTAINER:=GodBlessAmerica
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

SUITE_ROOT:=$(CURDIR)/..

define Package/proxy-mode-core
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=Dynamic sing-box mode manager for OpenWrt
  DEPENDS:=+sing-box +jsonfilter +uci
endef

define Package/proxy-mode-core/description
 Portable sing-box mode manager with dynamic modes, IPv6 leak protection,
 configuration validation, rollback-oriented behavior and migration helpers.
 This package intentionally relies on the official OpenWrt sing-box package
 for /usr/bin/sing-box, /etc/init.d/sing-box and /etc/config/sing-box.
endef

define Package/proxy-mode-core/conffiles
/etc/config/proxy-mode
endef

define Build/Compile
endef

define Package/proxy-mode-core/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(SUITE_ROOT)/core/usr/bin/proxy-mode $(1)/usr/bin/proxy-mode

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) $(SUITE_ROOT)/core/etc/config/proxy-mode $(1)/etc/config/proxy-mode

	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) $(SUITE_ROOT)/scripts/export-config.sh $(1)/usr/libexec/proxy-mode-export
	$(INSTALL_BIN) $(SUITE_ROOT)/scripts/import-config.sh $(1)/usr/libexec/proxy-mode-import
endef

define Package/proxy-mode-core/postinst
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] && exit 0
mkdir -p /etc/sing-box
# Reuse the official OpenWrt sing-box UCI service definition.
uci -q get sing-box.main >/dev/null 2>&1 || uci set sing-box.main='sing-box'
# Proxy Mode is designed around TUN-capable configurations, which require root.
uci set sing-box.main.user='root'
uci -q get sing-box.main.ipv6_mode >/dev/null 2>&1 || uci set sing-box.main.ipv6_mode='allow'
# On a fresh install do not start an empty proxy. If a valid mode1 already exists,
# make it the initial configuration and enable the service.
if [ -f /etc/sing-box/mode1.json ] && sing-box check -c /etc/sing-box/mode1.json >/dev/null 2>&1; then
	uci set sing-box.main.conffile='/etc/sing-box/mode1.json'
	uci set sing-box.main.enabled='1'
fi
uci commit sing-box
exit 0
endef

$(eval $(call BuildPackage,proxy-mode-core))
