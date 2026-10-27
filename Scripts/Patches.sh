#!/bin/bash
# FanWRT 源码补丁，在 ./wrt（OpenWrt 源码根）里执行
#
# 方案照抄 WoChen5770/openwrt_build 的赵云（jdcloud-re-cs-06）处理：
#   Patches/jdcloud-re-cs-06-emmc-mac-nvmem.patch   必需
#     block/block-device/partname="factory" → gpt-partitions + partname="0:ART"
#   Patches/jdcloud-re-cs-06-lzma-kernel.patch      标记文件 Config/LZMA_KERNEL 开启
#     FitImage → FitImageLzma（保留 7MiB 内核槽位，需 U-Boot 支持 LZMA/FIT）
#   Patches/dawn-runtime-fixes.patch                标记文件 Config/DAWN_PATCH 开启
#
# 额外保险层（我们加的，默认开，放 Config/NO_FIXED_MAC 可关）：
#   Patches/jdcloud-re-cs-06-fixed-mac.patch
#     6 处 nvmem MAC 消费者 → DT 的 mac-address，彻底不依赖任何分区
#
# 可选：Scripts/ppe-pppoe-fix.py（QCA4B tagged PPPoE，按内容自适应上游改名）
#
# 注意：判断"是否已打"用 grep 标记文件，而不是 patch -R 反向 dry-run ——
# 实测 GNU patch 对未打补丁的文件做反向 dry-run 也可能返回 0，会误判成"已存在"。

set -uo pipefail

PATCH_DIR="$GITHUB_WORKSPACE/Patches"
FLAG_DIR="$GITHUB_WORKSPACE/Config"
DTS="target/linux/qualcommbe/dts/ipq5322-re-cs-06.dts"
IMAGE_MK="target/linux/qualcommbe/image/ipq53xx.mk"

# APPLY <名称> <文件> <目标路径> <grep 标记>
APPLY() {
	local NAME="$1" FILE="$2" TARGET="$3" MARK="$4"

	echo " "
	echo "== $NAME"

	if [ ! -f "$FILE" ]; then
		echo "   ERROR: 缺少补丁文件 $FILE"
		exit 1
	fi

	if [ -f "$TARGET" ] && grep -q "$MARK" "$TARGET"; then
		echo "   已生效，跳过"
		return 0
	fi

	if patch -p1 --forward --batch --no-backup-if-mismatch <"$FILE"; then
		echo "   OK"
	else
		echo "   ERROR: $NAME 应用失败（上游结构可能已变化，见上面的 .rej 输出）"
		exit 1
	fi

	if grep -q "$MARK" "$TARGET"; then
		echo "   校验通过"
	else
		echo "   ERROR: 打完仍找不到标记 [$MARK]，终止"
		exit 1
	fi
}

TRY_APPLY() {
	local NAME="$1" FILE="$2" TARGET="$3" MARK="$4"

	echo " "
	echo "== $NAME (optional)"
	if [ ! -f "$FILE" ]; then
		echo "   没有该补丁文件，跳过"
		return 0
	fi
	if [ -f "$TARGET" ] && grep -q "$MARK" "$TARGET"; then
		echo "   已生效，跳过"
		return 0
	fi
	if patch -p1 --forward --batch --no-backup-if-mismatch <"$FILE"; then
		echo "   OK"
	else
		echo "   跳过（上下文不匹配，不影响网口）"
	fi
}

# ---- 照抄部分 ----
APPLY "jdcloud-re-cs-06-emmc-mac-nvmem.patch" \
	"$PATCH_DIR/jdcloud-re-cs-06-emmc-mac-nvmem.patch" \
	"$DTS" 'partname = "0:ART";'

if [ -f "$FLAG_DIR/LZMA_KERNEL" ]; then
	APPLY "jdcloud-re-cs-06-lzma-kernel.patch" \
		"$PATCH_DIR/jdcloud-re-cs-06-lzma-kernel.patch" \
		"$IMAGE_MK" 'Device/FitImageLzma'
else
	echo " "
	echo "== lzma-kernel 跳过（需 U-Boot 支持 LZMA/FIT；放 Config/LZMA_KERNEL 开启）"
fi

if [ -f "$FLAG_DIR/DAWN_PATCH" ]; then
	TRY_APPLY "dawn-runtime-fixes.patch" \
		"$PATCH_DIR/dawn-runtime-fixes.patch" \
		"feeds/luci/applications/luci-app-dawn" 'DAWN runtime fixes'
fi

# ---- 保险层 ----
if [ -f "$FLAG_DIR/NO_FIXED_MAC" ]; then
	echo " "
	echo "== fixed-mac 跳过（存在 Config/NO_FIXED_MAC）"
else
	APPLY "jdcloud-re-cs-06-fixed-mac.patch" \
		"$PATCH_DIR/jdcloud-re-cs-06-fixed-mac.patch" \
		"$DTS" 'mac-address = \[02 46 57 00 00 01\]'
fi

# ---- 可选：PPPoE ----
echo " "
echo "== ppe-pppoe-fix.py (optional)"
if python3 "$GITHUB_WORKSPACE/Scripts/ppe-pppoe-fix.py"; then
	echo "   OK"
else
	echo "   跳过（上游 PPE/PPPoE 代码结构已变化，不影响有线口）"
fi
