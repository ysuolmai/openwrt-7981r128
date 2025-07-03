#!/bin/bash
#============================================================
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
# Lisence: MIT
# Author: P3TERX
# Blog: https://p3terx.com
#============================================================
#add packages
git clone https://github.com/shmily103/openwrt-7981r128.git diy

# Modify default IP
sed -i 's/192.168.1.1/192.168.6.1/g' package/base-files/files/bin/config_generate
# Modify WiFi ON
sed -i 's/disabled=1/disabled=0/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh
# Modify default SSID
sed -i 's/ssid=ImmortalWrt/ssid=Panzy/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh
# Modify Automount
\cp -rf diy/diy/mount.hotplug package/system/fstools/files
# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
# Modify hostname
sed -i 's/ImmortalWrt/Panzy/g' package/base-files/files/bin/config_generate
# Modify LAN port
#sed -i 's/eth0/eth6/g' package/base-files/files/etc/board.d/99-default_network
# Modify patch
#rm -rf target/linux/mediatek/patches-5.4/9921-support-SX-7981R128-for-mtk-sdk-v7.6.6.1.patch
#\cp -rf diy/9921-support-SX-7981R128-for-mtk-sdk-v7.6.6.1_hanwckf.patch target/linux/mediatek/patches-5.4
#ADD target
\cp -rf diy/diy/mt7981-spim-nand-7981r128.dts target/linux/mediatek/files-5.4/arch/arm64/boot/dts/mediatek
\cp -rf diy/diy/mt7981.mk target/linux/mediatek/image
\cp -rf diy/diy/9921-support-SX-7981R128-for-mtk-sdk-v7.6.6.1.patch target/linux/mediatek/patches-5.4

# Modify aria2 samba
rm -rf feeds/luci/applications/luci-app-aria2
rm -rf feeds/luci/applications/luci-app-samba4
rm -rf feeds/luci/applications/luci-app-openclash
cd diy
git clone -b openwrt-21.02 https://github.com/openwrt/luci.git
git clone https://github.com/vernesong/OpenClash.git
cd ..
\cp -rf diy/luci/applications/luci-app-aria2 feeds/luci/applications
\cp -rf diy/luci/applications/luci-app-samba4 feeds/luci/applications
\cp -rf diy/OpenClash/luci-app-openclash feeds/luci/applications
rm -rf diy


#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4

	# 清理旧的包
	read -ra PKG_NAMES <<< "$PKG_NAME"  # 将PKG_NAME按空格分割成数组
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
			# 提取每个包
			for NAME in "${PKG_NAMES[@]}"; do
				cp -rf $(find ./package/$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$NAME*" -prune) ./package/
			done
			# 删除剩余的包
			rm -rf ./package/$REPO_NAME/
			;;
		"name")
			# 重命名包
			mv -f ./package/$REPO_NAME ./package/$PKG_NAME
			;;
	esac
}

UPDATE_PACKAGE "luci-app-poweroff" "esirplayground/luci-app-poweroff" "master"
UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"
UPDATE_PACKAGE "openwrt-gecoosac" "lwb1978/openwrt-gecoosac" "main"
#UPDATE_PACKAGE "luci-app-homeproxy" "immortalwrt/homeproxy" "master"
UPDATE_PACKAGE "luci-app-ddns-go" "sirpdboy/luci-app-ddns-go" "main"
#UPDATE_PACKAGE "luci-app-alist" "sbwml/luci-app-alist" "main"
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
#rm -rf $(find feeds/luci/ feeds/packages/ -maxdepth 3 -type d -iname parted -prune)
mkdir -p luci-app-diskman && \
wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/applications/luci-app-diskman/Makefile -O luci-app-diskman/Makefile
#mkdir -p parted && \
#wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/Parted.Makefile -O parted/Makefile


# Configuration lines to append to .config
provided_config_lines=(
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
    #"CONFIG_PACKAGE_luci-app-homeproxy=y"
    #"CONFIG_PACKAGE_luci-i18n-homeproxy-zh-cn=y"
    "CONFIG_PACKAGE_luci-app-ddns-go=y"
    "CONFIG_PACKAGE_luci-i18n-ddns-go-zh-cn=y"
    "CONFIG_PACKAGE_luci-app-argon-config=y"
    "CONFIG_PACKAGE_nano=y"
    "CONFIG_BUSYBOX_CONFIG_LSUSB=n"
    "CONFIG_PACKAGE_luci-app-netspeedtest=y"
    "CONFIG_PACKAGE_luci-app-vlmcsd=y"
    "CONFIG_PACKAGE_luci-app-filetransfer=y"
    "CONFIG_PACKAGE_openssh-sftp-server=y"
    "CONFIG_PACKAGE_luci-app-frpc=y" 
    "CONFIG_OPKG_USE_CURL=y"
    "CONFIG_PACKAGE_opkg=y"   
    "CONFIG_USE_APK=n"
    #"CONFIG_PACKAGE_luci-app-openlist=y"
    #"CONFIG_PACKAGE_luci-i18n-openlist-zh-cn=y"
)

