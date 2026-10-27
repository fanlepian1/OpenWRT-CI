#!/bin/bash
# FanWRT 源码补丁，在 ./wrt（OpenWrt 源码根）里执行
#
# Patches/jdcloud-re-cs-06-emmc-mac-nvmem.patch
#   DTS 的 MAC 来源从 legacy block/factory 换成 GPT 的 0:ART，
#   修 qcom-ppe deferred probe（有线口一个都不出来）
# Patches/jdcloud-re-cs-06-qca4b-pppoe.patch
#   QCA4B 持久 VP 允许承载 tagged PPPoE，PPE 才能对 PPPoE 生效

set -uo pipefail

PATCH_DIR="$GITHUB_WORKSPACE/Patches"

APPLY() {
	local NAME="$1"
	local FILE="$PATCH_DIR/$1"

	if [ ! -f "$FILE" ]; then
		echo "ERROR: 缺少补丁文件 $FILE"
		exit 1
	fi

	echo " "
	echo "== $NAME"

	# 已经打过（反向能 dry-run 成功）就跳过
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

APPLY "jdcloud-re-cs-06-emmc-mac-nvmem.patch"
APPLY "jdcloud-re-cs-06-qca4b-pppoe.patch"
