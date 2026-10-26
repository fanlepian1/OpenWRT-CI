# FanWRT 本地 kmod
#
# 背景：immortalwrt 的 package/kernel/linux/modules/usb.mk 里
#   define KernelPackage/usb-printer
#     DEPENDS:=printer-support
# 而 printer-support 这个 Kconfig 符号在本源码树里没有定义，
# 于是 qualcommbe/ipq53xx 上 CONFIG_PACKAGE_kmod-usb-printer 根本不存在，
# 连带 luci-app-usb-printer 也被依赖剪掉、/dev/usb/lp0 不会生成。
#
# 这里用同样的 KCONFIG / FILES / AUTOLOAD 重建一份，去掉那个悬空的 DEPENDS，
# 于是 usblp.ko 能正常编出来，p910nd / luci-app-usb-printer 才有设备可用。

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=kmod-usb-printer
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define KernelPackage/usb-printer
  SUBMENU:=USB Support
  TITLE:=Support for USB printers
  DEPENDS:=+kmod-usb-core
  KCONFIG:=CONFIG_USB_PRINTER
  FILES:= \
	$(LINUX_DIR)/drivers/usb/class/usblp.ko
  AUTOLOAD:=$(call AutoProbe,usblp)
endef

define KernelPackage/usb-printer/description
 Kernel support for USB printers (usblp, creates /dev/usb/lp0)
endef

$(eval $(call KernelPackage,usb-printer))
