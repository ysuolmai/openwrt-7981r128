#!/bin/bash
#============================================================
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
# Lisence: MIT
# Author: P3TERX
# Blog: https://p3terx.com
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
  UBINIZE_OPTS := -E 5
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  IMAGE_SIZE := 114688k
  KERNEL_IN_UBI := 1
  UBOOTENV_IN_UBI := 1
  IMAGES := sysupgrade.itb
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
# 2. 系统个性化配置
# ---------------------------------------------------------------

# 修改默认 SSID
# 注：新版 immortalwrt WiFi 默认已是开启状态（mac80211.uc 内 disabled='0'），无需再 sed
# 配置脚本从 mac80211.sh (bash) 改为 mac80211.uc (ucode)，默认 SSID 也从 ImmortalWrt 变成 ImmortalWRT
WIFI_UC=package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc
if [ -f "$WIFI_UC" ]; then
    sed -i 's/"ImmortalWRT"/"Panzy"/g' "$WIFI_UC"
fi

# 自动挂载脚本
\cp -f "${GITHUB_WORKSPACE}/diy/mount.hotplug" package/system/fstools/files/mount.hotplug

# 默认主题改为 argon
# 注：新版 immortalwrt 中 luci-theme-bootstrap 依赖定义在 luci-light/Makefile 里（不是 luci/Makefile）
# 用 glob 一次性匹配所有 collections，更鲁棒
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/*/Makefile

# ---------------------------------------------------------------
# 3. 安装/更新第三方软件包
# ---------------------------------------------------------------

UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4

	# 清理旧的包
	read -ra PKG_NAMES <<< "$PKG_NAME"
	for NAME in "${PKG_NAMES[@]}"; do
		rm -rf $(find feeds/luci/ feeds/packages/ package/ -maxdepth 3 -type d -iname "*$NAME*" -prune)
	done

	# 克隆仓库
	if [[ $PKG_REPO == http* ]]; then
		local REPO_NAME=$(echo $PKG_REPO | awk -F '/' '{gsub(/\.git$/, "", $NF); print $NF}')
		git clone --depth=1 --single-branch --branch $PKG_BRANCH "$PKG_REPO" package/$REPO_NAME
	else
		local REPO_NAME=$(echo $PKG_REPO | cut -d '/' -f 2)
		git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git" package/$REPO_NAME
	fi

	# 根据 PKG_SPECIAL 处理包
	case "$PKG_SPECIAL" in
		"pkg")
			for NAME in "${PKG_NAMES[@]}"; do
				cp -rf $(find ./package/$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$NAME*" -prune) ./package/
			done
			rm -rf ./package/$REPO_NAME/
			;;
		"name")
			mv -f ./package/$REPO_NAME ./package/$PKG_NAME
			;;
	esac
}

UPDATE_PACKAGE "luci-app-poweroff" "esirplayground/luci-app-poweroff" "master"
UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"
UPDATE_PACKAGE "openwrt-gecoosac" "lwb1978/openwrt-gecoosac" "main"
UPDATE_PACKAGE "luci-app-ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "luci-app-openlist" "sbwml/luci-app-openlist" "main"

#small-package
UPDATE_PACKAGE "xray-core xray-plugin dns2tcp dns2socks haproxy hysteria \
        naiveproxy shadowsocks-rust v2ray-core v2ray-geodata v2ray-geoview v2ray-plugin \
        tuic-client chinadns-ng ipt2socks tcping trojan-plus simple-obfs shadowsocksr-libev \
        luci-app-passwall smartdns luci-app-smartdns v2dat mosdns luci-app-mosdns \
        taskd luci-lib-xterm luci-lib-taskd luci-app-ssr-plus luci-app-passwall2 \
        luci-app-store quickstart luci-app-quickstart luci-app-istorex luci-app-cloudflarespeedtest \
        luci-theme-argon netdata luci-app-netdata lucky luci-app-lucky luci-app-openclash mihomo \
        luci-app-nikki luci-app-vlmcsd vlmcsd" "kenzok8/small-package" "main" "pkg"

#speedtest
UPDATE_PACKAGE "luci-app-netspeedtest" "https://github.com/sbwml/openwrt_pkgs.git" "main" "pkg"
UPDATE_PACKAGE "speedtest-cli" "https://github.com/sbwml/openwrt_pkgs.git" "main" "pkg"

UPDATE_PACKAGE "luci-app-adguardhome" "https://github.com/ysuolmai/luci-app-adguardhome.git" "master"
UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"

rm -rf $(find feeds/luci/ feeds/packages/ -maxdepth 3 -type d -iname luci-app-diskman -prune)
mkdir -p luci-app-diskman && \
wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/applications/luci-app-diskman/Makefile \
     -O luci-app-diskman/Makefile

# ---------------------------------------------------------------
# 4. .config 包选择
# ---------------------------------------------------------------

provided_config_lines=(
    # 目标设备（必须）
    "CONFIG_TARGET_mediatek=y"
    "CONFIG_TARGET_mediatek_filogic=y"
    "CONFIG_TARGET_mediatek_filogic_DEVICE_sx_7981r128=y"
    # 应用包
    "CONFIG_PACKAGE_luci-app-zerotier=y"
    "CONFIG_PACKAGE_luci-i18n-zerotier-zh-cn=y"
    "CONFIG_PACKAGE_luci-app-adguardhome=y"
    "CONFIG_PACKAGE_luci-i18n-adguardhome-zh-cn=y"
    "CONFIG_PACKAGE_luci-app-poweroff=y"
    "CONFIG_PACKAGE_luci-i18n-poweroff-zh-cn=y"
    "CONFIG_PACKAGE_cpufreq=y"
    "CONFIG_PACKAGE_luci-app-cpufreq=y"
    "CONFIG_PACKAGE_luci-i18n-cpufreq-zh-cn=y"
    "CONFIG_PACKAGE_luci-app-ttyd=y"
    "CONFIG_PACKAGE_luci-i18n-ttyd-zh-cn=y"
    "CONFIG_PACKAGE_ttyd=y"
    "CONFIG_PACKAGE_luci-app-ddns-go=y"
    "CONFIG_PACKAGE_luci-i18n-ddns-go-zh-cn=y"
    "CONFIG_PACKAGE_luci-app-argon-config=y"
    "CONFIG_PACKAGE_nano=y"
    "CONFIG_PACKAGE_luci-app-vlmcsd=y"
    "CONFIG_PACKAGE_luci-app-filetransfer=y"
    "CONFIG_PACKAGE_openssh-sftp-server=y"
    "CONFIG_PACKAGE_luci-app-frpc=y"
    "CONFIG_OPKG_USE_CURL=y"
    "CONFIG_PACKAGE_opkg=y"
    "CONFIG_USE_APK=n"
)

for line in "${provided_config_lines[@]}"; do
    echo "$line" >> .config
done

# ---------------------------------------------------------------
# 5. 界面美化：Argon 主题色改为青色
# ---------------------------------------------------------------

find ./ -name "cascade.css"  -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;
find ./ -name "dark.css"     -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;
find ./ -name "cascade.less" -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;
find ./ -name "dark.less"    -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;

# ---------------------------------------------------------------
# 6. uci-defaults 脚本
# ---------------------------------------------------------------

# ttyd 免密登录
install -Dm755 "${GITHUB_WORKSPACE}/diy/99_ttyd-nopass.sh" \
               "package/base-files/files/etc/uci-defaults/99_ttyd-nopass"

# Argon 主题色预设
install -Dm755 "${GITHUB_WORKSPACE}/diy/99_set_argon_primary.sh" \
               "package/base-files/files/etc/uci-defaults/99_set_argon_primary"

# ---------------------------------------------------------------
# 7. 兼容性修复
# ---------------------------------------------------------------

# 修复 getifaddr 返回值（某些版本有 bug）
find ./ -name "getifaddr.c" -exec sed -i 's/return 1;/return 0;/g' {} \;

# 修复 v2ray-geodata Makefile 版本格式
if [ -f ./package/v2ray-geodata/Makefile ]; then
    sed -i 's/VER)-\$(PKG_RELEASE)/VER)-r\$(PKG_RELEASE)/g' \
        ./package/v2ray-geodata/Makefile
fi

# 修复 luci-lib-taskd 依赖版本格式
if [ -f ./package/luci-lib-taskd/Makefile ]; then
    sed -i 's/>=1\.0\.3-1/>=1\.0\.3-r1/g' ./package/luci-lib-taskd/Makefile
fi

# 修复 luci-app-openclash 缺少 PKG_RELEASE
if [ -f ./package/luci-app-openclash/Makefile ]; then
    grep -q '^PKG_RELEASE' ./package/luci-app-openclash/Makefile || \
        sed -i '/^PKG_VERSION:=/a PKG_RELEASE:=1' ./package/luci-app-openclash/Makefile
fi

# 修复 luci-app-quickstart PKG_VERSION 格式
if [ -f ./package/luci-app-quickstart/Makefile ]; then
    sed -i -E 's/PKG_VERSION:=([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)/PKG_VERSION:=\1\nPKG_RELEASE:=\2/' \
        ./package/luci-app-quickstart/Makefile
fi

# 修复 luci-app-store PKG_VERSION 格式
if [ -f ./package/luci-app-store/Makefile ]; then
    sed -i -E 's/PKG_VERSION:=([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)/PKG_VERSION:=\1\nPKG_RELEASE:=\2/' \
        ./package/luci-app-store/Makefile
fi

# 修复 vlmcsd init 脚本路径
if [ -d "package/vlmcsd" ]; then
    MAKEFILE="package/vlmcsd/Makefile"
    if [[ -f "$MAKEFILE" ]] && ! grep -q "INSTALL_INIT_SCRIPT" "$MAKEFILE"; then
        echo "🛠 正在为 vlmcsd 添加 init 脚本安装逻辑..."
        awk '
            BEGIN { in_block=0 }
            {
                if ($0 ~ /^define Package\/vlmcsd\/install/) { in_block=1 }
                if (in_block && $0 ~ /^endef/) {
                    print "\t$(INSTALL_DIR) $(1)/etc/init.d"
                    print "\t$(INSTALL_BIN) ./files/vlmcsd.init $(1)/etc/init.d/vlmcsd"
                    in_block=0
                }
                print
            }
        ' "$MAKEFILE" > "$MAKEFILE.tmp" && mv "$MAKEFILE.tmp" "$MAKEFILE"
        echo "✅ vlmcsd Makefile 修补完成"
    fi
fi

if [ -d "package/luci-app-vlmcsd" ]; then
    find package/luci-app-vlmcsd -type f \( -name '*.js' -o -name '*.lua' -o -name '*.htm' \) \
        -exec sed -i 's#/etc/vlmcsd.ini#/etc/vlmcsd/vlmcsd.ini#g' {} +
fi
