#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""QCA4B 持久 VP 允许承载 tagged PPPoE。

上游把 PPE 的 PPPoE 激活逻辑挪来挪去（0652 → 0651 …），所以这里不写死文件名：
在 target/linux/qualcommbe/patches-6.18/*.patch 里找同时含
  ppe_vp_ref_qca4b(  和  VLAN-over-VP needs VP translation rules
的那个文件，就地改两处：

1. 删掉 "带 VLAN 就 -EOPNOTSUPP" 的拒绝（QCA4B 的 VP 已经带上了用户口身份）
2. 后面的 VLAN VSI 分支加 `vp < 0 &&` 前置条件

幂等：已改过就跳过。找不到目标时返回 2（Patches.sh 当作“可选步骤失败”处理）。
"""
import glob
import os
import sys

TARGET_GLOB = "target/linux/qualcommbe/patches-6.18/*.patch"

OLD_REJECT = [
    "+		/* VLAN-over-VP needs VP translation rules, not a physical rule. */",
    "+		if (session->svid >= 0 || session->cvid >= 0)",
    "+			return -EOPNOTSUPP;",
]

NEW_REJECT = [
    "+		/* QCA4B already owns the user-port identity in the VP; the",
    "+		 * PPPoE session table matches SID and peer on that VP, so no",
    "+		 * physical-port VLAN VSI is required for this tagged underlay. */",
]

OLD_VLAN = "+	if (session->svid >= 0 || session->cvid >= 0) {"
NEW_VLAN = "+	if (vp < 0 && (session->svid >= 0 || session->cvid >= 0)) {"


def find_target():
    for path in sorted(glob.glob(TARGET_GLOB)):
        try:
            text = open(path, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        if "ppe_vp_ref_qca4b(" in text and "VLAN-over-VP needs VP translation rules" in text:
            return path
    return None


def main():
    path = find_target()

    if path is None:
        # 可能上游已经自己修了，或整段被重构
        for p in sorted(glob.glob(TARGET_GLOB)):
            try:
                t = open(p, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            if "PVLAN" in t or "physical-port VLAN VSI is required" in t:
                print("PPPoE 补丁似乎已经在上游：%s" % p)
                return 0
        print("没找到可改的 PPE PPPoE 补丁（上游结构已变化），跳过")
        return 2

    lines = open(path, encoding="utf-8", errors="replace").read().split("\n")

    if any(NEW_VLAN in l for l in lines):
        print("已打过标记（%s），跳过" % os.path.basename(path))
        return 0

    # 1) 删掉拒绝分支
    joined = "\n".join(lines)
    block = "\n".join(OLD_REJECT)
    if block not in joined:
        print("在 %s 里没找到拒绝分支，跳过" % os.path.basename(path))
        return 2
    joined = joined.replace(block, "\n".join(NEW_REJECT), 1)

    # 2) VLAN VSI 分支加 vp < 0 条件（只改替换点之后的第一个）
    lines = joined.split("\n")
    anchor = lines.index(NEW_REJECT[-1])
    for i in range(anchor, len(lines)):
        if lines[i] == OLD_VLAN:
            lines[i] = NEW_VLAN
            break
    else:
        print("没找到 VLAN VSI 分支，跳过")
        return 2

    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print("已修补 %s" % path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
