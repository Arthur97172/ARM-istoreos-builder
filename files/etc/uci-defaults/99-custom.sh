#!/bin/sh
# 仅首次运行 Wrt 时执行以下脚本，重启后消失

LOGFILE="/tmp/uci-defaults-log.txt"

echo "========================================" >> "$LOGFILE"
echo "Starting 99-custom.sh at $(date)" >> "$LOGFILE"
echo "========================================" >> "$LOGFILE"

# =========================================================
# 基础设置
# =========================================================

wan_zone=$(uci show firewall 2>/dev/null |
    awk -F '[.=]' '/^firewall\.[^.]+\.name=.wan.$/ {print $2; exit}')

if [ -n "$wan_zone" ]; then
    uci -q set "firewall.$wan_zone.input=ACCEPT"
    echo "Firewall WAN zone: $wan_zone -> input ACCEPT" >> "$LOGFILE"
else
    uci -q set firewall.@zone[1].input='ACCEPT'
    echo "WARNING: WAN zone not found, fallback to firewall.@zone[1]" >> "$LOGFILE"
fi

if ! uci show dhcp 2>/dev/null |
    grep -q "name='time.android.com'"; then
    uci -q add dhcp domain
    uci -q set "dhcp.@domain[-1].name=time.android.com"
    uci -q set "dhcp.@domain[-1].ip=203.107.6.88"
    echo "Added DHCP domain: time.android.com -> 203.107.6.88" >> "$LOGFILE"
else
    echo "DHCP domain time.android.com already exists" >> "$LOGFILE"
fi

uci -q set system.@system[0].hostname='iStoreOS'
uci -q set system.@system[0].timezone='CST-8'
uci -q set system.@system[0].zonename='Asia/Taipei'
uci -q set luci.main.lang='zh_cn'

# =========================================================
# 检测 Ethernet 用户端口
# =========================================================

ifnames=""

for iface in /sys/class/net/*; do
    [ -e "$iface" ] || continue
    iface_name="${iface##*/}"

    case "$iface_name" in
        lo|br-*|wlan*|wl*|phy*)
            continue
            ;;
    esac

    [ -d "$iface/wireless" ] && continue
    [ -d "$iface/phy80211" ] && continue

    [ -e "$iface/device" ] || continue
    dev_target=$(readlink -f "$iface/device" 2>/dev/null)
    [ -n "$dev_target" ] || continue

    echo "$dev_target" | grep -q '/virtual/' && continue

    link_info=$(ip -d link show "$iface_name" 2>/dev/null)

    is_dsa_port=0
    if echo "$link_info" | grep -q 'portname '; then
        is_dsa_port=1
    fi

    if [ "$is_dsa_port" -eq 0 ]; then
        dsa_conduit=0
        for other_iface in /sys/class/net/*; do
            [ -e "$other_iface" ] || continue
            other_name="${other_iface##*/}"
            [ "$other_name" = "$iface_name" ] && continue

            case "$other_name" in
                lo|br-*|wlan*|wl*|phy*)
                    continue
                    ;;
            esac

            other_info=$(ip -d link show "$other_name" 2>/dev/null)
            if echo "$other_info" | grep -q "dsa conduit $iface_name"; then
                dsa_conduit=1
                break
            fi
        done

        if [ "$dsa_conduit" -eq 1 ]; then
            echo "Excluded DSA conduit: $iface_name" >> "$LOGFILE"
            continue
        fi
    fi

    ifnames="${ifnames:+$ifnames }$iface_name"
done

set -- $ifnames
count=$#

echo "Detected Ethernet user ports: $ifnames" >> "$LOGFILE"
echo "Ethernet user port count: $count" >> "$LOGFILE"

# =========================================================
# 网络设置
# =========================================================

if [ "$count" -eq 0 ]; then
    echo "ERROR: No Ethernet user port detected!" >> "$LOGFILE"
elif [ "$count" -eq 1 ]; then
    only_port="$1"
    echo "Single Ethernet user port detected: $only_port" >> "$LOGFILE"
    echo "Configuring LAN as DHCP." >> "$LOGFILE"

    uci -q set network.lan.proto='dhcp'
    uci -q delete network.lan.ipaddr
    uci -q delete network.lan.netmask
    uci -q delete network.lan.gateway
    uci -q delete network.lan.dns
