#!/bin/bash
#============================================================
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# 精简版：只做设备移植 + 必要的 LuCI/主题，其他插件全部移除以加快编译。
#============================================================

# ---------------------------------------------------------------
# 0. [upstream-fix] 删除上游 immortalwrt 格式损坏的 globitel-bt-r320 patch
# 该 patch (immortalwrt commit a3105d3f, 2026-05-07) 在 line 162/218 处
# 相邻多个 `--- /dev/null` 块之间缺 `diff --git` file-boundary header，
# 用 patch(1) plaintext 模式 apply 时报 "malformed patch at line 162"，
# 导致所有 MT7981 u-boot variant 编译失败。我们不用 globitel-bt-r320，
# 直接删除。上游修复后此 hook 会自然 no-op。
# ---------------------------------------------------------------
BROKEN_UBOOT_PATCH="package/boot/uboot-mediatek/patches/472-add-globitel-bt-r320.patch"
if [ -f "$BROKEN_UBOOT_PATCH" ]; then
    echo "[upstream-fix] 删除格式损坏的 $BROKEN_UBOOT_PATCH"
    rm -f "$BROKEN_UBOOT_PATCH"
fi

# ---------------------------------------------------------------
# 1. 注入 7981R128 设备支持（VIKINGYFY/immortalwrt owrt 分支）
# ---------------------------------------------------------------

# 复制移植后的 DTS 到正确位置
\cp -f "${GITHUB_WORKSPACE}/diy/mt7981b-sx-7981r128.dts" \
       target/linux/mediatek/dts/

# 在 filogic.mk 中追加设备条目
cat >> target/linux/mediatek/image/filogic.mk << 'FILOGIC_EOF'

define Device/sx_7981r128
  DEVICE_VENDOR := SX
  DEVICE_MODEL := 7981R128
  DEVICE_DTS := mt7981b-sx-7981r128
  DEVICE_DTS_DIR := ../dts
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware kmod-usb3
  # 第一项 = 新 DTS 的 compatible 第一字段（运行时 board_name）
  # 第二项 = hanwckf 老固件 board name，允许从老固件直接 sysupgrade 过来
  SUPPORTED_DEVICES := sx,7981r128 mediatek,mt7981-spim-snand-7981r128
  KERNEL_IN_UBI := 1
  UBOOTENV_IN_UBI := 1
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  IMAGE_SIZE := 65536k
  UBINIZE_OPTS := -E 5
  # factory.bin    = 裸 UBI 镜像（magic UBI#），由 U-Boot 写入 ubi 分区
  # sysupgrade.bin = sysupgrade-tar（OpenWrt 通用升级包），
  #                  既能在 OpenWrt 系统内 sysupgrade 升级，
  #                  也能被 hanwckf 改的 U-Boot HTTP recovery 接受
  IMAGES := sysupgrade.bin factory.bin
  IMAGE/factory.bin := append-ubi | check-size $$(IMAGE_SIZE)
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += sx_7981r128
FILOGIC_EOF

# 1.5. 注入 board.d/02_network 配置
#      定义 LAN/WAN 端口分配：lan1+lan2 → br-lan，eth1 (SFP) → WAN
#      没有这个配置，OpenWrt 会走默认 *) 分支，端口不能正常工作（br-lan 里只有 eth0）
BOARD_NETWORK="target/linux/mediatek/filogic/base-files/etc/board.d/02_network"
if [ -f "$BOARD_NETWORK" ] && ! grep -q 'sx,7981r128' "$BOARD_NETWORK"; then
    awk '
        !done && /^\t\*\)$/ {
            print "\tsx,7981r128)"
            print "\t\tucidef_set_interfaces_lan_wan \"lan1 lan2\" \"eth1\""
            print "\t\t;;"
            done = 1
        }
        { print }
    ' "$BOARD_NETWORK" > "$BOARD_NETWORK.new" && mv "$BOARD_NETWORK.new" "$BOARD_NETWORK"
    echo "[device-add] 02_network case 已注入"
fi

# ---------------------------------------------------------------
# 2. 默认主题改为 Argon（理论上 immortalwrt 自带 luci-theme-argon）
# ---------------------------------------------------------------

# luci-theme-bootstrap 在新版 immortalwrt 里定义在 luci-light/Makefile 中
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/*/Makefile 2>/dev/null || true

# ---------------------------------------------------------------
# 3. .config 包选择（最小化）
# ---------------------------------------------------------------

provided_config_lines=(
    # 目标设备（必须）
    "CONFIG_TARGET_mediatek=y"
    "CONFIG_TARGET_mediatek_filogic=y"
    "CONFIG_TARGET_mediatek_filogic_DEVICE_sx_7981r128=y"
    # 主题
    "CONFIG_PACKAGE_luci-theme-argon=y"
    "CONFIG_PACKAGE_luci-app-argon-config=y"
    # 中文
    "CONFIG_PACKAGE_luci-i18n-base-zh-cn=y"
    # 包管理：保留 opkg
    "CONFIG_OPKG_USE_CURL=y"
    "CONFIG_PACKAGE_opkg=y"
    "CONFIG_USE_APK=n"
)

for line in "${provided_config_lines[@]}"; do
    echo "$line" >> .config
done
