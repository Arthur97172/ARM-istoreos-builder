#!/bin/bash
# 24.10.x 第三方插件配置 (IPK 格式) - x86-64 专用
# 启用第三方插件时取消对应注释

# argon主题 (argon)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-argon-config luci-theme-argon luci-i18n-argon-config-zh-cn"

# aurora主题 (aurora)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-aurora-config luci-theme-aurora luci-i18n-aurora-config-zh-cn"

# 网络流量监控 (bandix)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES bandix luci-app-bandix luci-i18n-bandix-zh-cn"

# 网络流量监控 (bandix-plus)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES bandix-plus luci-app-bandix-plus luci-i18n-bandix-plus-zh-cn"

# clashoo代理面板 (clashoo)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES clashoo luci-app-clashoo luci-i18n-clashoo-zh-cn"

# daede代理面板 (daede)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES dae daed luci-app-daede"

# DNS转发器 (MosDNS)
USTOM_PACKAGES="$CUSTOM_PACKAGES mosdns luci-app-mosdns luci-i18n-mosdns-zh-cn"

# 网络设置向导 (netwizard)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-netwizard luci-i18n-netwizard-zh-cn"

# nikki代理面板 (nikki)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES nikki luci-app-nikki luci-i18n-nikki-zh-cn"

# openclash代理面板 (openclash)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-openclash"

# 分区扩容 (partexp)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-partexp luci-i18n-partexp-zh-cn"

# passwall代理面板 (passwall)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-passwall luci-i18n-passwall-zh-cn"

# 关机 (poweroffdevice)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-poweroffdevice luci-i18n-poweroffdevice-zh-cn"

# 文件管理器 (quickfile)
#CUSTOM_PACKAGES="$CUSTOM_PACKAGES quickfile luci-app-quickfile luci-i18n-quickfile-zh-cn"

# VPN代理 (tailscale)
CUSTOM_PACKAGES="$CUSTOM_PACKAGES tailscale luci-app-tailscale luci-i18n-tailscale-zh-cn"
