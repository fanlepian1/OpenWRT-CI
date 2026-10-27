#!/bin/bash
# FanWRT 源码补丁，在 ./wrt（OpenWrt 源码根）里执行
#
# 方案照抄 WoChen5770/openwrt_build 的赵云（jdcloud-re-cs-06）处理：
#   Patches/jdcloud-re-cs-06-emmc-mac-nvmem.patch   ← 原样照抄，必需
#     分区节点改成 gpt-partitions + partname="0:ART"（厂商 GPT 里 ART 的名字），
#     否则 NVMEM provider 不注册、qcom-ppe 一直 deferred probe、有线口一个都不出现
#   Patches/jdcloud-re-cs-06-lzma-kernel.patch      ← 原样照抄，标记文件开关
#     FitImage → FitImageLzma，保留 7MiB 内核槽位容纳 BTF；需要 U-Boot 支持 LZMA/FIT
#   Patches/dawn-runtime-fixes.patch                ← 原样照抄，标记文件开关（用 DAWN 才需要）
#
# 额外保险层（我们加的，可关）：
#   Patches/jdcloud-re-cs-06-fixed-mac.patch
#     把 6 处 nvmem MAC 消费者换成 DT 的 mac-address，彻底不依赖任何分区。
#     即使 GPT 里没有 0:ART，qcom-ppe 也能 probe，网口照样出现。
#     关掉：在仓库根放一个 Config/NO_FIXED_MAC 文件
#
# 可选：Scripts/ppe-pppoe-fix.py（QCA4B 持久 VP 承载 tagged PPPoE，上游改名也能自适应）

set -uo pipefail

PATCH_DIR="$GITHUB_WORKSPACE/Patches"
FLAG_DIR="$GITHUB_WORKSPACE/Config"

APPLY() {
	local NAME="$1"
	local FILE="$PATCH_DIR/$1"

	if [ ! -f "$FILE" ]; then
		echo "ERROR: 缺少补丁文件 $FILE"
		exit 1
	fi

	echo " "
	echo "== $NAME"

	if patch -p1 -R --dry-run --batch --no-backup-if-mismatch <"$FILE" >/dev/null 2>&1; then
		echo "   已存在，跳过"
		return 0
	fi

	if patch -p1 --forward --batch --no-backup-if-mismatch <"$FILE"; then
		echo "   OK"
	else
		echo "   ERROR: $NAME 应用失败（上游结构可能已变化，见上面的 .rej 输出）"
		exit 1
	fi
}

TRY_APPLY() {
	local NAME="$1"
	local FILE="$PATCH_DIR/$1"

	echo " "
	echo "== $NAME (optional)"
	if [ ! -f "$FILE" ]; then
		echo "   没有该补丁文件，跳过"
		return 0
	fi
	if patch -p1 -R --dry-run --batch --no-backup-if-mismatch <"$FILE" >/dev/null 2>&1; then
		echo "   已存在，跳过"
		return 0
	fi
	if patch -p1 --forward --batch --no-backup-if-mismatch <"$FILE"; then
		echo "   OK"
	else
		echo "   跳过（上下文不匹配，不影响网口）"
	fi
}

# ---- 照抄部分 ----
APPLY "jdcloud-re-cs-06-emmc-mac-nvmem.patch"

if [ -f "$FLAG_DIR/LZMA_KERNEL" ]; then
	APPLY "jdcloud-re-cs-06-lzma-kernel.patch"
else
	echo " "
	echo "== lzma-kernel 跳过（需要 U-Boot 支持 LZMA/FIT；放 Config/LZMA_KERNEL 可开启）"
fi

if [ -f "$FLAG_DIR/DAWN_PATCH" ]; then
	TRY_APPLY "dawn-runtime-fixes.patch"
fi

# ---- 保险层 ----
if [ -f "$FLAG_DIR/NO_FIXED_MAC" ]; then
	echo " "
	echo "== fixed-mac 跳过（存在 Config/NO_FIXED_MAC）"
else
	APPLY "jdcloud-re-cs-06-fixed-mac.patch"
fi

# ---- 可选：PPPoE ----
echo " "
echo "== ppe-pppoe-fix.py (optional)"
if python3 "$GITHUB_WORKSPACE/Scripts/ppe-pppoe-fix.py"; then
	echo "   OK"
else
	echo "   跳过（上游 PPE/PPPoE 代码结构已变化，不影响有线口）"
fi
