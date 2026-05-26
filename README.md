# openwrt-7981r128

基于 [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt)（Linux kernel 6.18）的 **SX 7981R128** 路由器固件构建项目，通过 GitHub Actions 在线编译。

[![Build](https://github.com/ysuolmai/openwrt-7981r128/actions/workflows/openwrt-7981r128.yml/badge.svg)](https://github.com/ysuolmai/openwrt-7981r128/actions/workflows/openwrt-7981r128.yml)

---

## 硬件信息

| 项目 | 规格 |
|---|---|
| SoC | MediaTek MT7981B（双核 ARM Cortex-A53 @ 1.3 GHz） |
| 内存 | 256 MB DDR |
| 存储 | 128 MB SPI NAND（带 NMBM 坏块管理） |
| 有线网口 | 1× LAN（千兆，MT7531 内部）+ 1× LAN（2.5G，外置 Airoha EN8801SC PHY） |
| WAN | 1× SFP 笼（直连 gmac1，锁定 2500base-x） |
| 无线 | MT7976 双频 WiFi 6（2.4G + 5G） |
| USB | USB 3.0 × 1 |
| 指示灯 | SFP / WIFI5G / WIFI2G / LAN / POWER（共 5 个 GPIO LED） |
| 按键 | Reset × 1 |

---

## 构建方式

1. Fork 本仓库到你自己的 GitHub 账号
2. 进入 **Actions** 标签页
3. 选择左侧 `openwrt-7981r128` workflow
4. 点击右上角 **Run workflow** 手动触发
5. 等待约 1–2 小时（首次编译会更久，因为要下载所有源码和工具链）
6. 编译完成后到 **Releases** 页面下载固件

---

## 安装

固件产物（在 Release 里）只有一个 `...-squashfs-sysupgrade.bin`（sysupgrade-tar 格式），覆盖所有刷机场景：OpenWrt 系统内 sysupgrade 升级、LuCI 系统升级页面、hanwckf 改的 U-Boot HTTP recovery 都用同一个文件。

### 已经在跑 OpenWrt（包括老的 hanwckf 版本）

通过 LuCI **系统升级** 上传 `sysupgrade.bin`，正常勾选/不勾选保留配置都行。新旧 board name 都在 `SUPPORTED_DEVICES` 里（`sx,7981r128` 和 `mediatek,mt7981-spim-snand-7981r128`），**不需要** `-F` 强刷。

或者命令行：

```sh
sysupgrade -n /tmp/sysupgrade.bin    # -n = 不保留配置；想保留就去掉
```

### hanwckf 改的 U-Boot HTTP recovery 页面

串口选 1 进 web，直接上传 `sysupgrade.bin`。该 U-Boot 接受 sysupgrade-tar 格式，会自动解出 kernel 和 rootfs 写到 UBI 对应 volume。

### 原厂 MTK SDK 固件

本项目**不产出** U-Boot 链镜像（无 `preloader.bin` / `bl31-uboot.fip`），从原厂直刷需要先刷一个 [hanwckf/immortalwrt-mt798x](https://github.com/hanwckf/immortalwrt-mt798x) 老版本作为跳板，再 sysupgrade 到本项目固件。

---

## 项目结构

```
.github/workflows/
    openwrt-7981r128.yml         # GitHub Actions 编译流程
diy/
    mt7981b-sx-7981r128.dts      # 移植到 kernel 6.18 DSA 的 DTS
    diy-part1.sh                 # 拉源码前的钩子（目前为空）
    diy-part2.sh                 # 拉源码后的钩子（注入 DTS + filogic.mk + 包配置）
    .config                      # 最小化 seed config（仅指定目标设备）
    99_ttyd-nopass.sh            # （备用）ttyd 免密 uci-defaults
    99_set_argon_primary.sh      # （备用）Argon 设为默认主题
    mount.hotplug                # （备用）U 盘自动挂载脚本
    default-settings/            # （备用）默认设置 LuCI 包
```

`（备用）`标记的文件目前在简化版 `diy-part2.sh` 中未被使用，保留以便后续扩展。

---

## 上游源码

- **源码**：[`VIKINGYFY/immortalwrt`](https://github.com/VIKINGYFY/immortalwrt) `owrt` 分支
- **内核**：Linux 6.18
- **基础**：ImmortalWrt（基于 OpenWrt master）

---

## 自带软件（最小化）

- LuCI Web 界面（默认主题：**Argon**）
- 简体中文翻译（`luci-i18n-base-zh-cn`）
- `opkg` 包管理器（保留传统包格式，未启用 APK）
- ImmortalWrt 标配：SSH（dropbear）、firewall4、odhcpd、dnsmasq 等

**未预装**：翻墙工具、广告过滤、网速测试、AdGuardHome、Tailscale、frpc 等所有第三方插件。需要可在系统运行后通过 `opkg install ...` 或 LuCI 软件包菜单按需安装。

---

## 关键定制

### DTS 移植要点（vs 原 hanwckf 21.02 版本）

| 改动 | 说明 |
|---|---|
| `mt7981.dtsi` → `mt7981b.dtsi` | 新仓库按 A/B 变体拆分 |
| switch 移到 `&mdio_bus` + 加 `interrupt-controller` | DSA 驱动模型要求 |
| `nmbm_spim_nand` wrapper → 内联 `mediatek,nmbm` 属性 | 新 binding |
| LEDs 使用 `LED_COLOR_ID_*` / `LED_FUNCTION_*` 宏 | 内核 6.x 标准 |
| `spi-tx-buswidth` → `spi-tx-bus-width` | binding 名修正 |
| 移除 `&hnat` / `&afe` / `bootargs` / `memory` 节点 | 6.18 不需要 |
| 移除 MAC nvmem 引用 | 原 DTS 无定义，U-Boot 通过 cmdline 传 MAC |

### EN8801SC PHY 驱动

不需要任何 kmod 包。`CONFIG_AIROHA_EN8801SC_PHY=y` 已内置在 VIKINGYFY 的 kernel 6.18 配置中，DTS 中的 `compatible = "ethernet-phy-id67c9.de0a"` 会自动匹配该驱动。

---

## 已知限制

1. **不产出 U-Boot 链镜像**：没有 `preloader.bin` / `bl31-uboot.fip`，因为 VIKINGYFY 源码不包含此设备的 U-Boot 配置；从原厂第一次刷机需要 hanwckf 老固件作跳板。
2. **SFP WAN 锁定 2.5G**：当前 DTS `phy-mode = "2500base-x"`，只支持 2.5G SFP+ 模块。如需兼容 1G SFP，需将 `gmac1` 的 `phy-mode` 改为 `"sgmii"`。
3. **MAC 地址**：依赖 U-Boot 通过 kernel cmdline 传递；如果 U-Boot 配置异常，MAC 可能随机化。
4. **首次构建慢**：约 1–2 小时（GitHub Actions 标准 runner）。增量构建会快很多。

---

## 上游致谢

- [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) — kernel 6.18 源码主线
- [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) — ImmortalWrt 上游
- [OpenWrt](https://github.com/openwrt/openwrt) — 一切的上游
- [hanwckf/immortalwrt-mt798x](https://github.com/hanwckf/immortalwrt-mt798x) — 原 swconfig 时代的 7981R128 支持
- [shmily103/openwrt-7981r128](https://github.com/shmily103/openwrt-7981r128) — 原始 DTS 来源
- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) — GitHub Actions 工作流模板

---

## 许可

- 仓库内的 DTS 文件采用 `GPL-2.0-or-later OR MIT` 双协议
- 编译脚本部分采用 MIT
- 编译产物中各软件遵循其各自的开源协议
