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
# \cp -rf diy/diy/9921-support-SX-7981R128-for-mtk-sdk-v7.6.6.1.patch target/linux/mediatek/patches-5.4

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

