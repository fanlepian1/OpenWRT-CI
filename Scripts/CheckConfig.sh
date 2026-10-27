#!/bin/bash
# 配置门禁（照 WoChen5770 的 required / expected_config 思路）
# 在 make defconfig 之后跑：必需项缺一个、或补丁没生效，就让构建失败，
# 避免"编译成功但功能没进去"的静默问题。

set -uo pipefail

CFG=".config"
FAIL=0

need() {
	local SYM="$1"
	if grep -qx "$SYM" "$CFG"; then
		echo "  OK   $SYM"
	else
		echo "  MISS $SYM"
		FAIL=1
	fi
}

forbid() {
	local SYM="$1"
	if grep -qx "$SYM" "$CFG"; then
		echo "  BAD  $SYM（不应存在）"
		FAIL=1
	else
		echo "  ok   $SYM 不在"
	fi
}

echo "== 平台/设备 =="
need "CONFIG_TARGET_qualcommbe=y"
need "CONFIG_TARGET_qualcommbe_ipq53xx=y"
need "CONFIG_TARGET_DEVICE_qualcommbe_ipq53xx_DEVICE_jdcloud_re-cs-06=y"

echo "== 网络加速 =="
need "CONFIG_PACKAGE_kmod-nft-offload=y"
need "CONFIG_PACKAGE_kmod-nft-queue=y"
need "CONFIG_PACKAGE_kmod-sched-bpf=y"

echo "== 我们自己加的包 =="
need "CONFIG_PACKAGE_luci-app-giwifi=y"
need "CONFIG_PACKAGE_fanwrt-defaults=y"
need "CONFIG_PACKAGE_ua3f=y"
need "CONFIG_PACKAGE_luci-app-homeproxy=y"
need "CONFIG_PACKAGE_adguardhome=y"
need "CONFIG_PACKAGE_luci-app-adguardhome=y"
need "CONFIG_PACKAGE_luci-theme-argon=y"
need "CONFIG_PACKAGE_luci-app-argon-config=y"
need "CONFIG_PACKAGE_luci-app-upnp=y"
need "CONFIG_PACKAGE_miniupnpd-nftables=y"
need "CONFIG_PACKAGE_kmod-usb-printer=y"
need "CONFIG_PACKAGE_luci-app-usb-printer=y"

echo "== 软检查（有就更好，缺了不拦）=="
for SYM in CONFIG_PACKAGE_kmod-tcp-bbr CONFIG_PACKAGE_kmod-sched CONFIG_PACKAGE_ipq-wifi-jdcloud_re-cs-06; do
	if grep -qx "${SYM}=y" "$CFG"; then
		echo "  OK   $SYM"
	else
		echo "  --   $SYM 未出现在 .config（可能由 DEVICE_PACKAGES/Kconfig 内部处理）"
	fi
done

echo "== 不应出现 =="
forbid "CONFIG_PACKAGE_luci-app-fanmac=y"
forbid "CONFIG_PACKAGE_luci-theme-aurora=y"

echo "== 补丁是否真的生效 =="
DTS="target/linux/qualcommbe/dts/ipq5322-re-cs-06.dts"
if grep -q 'compatible = "gpt-partitions";' "$DTS"; then
	echo "  OK   DTS: gpt-partitions (0:ART)"
else
	echo "  MISS DTS: gpt-partitions 未生效"
	FAIL=1
fi

if [ -f "$GITHUB_WORKSPACE/Config/NO_FIXED_MAC" ]; then
	echo "  --   fixed-mac 已关闭（Config/NO_FIXED_MAC）"
elif grep -q 'mac-address = \[02 46 57' "$DTS"; then
	echo "  OK   DTS: fixed mac-address"
else
	echo "  MISS DTS: fixed mac-address 未生效"
	FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
	echo
	echo "ERROR: 配置门禁未通过，终止构建"
	exit 1
fi

echo
echo "配置门禁全部通过"
