#!/bin/bash
#============================================================
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# 精简版：只做设备移植 + 必要的 LuCI/主题，其他插件全部移除以加快编译。
#============================================================

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
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware \
                     kmod-usb3
  # 兼容 hanwckf 老固件的 board name，允许从老固件直接 sysupgrade 过来
  SUPPORTED_DEVICES := mediatek,mt7981-spim-snand-7981r128
  UBINIZE_OPTS := -E 5
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  IMAGE_SIZE := 102400k
  KERNEL_IN_UBI := 1
  UBOOTENV_IN_UBI := 1
  # factory.bin 是裸 UBI 镜像，U-Boot 下可直接 nand write 刷写
  # sysupgrade.itb 是 FIT 格式，OpenWrt 系统内 sysupgrade 升级用
  # recovery.itb 是 initramfs，用于 U-Boot 的 bootm 救砖
  IMAGES += factory.bin sysupgrade.itb
  IMAGE/factory.bin := append-ubi | check-size $$(IMAGE_SIZE)
  KERNEL_INITRAMFS_SUFFIX := -recovery.itb
  KERNEL := kernel-bin | gzip
  KERNEL_INITRAMFS := kernel-bin | lzma | \
        fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb with-initrd | pad-to 64k
  IMAGE/sysupgrade.itb := append-kernel | \
        fit gzip $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb external-static-with-rootfs | \
        append-metadata
endef
TARGET_DEVICES += sx_7981r128
FILOGIC_EOF

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
