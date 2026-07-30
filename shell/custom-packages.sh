#!/bin/bash
# 24.10.x 第三方插件配置 (IPK 格式) - aarch64_generic 专用
# 启用第三方插件时取消对应注释


# adguardhome广告拦截 (adguardhome)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES adguardhome luci-app-adguardhome luci-i18n-adguardhome-zh-cn"

#晶晨宝盒 (amlogic)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-amlogic luci-i18n-amlogic-zh-cn"

# argon主题 (argon)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-argon-config luci-theme-argon"

# aurora主题 (aurora)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-aurora-config luci-theme-aurora luci-i18n-aurora-config-zh-cn"

# 网络流量监控 (bandix)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES bandix luci-app-bandix luci-i18n-bandix-zh-cn"

# 网络流量监控 (bandix-plus)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES bandix-plus luci-app-bandix-plus luci-i18n-bandix-plus-zh-cn"

# clashoo代理面板 (clashoo)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES clashoo luci-app-clashoo luci-i18n-clashoo-zh-cn"

# daede代理面板 (daede)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES dae daed luci-app-daede"

# lucky内网穿透 (lucky)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES lucky luci-app-lucky luci-i18n-lucky-zh-cn"

# DNS转发器 (MosDNS)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES mosdns luci-app-mosdns luci-i18n-mosdns-zh-cn"

# 网络设置向导 (netwizard)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-netwizard luci-i18n-netwizard-zh-cn"

# nikki代理面板 (nikki)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES nikki luci-app-nikki luci-i18n-nikki-zh-cn"

# openclash代理面板 (openclash)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-openclash"

# 分区扩容 (partexp)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-partexp luci-i18n-partexp-zh-cn"

# passwall代理面板 (passwall)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-passwall luci-i18n-passwall-zh-cn"

# 关机 (poweroffdevice)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-poweroffdevice luci-i18n-poweroffdevice-zh-cn"

# 流媒体转发 (rtp2httpd)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES rtp2httpd luci-app-rtp2httpd luci-i18n-rtp2httpd-zh-cn"

# run插件安装工具 (run)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-run"

# VPN代理 (tailscale)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES tailscale luci-app-tailscale luci-i18n-tailscale-zh-cn"

# 定时任务 (taskplan)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-taskplan luci-i18n-taskplan-zh-cn"