# Append configuration lines to .config
for line in "${provided_config_lines[@]}"; do
    echo "$line" >> .config
done


find ./ -name "cascade.css" -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;
find ./ -name "dark.css" -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;
find ./ -name "cascade.less" -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;
find ./ -name "dark.less" -exec sed -i 's/#5e72e4/#31A1A1/g; s/#483d8b/#31A1A1/g' {} \;

#修改ttyd为免密
install -Dm755 "${GITHUB_WORKSPACE}/diy/99_ttyd-nopass.sh" "package/base-files/files/etc/uci-defaults/99_ttyd-nopass"

install -Dm755 "${GITHUB_WORKSPACE}/diy/99_set_argon_primary" "package/base-files/files/etc/uci-defaults/99_set_argon_primary"


find ./ -name "getifaddr.c" -exec sed -i 's/return 1;/return 0;/g' {} \;

#fix makefile for apk
if [ -f ./package/v2ray-geodata/Makefile ]; then
    sed -i 's/VER)-\$(PKG_RELEASE)/VER)-r\$(PKG_RELEASE)/g' ./package/v2ray-geodata/Makefile
fi
if [ -f ./package/luci-lib-taskd/Makefile ]; then
    sed -i 's/>=1\.0\.3-1/>=1\.0\.3-r1/g' ./package/luci-lib-taskd/Makefile
fi
if [ -f ./package/luci-app-openclash/Makefile ]; then
    sed -i '/^PKG_VERSION:=/a PKG_RELEASE:=1' ./package/luci-app-openclash/Makefile
fi
if [ -f ./package/luci-app-quickstart/Makefile ]; then
    # 把 PKG_VERSION:=x.y.z-n 拆成 PKG_VERSION:=x.y.z 和 PKG_RELEASE:=n
    sed -i -E 's/PKG_VERSION:=([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)/PKG_VERSION:=\1\nPKG_RELEASE:=\2/' ./package/luci-app-quickstart/Makefile
fi
if [ -f ./package/luci-app-store/Makefile ]; then
    # 把 PKG_VERSION:=x.y.z-n 拆成 PKG_VERSION:=x.y.z 和 PKG_RELEASE:=n
    sed -i -E 's/PKG_VERSION:=([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)/PKG_VERSION:=\1\nPKG_RELEASE:=\2/' ./package/luci-app-store/Makefile
fi


if [ -d "package/vlmcsd" ]; then
    mkdir -p "package/vlmcsd/patches"
    cp -f "${GITHUB_WORKSPACE}/Scripts/001-fix_compile_with_ccache.patch" "package/vlmcsd/patches"

    MAKEFILE="package/vlmcsd/Makefile"
    cp -f "${GITHUB_WORKSPACE}/Scripts/992_vlmcsd_init" "package/vlmcsd/files/vlmcsd.init"
    chmod +x package/vlmcsd/files/vlmcsd.init
    
    # 如果 Makefile 存在且尚未包含 INSTALL_INIT_SCRIPT，则插入 init.d 安装逻辑
    if [[ -f "$MAKEFILE" && ! $(grep -q "INSTALL_INIT_SCRIPT" "$MAKEFILE") ]]; then
        echo "🛠 正在补丁 package/vlmcsd/Makefile 添加 init 脚本逻辑..."

        awk '
            BEGIN { in_block=0 }
            {
                if ($0 ~ /^define Package\/vlmcsd\/install/) {
                    in_block = 1
                }

                if (in_block && $0 ~ /^endef/) {
                    print "\t$(INSTALL_DIR) $(1)/etc/init.d"
                    print "\t$(INSTALL_BIN) ./files/vlmcsd.init $(1)/etc/init.d/vlmcsd"
                    in_block = 0
                }

                print
            }
        ' "$MAKEFILE" > "$MAKEFILE.tmp" && mv "$MAKEFILE.tmp" "$MAKEFILE"
	echo "$MAKEFILE"
        echo "✅ Makefile 补丁完成: 添加 init 脚本安装逻辑。"
    else
        echo "ℹ️ Makefile 已存在或已有 init 脚本安装逻辑，跳过。"
    fi
fi

if [ -d "package/luci-app-vlmcsd" ]; then
    find package/luci-app-vlmcsd -type f \( -name '*.js' -o -name '*.lua' -o -name '*.htm' \) -exec sed -i 's#/etc/vlmcsd.ini#/etc/vlmcsd/vlmcsd.ini#g' {} +
fi

