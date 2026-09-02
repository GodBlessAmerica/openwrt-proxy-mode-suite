include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-proxy-mode
PKG_VERSION:=1.0.0
PKG_RELEASE:=6
PKG_LICENSE:=MIT
PKG_MAINTAINER:=GodBlessAmerica
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

# OpenWrt follows the package symlink and runs make with CURDIR at the real
# checkout path: <repo>/package/luci-app-proxy-mode. Therefore the repository
# root is two directories above CURDIR.
SUITE_ROOT:=$(abspath $(CURDIR)/../..)

define Package/luci-app-proxy-mode
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI support for Proxy Mode Suite
  DEPENDS:=+proxy-mode-core
endef

define Package/luci-app-proxy-mode/description
 LuCI frontend for Proxy Mode Suite: status dashboard, dynamic mode management,
 IPv6 leak protection, service control and sing-box logs.
 This package ships static LuCI assets and an RPC helper only. It intentionally
 does not hard-select luci-base at build time so SDK package builds do not try to
 rebuild the complete LuCI/lucihttp stack. Install it on an OpenWrt system that
 already has LuCI, rpcd and uhttpd.
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
if [ ! -d /usr/share/luci ] || [ ! -x /etc/init.d/rpcd ] || [ ! -x /etc/init.d/uhttpd ]; then
	echo "luci-app-proxy-mode: LuCI, rpcd and uhttpd must already be installed" >&2
	exit 1
fi
rm -rf /tmp/luci-* /tmp/.uci 2>/dev/null || true
/etc/init.d/rpcd restart 2>/dev/null || true
/etc/init.d/uhttpd restart 2>/dev/null || true
exit 0
endef

$(eval $(call BuildPackage,luci-app-proxy-mode))
