include $(TOPDIR)/rules.mk

PKG_NAME:=proxy-mode-core
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT
PKG_MAINTAINER:=GodBlessAmerica

include $(INCLUDE_DIR)/package.mk

define Package/proxy-mode-core
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=Dynamic sing-box mode manager for OpenWrt
  PKGARCH:=all
  DEPENDS:=+sing-box +jsonfilter +uci
endef

define Package/proxy-mode-core/description
 Portable sing-box mode manager with dynamic modes, IPv6 leak protection,
 configuration validation, rollback-oriented behavior and migration helpers.
endef

define Package/proxy-mode-core/conffiles
/etc/config/proxy-mode
/etc/config/sing-box
endef

define Build/Compile
endef

define Package/proxy-mode-core/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/proxy-mode $(1)/usr/bin/proxy-mode

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/sing-box $(1)/etc/init.d/sing-box

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/proxy-mode $(1)/etc/config/proxy-mode
	$(INSTALL_CONF) ./files/etc/config/sing-box $(1)/etc/config/sing-box

	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) ./files/usr/libexec/proxy-mode-export $(1)/usr/libexec/proxy-mode-export
	$(INSTALL_BIN) ./files/usr/libexec/proxy-mode-import $(1)/usr/libexec/proxy-mode-import
endef

$(eval $(call BuildPackage,proxy-mode-core))
