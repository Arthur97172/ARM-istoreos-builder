#!/bin/sh
# 仅首次运行iStoreOS时，会执行以下脚本。重启后消失

LOGFILE="/etc/config/uci-defaults-log.txt"
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

# 1. 物理接口自动识别
ifnames=""
for iface in /sys/class/net/*; do
    iface_name=$(basename "$iface")
    if [ -e "$iface/device" ] && echo "$iface_name" | grep -Eq '^eth|^en'; then
        ifnames="$ifnames $iface_name"
    fi
done
ifnames=$(echo "$ifnames" | awk '{$1=$1};1')
count=$(echo "$ifnames" | wc -w)

# 2. 硬件板号兼容性映射
board_name=$(cat /tmp/sysinfo/board_name 2>/dev/null || echo "unknown")
case "$board_name" in
    "radxa,e20c"|"friendlyarm,nanopi-r5c")
        wan_ifname="eth1"
        lan_ifnames="eth0"
        ;;
    *)
        wan_ifname=$(echo "$ifnames" | awk '{print $1}')
        lan_ifnames=$(echo "$ifnames" | cut -d ' ' -f2-)
        ;;
esac

# 3. 网络拓扑配置
if [ "$count" -eq 1 ]; then
    # 单网口默认设为 DHCP（Workflow 会根据选择修改此逻辑）
    uci set network.lan.proto='dhcp'
    uci delete network.lan.ipaddr
    uci delete network.lan.netmask
elif [ "$count" -gt 1 ]; then
    # 多网口配置 WAN
    uci set network.wan=interface
    uci set network.wan.device="$wan_ifname"
    uci set network.wan.proto='dhcp'
    
    # 绑定 br-lan 端口
    section=$(uci show network | awk -F '[.=]' '/\.@?device\[\d+\]\.name=.br-lan.$/ {print $2; exit}')
    if [ -n "$section" ]; then
        uci -q delete "network.$section.ports"
        for port in $lan_ifnames; do uci add_list "network.$section.ports"="$port"; done
    fi

    # PPPoE 逻辑
    if [ "$enable_pppoe" = "yes" ]; then
        uci set network.wan.proto='pppoe'
        uci set network.wan.username="$pppoe_account"
        uci set network.wan.password="$pppoe_password"
    fi
fi

# 4. LAN 静态 IP 设置 (此段会被 Workflow 的 sed 匹配并修改)
# 注意：如果是单网口且用户在 Action 选了 DHCP，Workflow 会删掉下面这两行并把 proto 改为 dhcp
uci set network.lan.proto='static'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.ipaddr='__IPADDR__'

# 权限与服务
uci delete ttyd.@ttyd[0].interface
uci set dropbear.@dropbear[0].Interface=''
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
