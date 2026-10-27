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
  TITLE:=FanWRT defaults (PPE hardware flow offload)
  DEPENDS:=+kmod-nft-offload
endef

define Package/fanwrt-defaults/description
 FanWRT 默认项：打开防火墙 flow offload，并启用硬件卸载（IPQ5332 PPE）。
endef

define Build/Compile
endef

define Package/fanwrt-defaults/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/99-fanwrt-defaults $(1)/etc/uci-defaults/99-fanwrt-defaults
endef

$(eval $(call BuildPackage,fanwrt-defaults))
