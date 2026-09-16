#!/bin/sh
# 仅首次运行iStoreOS时，会执行以下脚本。重启后消失

LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >>$LOGFILE

# 基础设置
uci set firewall.@zone[1].input='ACCEPT'
uci add dhcp domain
uci set "dhcp.@domain[-1].name=time.android.com"
uci set "dhcp.@domain[-1].ip=203.107.6.88"
uci set system.@system[0].hostname='iStoreOS'
uci set system.@system[0].timezone='CST-8'
uci set system.@system[0].zonename='Asia/Shanghai'
uci set luci.main.lang='zh_cn'
uci commit system
uci commit luci

# 检查 PPPoE 配置
SETTINGS_FILE="/etc/config/pppoe-settings"
[ -f "$SETTINGS_FILE" ] && . "$SETTINGS_FILE"

# 计算网卡物理接口数量
ifnames=""
for iface in /sys/class/net/*; do
    iface_name=$(basename "$iface")
    if [ "$iface_name" != "lo" ] && [ "$iface_name" != "br-lan" ] && \
       ! echo "$iface_name" | grep -qE '^br-|phy|ap'; then
        ifnames="$ifnames $iface_name"
    fi
done
ifnames=$(echo "$ifnames" | awk '{$1=$1};1')
count=$(echo "$ifnames" | wc -w)
# 网络设置
if [ "$count" -eq 1 ]; then
    # 单网口设备：采用 DHCP 模式（旁路由）
    uci set network.lan.proto='dhcp'
    uci -q delete network.lan.ipaddr
    uci -q delete network.lan.netmask
    uci -q delete network.lan.gateway
    uci -q delete network.lan.dns
elif [ "$count" -gt 1 ]; then
    # 多网口设备：第一个网口作为 WAN
    wan_ifname=$(echo "$ifnames" | awk '{print $1}')
    # 剩余网口作为 LAN
    lan_ifnames=$(echo "$ifnames" | cut -d ' ' -f2-)
    # WAN 配置
    uci set network.wan=interface
    uci set network.wan.device="$wan_ifname"
    uci set network.wan.proto='dhcp'
    # WAN6 配置
    uci set network.wan6=interface
    uci set network.wan6.device="$wan_ifname"
    # br-lan 端口配置
    section=$(uci show network | awk -F '[.=]' \
        '/\.@?device\[\d+\]\.name=.br-lan.$/ {print $2; exit}')
    if [ -z "$section" ]; then
        echo "error: cannot find device 'br-lan'." >> "$LOGFILE"
    else
        uci -q delete "network.$section.ports"
        for port in $lan_ifnames; do
            uci add_list "network.$section.ports"="$port"
        done
        echo "ports of device 'br-lan' updated." >> "$LOGFILE"
    fi
    # 多网口 LAN 必须明确指定静态 IP（Workflow 的 sed 会自动替换 __IPADDR__）
    uci set network.lan.proto='static'
    uci set network.lan.ipaddr='__IPADDR__'
    uci set network.lan.netmask='255.255.255.0'
fi
# =========================
# SSH / Web 管理
# =========================
uci delete ttyd.@ttyd[0].interface
uci set dropbear.@dropbear[0].Interface=''
# =========================
# 保存配置
# =========================
uci commit network
uci commit
# 清理并还原 Banner
cp /etc/banner1/banner /etc/
rm -r /etc/banner1

# 设置作者描述信息
FILE_PATH="/etc/openwrt_release"
NEW_DESCRIPTION="iStoreOS VERXXXX"
sed -i "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$NEW_DESCRIPTION'/" "$FILE_PATH"

exit 0
