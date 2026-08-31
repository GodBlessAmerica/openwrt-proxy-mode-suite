include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-proxy-mode
PKG_VERSION:=1.0.0
PKG_RELEASE:=2
PKG_LICENSE:=MIT
PKG_MAINTAINER:=GodBlessAmerica
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

SUITE_ROOT:=$(abspath $(CURDIR)/../..)

define Package/luci-app-proxy-mode
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI support for Proxy Mode Suite
  DEPENDS:=+proxy-mode-core +luci-base +rpcd-mod-file +uhttpd-mod-ubus
endef

define Package/luci-app-proxy-mode/description
 LuCI frontend for Proxy Mode Suite: status, dynamic mode management,
 IPv6 leak protection, service control and sing-box logs.
endef

define Build/Compile
endef

define Package/luci-app-proxy-mode/install
	$(INSTALL_DIR) $(1)/usr/libexec
	$(INSTALL_BIN) $(SUITE_ROOT)/luci-app-proxy-mode/usr/libexec/proxy-mode-ui $(1)/usr/libexec/proxy-mode-ui

	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) $(SUITE_ROOT)/luci-app-proxy-mode/usr/share/luci/menu.d/luci-app-proxy-mode.json $(1)/usr/share/luci/menu.d/luci-app-proxy-mode.json

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) $(SUITE_ROOT)/luci-app-proxy-mode/usr/share/rpcd/acl.d/luci-app-proxy-mode.json $(1)/usr/share/rpcd/acl.d/luci-app-proxy-mode.json

	$(INSTALL_DIR) $(1)/www/luci-static/resources/view
	$(INSTALL_DATA) $(SUITE_ROOT)/luci-app-proxy-mode/www/luci-static/resources/view/proxy-mode.js $(1)/www/luci-static/resources/view/proxy-mode.js
endef

define Package/luci-app-proxy-mode/postinst
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] && exit 0
rm -rf /tmp/luci-* /tmp/.uci 2>/dev/null || true
/etc/init.d/rpcd restart 2>/dev/null || true
/etc/init.d/uhttpd restart 2>/dev/null || true
exit 0
endef

$(eval $(call BuildPackage,luci-app-proxy-mode))
