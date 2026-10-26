# luci-app-fanmac

京东云 BE6500（赵云）/ 太乙 刷常规大分区后 **factory 分区丢失导致 MAC 全零** 的兜底。

- 菜单：网络 → MAC 兜底
- 主程序：`/usr/sbin/fanmac`（`apply` / `show` / `reset`）
- 持久化：`/etc/fanmac.macs`
- 顺序：`/etc/init.d/fanmac` START=18，跑在 netifd(20) / wpad(19) 之前

## 为什么需要

DTS 里 lan1..4、wan、wifi0/wifi1 的 MAC 都来自

```
&sdhc { card@0 { block { partitions { block-partition-factory {
    partname = "factory";
    nvmem-layout { fixed-layout; lan_macaddr@0; wan_macaddr@6; }
}}}}}
```

`partname` 按 GPT 分区名找 factory。刷大分区后 GPT 里没有这个分区，nvmem cell 不存在：

1. 所有网口 MAC = `00:00:00:00:00:00`
2. 内核 `br_add_if()` 直接拒绝把全零 MAC 的端口加进 `br-lan`
3. `br-lan` 没成员 → 有线没有 DHCP/IP
4. `wifi0/wifi1` 的 MAC 也来自同一个 cell → 无线一起废

## 它做什么

1. `factory` 分区（`/dev/disk/by-partlabel/factory` 或 `/dev/mmcblk0p25`）能读到有效 MAC → 原样沿用
2. 读不到 → 用 `/etc/fanmac.macs` 里上次保存的值
3. 还没有 → 从 SoC 序列号 / eMMC CID 派生 `02:xx:xx:xx:xx:xx`（本机管理 + 单播），写盘持久化
4. 写入 `/etc/config/network` 的 `config device` 段（`macaddr`）、`br-lan`、以及每个 `wifi-iface` 的 `macaddr`
5. 立刻 `ip link set ... address` 一遍，保证本次启动 netifd 建桥时 MAC 已合法

factory 还在的机器行为完全不变（读到真 MAC 就用真的）。