else
    echo "Multiple Ethernet user ports detected." >> "$LOGFILE"
    wan_ifname=""

    configured_wan=$(uci -q get network.wan.device 2>/dev/null)
    if [ -n "$configured_wan" ]; then
        for port in $ifnames; do
            if [ "$port" = "$configured_wan" ]; then
                wan_ifname="$port"
                break
            fi
        done
        [ -n "$wan_ifname" ] && echo "Using existing configured WAN device: $wan_ifname" >> "$LOGFILE"
    fi

    if [ -z "$wan_ifname" ]; then
        for port in $ifnames; do
            if [ "$port" = "wan" ]; then
                wan_ifname="$port"
                echo "Detected standard WAN interface: $wan_ifname" >> "$LOGFILE"
                break
            fi
        done
    fi

    if [ -z "$wan_ifname" ]; then
        wan_ifname="$1"
        echo "WARNING: Cannot determine WAN automatically." >> "$LOGFILE"
        echo "Fallback WAN interface: $wan_ifname" >> "$LOGFILE"
    fi

    lan_ifnames=""
    for port in $ifnames; do
        [ "$port" = "$wan_ifname" ] && continue
        lan_ifnames="${lan_ifnames:+$lan_ifnames }$port"
    done

    echo "WAN interface: $wan_ifname" >> "$LOGFILE"
    echo "LAN interfaces: $lan_ifnames" >> "$LOGFILE"

    uci -q set network.wan=interface
    uci -q set network.wan.device="$wan_ifname"
    uci -q set network.wan.proto='dhcp'
    uci -q set network.wan6=interface
    uci -q set network.wan6.device="$wan_ifname"
    uci -q set network.wan6.proto='dhcpv6'

    section=$(uci show network 2>/dev/null |
        awk -F '[.=]' '/^network\.[^.]+\.name=['"'"'"]br-lan['"'"'"]$/ {print $2; exit}')

    if [ -n "$section" ]; then
        echo "Found br-lan device section: $section" >> "$LOGFILE"
        uci -q delete "network.$section.ports"
        for port in $lan_ifnames; do
            uci -q add_list "network.$section.ports=$port"
        done
        echo "br-lan ports updated: $lan_ifnames" >> "$LOGFILE"
    else
        first_lan_port=$(echo "$lan_ifnames" | awk '{print $1}')
        if [ -n "$first_lan_port" ]; then
            uci -q set network.lan.device="$first_lan_port"
            echo "WARNING: Cannot find br-lan device." >> "$LOGFILE"
            echo "Fallback LAN device: $first_lan_port" >> "$LOGFILE"
        else
            echo "ERROR: No LAN port available!" >> "$LOGFILE"
        fi
    fi

    # LAN 静态 IP (恢复直接写入占位符)
    uci -q set network.lan.proto='static'
    uci -q set network.lan.ipaddr='__IPADDR__'
    uci -q set network.lan.netmask='255.255.255.0'
    echo "LAN IP set to: __IPADDR__/24" >> "$LOGFILE"
fi

# =========================================================
# SSH / Web 管理 & 保存配置
# =========================================================

uci -q delete ttyd.@ttyd[0].interface
uci -q set dropbear.@dropbear[0].Interface=''

uci commit system
uci commit luci
uci commit firewall
uci commit dhcp
uci commit network
uci commit dropbear
uci -q commit ttyd

if [ -f /etc/banner1/banner ]; then
    cp -f /etc/banner1/banner /etc/
fi
[ -d /etc/banner1 ] && rm -rf /etc/banner1

FILE_PATH="/etc/openwrt_release"
NEW_DESCRIPTION="iStoreOS VERXXXX"
if [ -f "$FILE_PATH" ]; then
    sed -i "s/DISTRIB_DESCRIPTION='[^']*'/DISTRIB_DESCRIPTION='$NEW_DESCRIPTION'/" "$FILE_PATH"
fi

echo "========================================" >> "$LOGFILE"
echo "Final Ethernet ports: $ifnames" >> "$LOGFILE"
echo "Final Ethernet port count: $count" >> "$LOGFILE"
if [ "$count" -gt 1 ]; then
    echo "Final WAN: $wan_ifname" >> "$LOGFILE"
    echo "Final LAN: $lan_ifnames" >> "$LOGFILE"
fi
echo "99-custom.sh completed at $(date)" >> "$LOGFILE"
echo "========================================" >> "$LOGFILE"

exit 0
