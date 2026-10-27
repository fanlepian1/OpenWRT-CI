# FanWRT —— 京东云 BE6500（IPQ53XX）专用固件

基于 [VIKINGYFY/OpenWRT-CI](https://github.com/VIKINGYFY/OpenWRT-CI) 改造，只为 **京东云 BE6500（赵云，IPQ5332 + Wi-Fi 7）** 服务。

- 源码：[VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) 分支 `owrt`
- 平台：`qualcommbe / ipq53xx`，设备：`jdcloud_re-cs-06`
- 主机名：**FanWRT**，后台 http://192.168.10.1 （默认无密码）
- Wi-Fi：`FanWRT` / `12345678`（首次开机后请自行修改）
- 主题：[argon](https://github.com/sbwml/luci-theme-argon)（含 `luci-app-argon-config`）

## 有线口的修复（照抄 WoChen5770/openwrt_build 的赵云方案）

上游 DTS 把 lan1..4、wan、wifi0/wifi1 的 MAC 都挂在 nvmem cell 上，来源是
`block/block-device/partname="factory"` 那个分区。`of_get_mac_address()` **先查 nvmem**，
只要 provider 没注册就返回 `-EPROBE_DEFER`，树里的
`0526-01-net-ethernet-qualcomm-ppe-defer-for-nvmem-mac` 就会让 `ppe_port_mac_prepare()`
一直 defer —— **qcom-ppe 永远不 probe，lan1..4 / wan 一个都不出现**，
br-lan 没成员，有线没有 IP（"设备不存在"）。

### 照抄的部分（原样，字节级一致）

| 补丁 | 作用 | 开关 |
| --- | --- | --- |
| `Patches/jdcloud-re-cs-06-emmc-mac-nvmem.patch` | 分区节点换成 `gpt-partitions` + `partname="0:ART"`（厂商 GPT 里 ART 的名字） | **必需** |
| `Patches/jdcloud-re-cs-06-lzma-kernel.patch` | `FitImage` → `FitImageLzma`，保留 7 MiB 内核槽位容纳 BTF | `Config/LZMA_KERNEL`（默认关，需 U-Boot 支持 LZMA/FIT） |
| `Patches/dawn-runtime-fixes.patch` | DAWN 运行期修复 | `Config/DAWN_PATCH`（默认关，用 DAWN 才需要） |

前两个是 WoChen5770 仓库里的原文件，`Scripts/Patches.sh` 直接 `patch -p1`。

**LZMA 那个默认不开**：它会把内核镜像格式换掉，U-Boot 不支持 LZMA/FIT 就开不了机。
确认你的引导器兼容后，`touch Config/LZMA_KERNEL` 重新构建即可。

### 额外保险层（我们加的，默认开）

`Patches/jdcloud-re-cs-06-fixed-mac.patch`：把 6 处 nvmem MAC 消费者
（port@1..4 + wifi0/wifi1）换成 DT 的 `mac-address`

```dts
port@1 { label = "lan1"; mac-address = [02 46 57 00 00 01]; };
port@4 { label = "wan";  mac-address = [02 46 57 00 00 11]; };
&wifi0 { mac-address = [02 46 57 00 00 21]; };
```

这样 `of_get_mac_address()` 直接命中 `mac-address`，根本不碰 nvmem，
**即使 GPT 里没有 `0:ART` 分区，网口也照样出现**。只在照抄方案不生效时才会用到，
放一个 `Config/NO_FIXED_MAC` 文件就能彻底回到纯照抄状态。

MAC 身份由 `fanwrt-defaults` 的 `50-fanwrt-mac` 按 SoC 序列号派生后写进 UCI
（`network.mac_lan1..4` / `mac_wan` / `wireless.macaddr`），同一份固件刷多台不会撞。

### 配置门禁（照抄他们的 required / expected_config 思路）

`Scripts/CheckConfig.sh` 在 `make defconfig` 之后跑：

- 硬门禁：平台/设备、`fanwrt-defaults`、`luci-app-giwifi`、`ua3f`、`luci-app-homeproxy`、
  `adguardhome`、`luci-theme-argon`、`luci-app-argon-config`、`luci-app-upnp`、
  `miniupnpd-nftables`、`kmod-usb-printer`、`luci-app-usb-printer`、`kmod-nft-*`、`kmod-sched-bpf`
- 补丁生效检查：DTS 里必须有 `gpt-partitions`（和 `mac-address`，除非关了保险层）
- 禁止项：`luci-app-fanmac`、`luci-theme-aurora` 不许出现

任一项不过 → 构建直接失败，不会发一个"编译成功但功能没进去"的固件。

## PPE 硬件加速

`Packages/fanwrt-defaults` 在首次启动（含保留配置升级）写入：

```sh
uci set firewall.@defaults[0].flow_offloading='1'      # nftables flowtable（软件路径，需开）
uci set firewall.@defaults[0].flow_offloading_hw='1'   # flowtable 卸载到 PPE
```

PPE 硬件流表由 qualcommbe 的 `net-ethernet-qualcomm PPE` 系列补丁提供（0507 绑定 netfilter flowtables、0509 PPPoE、0510 VLAN 上行、0517/0518 虚拟口等），依赖 `kmod-nft-offload`。

- 想确认是否真卸载：`nft list ruleset | grep -i flowtable`，以及 `dmesg | grep -i ppe`
- 某条链路异常时可退回软件转发：`uci set firewall.@defaults[0].flow_offloading_hw='0' && uci commit firewall && /etc/init.d/firewall restart`
- 拨号（PPPoE）用户额外打了 `Patches/jdcloud-re-cs-06-qca4b-pppoe.patch`：允许 QCA4B 持久虚拟口承载 tagged PPPoE，否则带 VLAN tag 的 PPPoE 会在装硬件流表前被拒，PPE 对拨号等于没生效

## 编译

唯一入口：`.github/workflows/BE6500.yml`（矩阵只有 `IPQ53XX`，只编 `jdcloud_re-cs-06`）。

- 手动：Actions → **BE6500** → Run workflow；勾 `TEST` 只生成 `.config` 不编译固件
- 自动：推送到 `Config/`、`Scripts/`、`Packages/`、`Patches/`、`BE6500.yml`、`WRT-CORE.yml` 时触发
- 产物：Releases 里 `...-qualcommbe-ipq53xx-jdcloud_re-cs-06-squashfs-sysupgrade-...bin`
- 编译流程：`Update Feeds → Custom Packages（拉插件 + 打补丁）→ Custom Settings（写死配置 + 主机名/Wi-Fi/IP + 配置门禁）→ Compile → Release`

## 保留的插件

| 功能 | 包 |
| --- | --- |
| 科学上网 | `luci-app-homeproxy` + `sing-box` |
| UA 重写 | [UA3F](https://github.com/SunBK201/UA3F)（服务 → UA3F） |
| 校园网 | `luci-app-giwifi`（本仓库自带，服务 → GIWIFI 自动登录） |
| DNS 去广告 | `adguardhome` + `luci-app-adguardhome`（服务 → AdGuard Home） |
| UPnP / PCP | `luci-app-upnp` + `miniupnpd-nftables`（UPnP IGD + PCP + NAT-PMP） |
| 打印 | `cups` `cups-bsd` `cups-client` `cups-filters` `cups-ppdc` `hplip-common` `hplip-sane` `p910nd` `luci-app-p910nd` `luci-app-usb-printer` `kmod-usb-printer` |
| 加速 | PPE 硬件卸载（`kmod-nft-offload` + `fanwrt-defaults`）、`kmod-nft-queue`、`kmod-sched-bpf` |
| 界面 | `luci-theme-argon` + `luci-app-argon-config` |
| 系统 | `autocore` `htop` `iperf3` `smartmontools` `usbutils` 等 |

已剔除上游仓库里的一堆第三方插件（OpenClash、PassWall/2、mosdns、qbittorrent、easytier、vnt、QModem、ddns-go、各类主题、natmapt/stuntman、LianXia233 系列等）。

## HP LaserJet P1108 打印

OpenWrt 的 `hplip` 源包只编了 Sane 扫描后端（上游 `--disable-hpcups-install`），P1108 这类主机型打印机**不靠它出纸**。两条路都内置：

0. **先有设备节点**：上游 `kmod-usb-printer` 依赖了一个本源码树里没定义的 `printer-support`，导致 `qualcommbe` 上这个包根本不可选、`/dev/usb/lp0` 不出现。本仓库用 `Packages/kmod-usb-printer/` 本地重建了同一份 kmod（`KCONFIG:=CONFIG_USB_PRINTER`、`FILES:=usblp.ko`、`AutoProbe usblp`）。
1. **p910nd（推荐）**：`服务 → 打印服务器` 启用，设备选 `/dev/usb/lp0`，端口 9100；Windows 添加「标准 TCP/IP 端口 → 路由器 IP:9100」，驱动选 HP LaserJet Professional P1100 系列。
2. **CUPS**：`http://192.168.10.1:631` 添加 **Raw / 原始** 队列指向 `usb://HP/LaserJet%20Professional%20P1108`。CUPS 自带 libusb 版 `backend/usb`，不依赖 usblp。

扫描由 `hplip-sane` + `sane-backends` 提供（`scanimage -L` 能识别即可）。

## GIWIFI 校园网自动登录

`服务 → GIWIFI 自动登录` 填帐号、密码、认证门户地址（例如 `http://100.100.9.2`）、AES 密钥（默认 `1234567887654321`），勾启用保存。

- 逻辑：`check_url` 判断在线 → 掉线抓门户登录页隐藏域 → 用门户同一套 AES-128-CBC 加密帐号密码 → POST 认证 → 失败退避重试
- 日志：`/var/log/giwifi.log`（`logread -e giwifi` 也行）；手动跑一次：`/usr/sbin/giwifi-login --once`

## 目录说明

```
.github/workflows/BE6500.yml   唯一编译入口（IPQ53XX / jdcloud_re-cs-06）
.github/workflows/WRT-CORE.yml 通用编译核心（被 BE6500 调用）
Config/IPQ53XX.txt             平台 + 设备
Config/GENERAL.txt             插件 / 内核 / 组件开关
Scripts/Packages.sh            拉第三方插件（argon、homeproxy、UA3F、本地包）
Scripts/Patches.sh             打 Device Tree / PPPoE 补丁（照抄 WoChen5770 方案）
Scripts/CheckConfig.sh         配置门禁（缺项/补丁没生效就红）
Scripts/ppe-pppoe-fix.py       QCA4B tagged PPPoE（按内容自适应上游改名）
Scripts/Settings.sh            主机名、Wi-Fi、IP、主题
Scripts/Handles.sh             插件补丁（argon 配色/菜单）
Patches/                       jdcloud-re-cs-06 的 DTS 与 PPPoE 补丁
Packages/luci-app-giwifi/      GIWIFI 校园网自动登录插件
Packages/kmod-usb-printer/     本地重建的 usblp（修上游悬空依赖）
Packages/fanwrt-defaults/      默认项：flow offload + PPE 卸载、MAC 派生、fanwrt-diag
```

## 刷机提醒

BE6500 需先刷好 U-Boot（Web 后台 `192.168.3.3`）再刷本固件；建议首次「不保留配置」。

刷完先确认：

一条命令看全部（固件自带）：

```sh
fanwrt-diag
```

它会打印：网口列表、`/dev/disk/by-partlabel`、`sgdisk -p /dev/mmcblk0` 的 GPT 分区名、`/sys/kernel/debug/devices_deferred`、PPE/nvmem/DSA 相关 dmesg、br-lan 成员、各口 MAC。

只关心要点：

```sh
ip -o link | grep -E ' (lan|wan)[0-9]*'        # lan1..4 / wan 都在（这次修的核心）
cat /sys/class/net/lan1/address                # 应是 02:xx:... 且各口不同
nft list ruleset | grep -i flowtable           # PPE 卸载表
cat /sys/kernel/debug/devices_deferred         # 不该再有 ppe
```

## 上游致谢

- [immortalwrt](https://github.com/immortalwrt/immortalwrt)
- [VIKINGYFY/OpenWRT-CI](https://github.com/VIKINGYFY/OpenWRT-CI) 与 [VIKINGYFY/packages](https://github.com/VIKINGYFY/packages)
- [sbwml/luci-theme-argon](https://github.com/sbwml/luci-theme-argon)
- [SunBK201/UA3F](https://github.com/SunBK201/UA3F)
- [mcitem/GIWIFI](https://github.com/mcitem/GIWIFI)（GIWIFI 认证协议参考）
- [WoChen5770/openwrt_build](https://github.com/WoChen5770/openwrt_build)（赵云 `0:ART` / gpt-partitions 与 QCA4B PPPoE 补丁思路）
