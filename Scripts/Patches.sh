#!/bin/bash
# FanWRT 进阶补丁（默认全部关闭，放标记文件才生效）
#
# Config/NOMAC_DTS：
#   qualcommbe 的 DTS 把 lan1..4 / wan / wifi0 / wifi1 的 MAC 都挂在
#   factory 分区的 nvmem cell 上。刷大分区丢了 factory 后，部分驱动会把
#   "取不到 MAC" 当成硬错误，直接 probe 失败（连 phy / 网口都不出现），
#   这种情况 userspace 的 fanmac 兜底就救不了，需要把 DTS 里的依赖摘掉，
#   让驱动自己用随机 MAC 起来，再由 fanmac 统一写合法 MAC。
#
#   启用：在仓库根放一个 Config/NOMAC_DTS 文件，然后重新构建。

if [ -f "$GITHUB_WORKSPACE/Config/NOMAC_DTS" ]; then
	echo " "
	echo "NOMAC_DTS enabled: strip nvmem MAC references from jdcloud DTS"

	for DTS in "./target/linux/qualcommbe/dts/ipq5322-re-cs-06.dts" \
		   "./target/linux/qualcommbe/dts/ipq5322-re-cs-08.dts"; do
		[ -f "$DTS" ] || continue

		# 只删消费者一侧的引用（switch 端口 / wifi 节点），
		# factory 分区里的 nvmem-layout 定义保持不动
		perl -0pi -e 's/[ \t]*nvmem-cells = <&(?:lan|wan)_macaddr[^;]*>;\n\s*nvmem-cell-names = "mac-address";\n//g' "$DTS"

		LEFT=$(grep -c 'nvmem-cells = <&.*_macaddr' "$DTS" 2>/dev/null || true)
		echo "  $DTS: 剩余消费者引用 ${LEFT:-0}（factory 分区里的定义保留）"
	done
else
	echo "NOMAC_DTS not enabled: keep DTS MAC wiring (factory 分区存在时的原生行为)"
fi
