include $(TOPDIR)/rules.mk

PKG_NAME:=fanwrt-defaults
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=FanWRT

include $(INCLUDE_DIR)/package.mk

define Package/fanwrt-defaults
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=FanWRT defaults (PPE offload, MAC identity, diag)
  DEPENDS:=+kmod-nft-offload
endef

define Package/fanwrt-defaults/description
 FanWRT 默认项：防火墙 flow offload + PPE 硬件卸载、按 SoC 序列号派生 MAC、fanwrt-diag 诊断脚本。
endef

define Build/Compile
endef

define Package/fanwrt-defaults/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/99-fanwrt-defaults $(1)/etc/uci-defaults/99-fanwrt-defaults
	$(INSTALL_BIN) ./files/50-fanwrt-mac $(1)/etc/uci-defaults/50-fanwrt-mac
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/fanwrt-diag $(1)/usr/sbin/fanwrt-diag
endef

$(eval $(call BuildPackage,fanwrt-defaults))
