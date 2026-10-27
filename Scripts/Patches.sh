#!/bin/bash
# FanWRT 源码补丁，在 ./wrt（OpenWrt 源码根）里执行
#
# Patches/jdcloud-re-cs-06-emmc-mac-nvmem.patch   （必需）
#   分区节点换 gpt-partitions + partname="0:ART"；GPT 里真有 0:ART 时生效
# Patches/jdcloud-re-cs-06-fixed-mac.patch       （必需）
#   网口/Wi-Fi 的 MAC 改由 DT mac-address 提供，去掉 ART/factory nvmem 依赖
# Scripts/ppe-pppoe-fix.py                       （可选）
#   允许 QCA4B 持久 VP 承载 tagged PPPoE；上游补丁文件名会变，用脚本就地改

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
APPLY "jdcloud-re-cs-06-fixed-mac.patch"

# PPE 的 PPPoE 补丁是可选项：上游会重命名/重构 PPE 补丁系列，
# 失败只告警，不影响网口 MAC 的修复
echo " "
echo "== ppe-pppoe-fix.py (optional)"
if python3 "$GITHUB_WORKSPACE/Scripts/ppe-pppoe-fix.py"; then
	echo "   OK"
else
	echo "   跳过（上游 PPE/PPPoE 代码结构已变化，不影响有线口）"
fi
