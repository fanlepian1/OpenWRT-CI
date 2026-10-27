# FanWRT —— 京东云 BE6500（IPQ53XX）专用固件

基于 [VIKINGYFY/OpenWRT-CI](https://github.com/VIKINGYFY/OpenWRT-CI) 改造，只为一个设备服务：**京东云 BE6500（代号赵云，IPQ5332 + Wi-Fi 7）**。

- 源码：[VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) 分支 `owrt`
- 平台：`qualcommbe / ipq53xx`
- 设备：`jdcloud_re-cs-06`（BE6500，主目标）；`jdcloud_re-cs-08`（同平台无 WiFi 型号，备用）
- 主机名：**FanWRT**
- 后台：http://192.168.10.1 ，默认无密码
- Wi-Fi：`FanWRT` / `12345678`（首次开机后请自行修改）

## 编译

工作流只有一个：`.github/workflows/BE6500.yml`（矩阵只有 `IPQ53XX`）。

- 手动：Actions → **BE6500** → Run workflow；勾选 `TEST` 只生成 `.config` 不编译固件，适合先验证配置。
- 自动：推送改动到 `Config/`、`Scripts/`、`Packages/`、`BE6500.yml`、`WRT-CORE.yml` 时自动触发。
- 产物：Releases 里的 `...-qualcommbe-ipq53xx-...` 固件包，按机型命名，刷 `jdcloud_re-cs-06` 那个。

## 保留的插件

| 功能 | 包 |
| --- | --- |
| 科学上网 | `luci-app-homeproxy` + `sing-box` |
| UA 重写 | [UA3F](https://github.com/SunBK201/UA3F)（Services → UA3F） |
| 校园网 | `luci-app-giwifi`（本仓库自带，Services → GIWIFI 自动登录） |
| UPnP / PCP | `luci-app-upnp` + `miniupnpd-nftables`（同时提供 UPnP IGD、PCP、NAT-PMP） |
| 打印 | `cups` `cups-bsd` `cups-client` `cups-filters` `cups-ppdc` `hplip-common` `hplip-sane` `p910nd` `luci-app-p910nd` `luci-app-usb-printer` `kmod-usb-printer` |
| 加速/兼容 | `kmod-nft-queue`、`kmod-sched-bpf`（eBPF 卸载）、`kmod-nft-offload` 等 |
| 系统 | `autocore` `htop` `iperf3` `smartmontools` `usbutils` 等常用工具 |

已剔除上游仓库里的一堆第三方插件（OpenClash、PassWall/2、mosdns、qbittorrent、easytier、vnt、QModem、ddns-go、各类主题、natmapt/stuntman、LianXia233 系列等），编译更快、固件更小。

## HP LaserJet P1108 打印怎么用

OpenWrt 的 `hplip` 源包只编译了 Sane 扫描后端（上游 Makefile 带 `--disable-hpcups-install`），P1108 这类主机型打印机**不靠它出纸**。实际有两条路，都已内置：

0. **先有设备节点**：上游 `kmod-usb-printer` 依赖了一个本源码树里没定义的 `printer-support`，导致 `qualcommbe` 上这个包根本不可选、`/dev/usb/lp0` 不会出现。本仓库用 `Packages/kmod-usb-printer/` 本地重建了同一份 kmod（`KCONFIG:=CONFIG_USB_PRINTER`、`FILES:=usblp.ko`、`AutoProbe usblp`），所以插上 P1108 后应该能看到 `/dev/usb/lp0`，`luci-app-usb-printer` 也能装了。
1. **p910nd（推荐，最省事）**：`服务 → 打印服务器` 里启用，设备选 `/dev/usb/lp0`，端口 9100。Windows 上添加"标准 TCP/IP 端口 → 路由器 IP:9100"，驱动选 HP LaserJet Professional P1100 系列。
2. **CUPS**：浏览器打开 `http://192.168.10.1:631`，添加 **Raw / 原始** 队列指向 `usb://HP/LaserJet%20Professional%20P1108`，客户端同样用 HP 驱动。CUPS 自带 libusb 版 `backend/usb`，不依赖 usblp。

扫描功能由 `hplip-sane` + `sane-backends` 提供（`scanimage -L` 能识别即可）。

## GIWIFI 校园网自动登录

`服务 → GIWIFI 自动登录` 填写帐号、密码、认证门户地址（例如 `http://100.100.9.2`）和 AES 密钥（默认 `1234567887654321`），勾选启用并保存即可。

- 逻辑：定时用 `check_url` 判断是否在线 → 掉线就去门户登录页抓隐藏域 → 用门户同一套 AES-128-CBC 加密帐号密码 → POST 认证 → 失败自动退避重试。
- 日志：`/var/log/giwifi.log`（`logread -e giwifi` 也能看）。
- 手动跑一次：`/usr/sbin/giwifi-login --once`。
- 门户地址、AES 密钥各校不同：抓一次学校登录页的 `gportal/web/login` 就能看到 `input[name=iv]` 和请求里的 `data`/`iv`。

## 目录说明

```
.github/workflows/BE6500.yml   唯一的编译入口（IPQ53XX）
.github/workflows/WRT-CORE.yml 通用编译核心（被 BE6500 调用）
Config/IPQ53XX.txt             平台 + 设备选择
Config/GENERAL.txt             插件 / 内核 / 组件开关
Scripts/Packages.sh            第三方插件拉取（aurora、homeproxy、UA3F、本地包）
Scripts/Settings.sh            主机名、Wi-Fi、IP、主题
Scripts/Handles.sh             插件补丁
Packages/luci-app-giwifi/      自写 GIWIFI 校园网自动登录插件
```

## 刷机提醒

BE6500 需要先刷好 U-Boot（Web 后台 `192.168.3.3`）再刷本固件；分区、U-Boot、备份相关请看设备教程。升级时建议"不保留配置"首次刷入，之后可正常 sysupgrade。

## 上游致谢

- [immortalwrt](https://github.com/immortalwrt/immortalwrt)
- [VIKINGYFY/OpenWRT-CI](https://github.com/VIKINGYFY/OpenWRT-CI) 与 [VIKINGYFY/packages](https://github.com/VIKINGYFY/packages)
- [SunBK201/UA3F](https://github.com/SunBK201/UA3F)
- [mcitem/GIWIFI](https://github.com/mcitem/GIWIFI)（GIWIFI 认证协议参考）
