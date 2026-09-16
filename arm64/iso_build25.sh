#!/bin/bash
# Wrt 25.12.x armv8 构建脚本 (APK 格式)
# 在 imagebuilder 目录下运行

# --- 接收外部参数 ---
# 与 build25.sh 约定一致:$1=PROFILE, $2=ROOTFS_PARTSIZE
ROOTFS_PARTSIZE=${2:-"2048"}
INCLUDE_DOCKER=${INCLUDE_DOCKER:-"no"}

echo "Rootfs Size: $ROOTFS_PARTSIZE MB"
echo "Include Docker: $INCLUDE_DOCKER"

# ============================================
# 步骤1: 加载第三方插件配置
# ============================================
CUSTOM_PACKAGES=""
source apk-custom-packages.sh

HAS_CUSTOM_PACKAGES="no"
if [ -n "$CUSTOM_PACKAGES" ]; then
    HAS_CUSTOM_PACKAGES="yes"
    echo "✅ 检测到第三方插件: $CUSTOM_PACKAGES"
fi

# 定义所需安装的包列表
PACKAGES=""

# [核心系统 - 不含 libc/libgcc,由 base 系统提供]
PACKAGES="$PACKAGES base-files uci ubus dropbear logd mtd bash htop curl wget ca-bundle ca-certificates"
PACKAGES="$PACKAGES -dnsmasq dnsmasq-full firewall4 nftables kmod-nft-offload nano"
PACKAGES="$PACKAGES -odhcpd odhcpd-ipv6only odhcp6c"
PACKAGES="$PACKAGES -libustream-mbedtls -libustream-wolfssl libustream-openssl"
PACKAGES="$PACKAGES ip-full ipset iw ppp ppp-mod-pppoe -wpad-basic-mbedtls -wpad-mbedtls -wpad-openssl wpad-mesh-openssl luci-proto-ppp luci-proto-ipv6"
PACKAGES="$PACKAGES kmod-tcp-bbr"

# [硬件驱动]
PACKAGES="$PACKAGES -kmod-ath10k-sdio kmod-ath10k"
PACKAGES="$PACKAGES kmod-ata-ahci kmod-mmc kmod-r8125 kmod-r8168 kmod-r8169 r8169-firmware"

# [磁盘与文件系统]
PACKAGES="$PACKAGES block-mount fdisk lsblk blkid parted resize2fs smartmontools"
PACKAGES="$PACKAGES kmod-fs-ext4 kmod-fs-vfat kmod-fs-ntfs3 kmod-fs-exfat kmod-fs-btrfs kmod-fs-f2fs"
PACKAGES="$PACKAGES kmod-usb-storage kmod-usb-storage-uas kmod-usb2 kmod-usb3"

# [USB 网卡驱动]
PACKAGES="$PACKAGES kmod-usb-net kmod-usb-net-rtl8150 kmod-usb-net-rtl8152 r8152-firmware"
PACKAGES="$PACKAGES kmod-usb-net-asix-ax88179 kmod-usb-net-aqc111"
PACKAGES="$PACKAGES kmod-usb-net-cdc-ether kmod-usb-net-cdc-ncm kmod-usb-net-cdc-mbim"

# [无线驱动]
PACKAGES="$PACKAGES kmod-brcmfmac kmod-brcmsmac"
PACKAGES="$PACKAGES brcmfmac-firmware-usb brcmfmac-firmware-43430-sdio brcmfmac-firmware-43455-sdio"
PACKAGES="$PACKAGES kmod-usb-ohci kmod-usb-ohci-pci kmod-usb-core kmod-usb2-pci usbutils"
PACKAGES="$PACKAGES kmod-mac80211"
PACKAGES="$PACKAGES kmod-mt7921-common kmod-mt7921-firmware kmod-mt7921e kmod-mt7921u"
PACKAGES="$PACKAGES kmod-mt7922-firmware kmod-mt7925-common kmod-mt7925-firmware kmod-mt7925e kmod-mt7925u"
PACKAGES="$PACKAGES kmod-mt792x-common kmod-mt792x-usb"
PACKAGES="$PACKAGES kmod-mt7992-23-firmware kmod-mt7992-firmware"
PACKAGES="$PACKAGES kmod-mt7996-233-firmware kmod-mt7996-firmware kmod-mt7996-firmware-common kmod-mt7996e kmod-mtk-t7xx"

# [Web 界面]
PACKAGES="$PACKAGES luci luci-base luci-i18n-base-zh-cn luci-mod-admin-full luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-app-ttyd luci-i18n-ttyd-zh-cn"

# [功能插件]
PACKAGES="$PACKAGES luci-app-samba4 luci-i18n-samba4-zh-cn"
PACKAGES="$PACKAGES luci-app-upnp luci-i18n-upnp-zh-cn"
PACKAGES="$PACKAGES luci-app-wol luci-i18n-wol-zh-cn"
PACKAGES="$PACKAGES luci-app-ddns luci-i18n-ddns-zh-cn"
PACKAGES="$PACKAGES luci-app-package-manager luci-i18n-package-manager-zh-cn"

# Docker 插件
if [ "$INCLUDE_DOCKER" = "yes" ]; then
    echo "🐳 Docker enabled, adding docker packages"
    PACKAGES="$PACKAGES docker docker-compose luci-app-dockerman luci-i18n-dockerman-zh-cn"
fi

# ============================================
# 步骤2: 处理第三方插件(最佳努力,失败不阻断构建)
# ============================================
THIRD_PARTY_OK=0
if [ "$HAS_CUSTOM_PACKAGES" = "yes" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始处理第三方APK..."

    # 克隆 OpenWrt-App 仓库 (best-effort)
    echo "克隆 OpenWrt-App 仓库..."
    rm -rf /tmp/store-repo
    if git clone --depth=1 https://github.com/Arthur97172/OpenWrt-App.git /tmp/store-repo 2>/tmp/git-clone.log; then
        THIRD_PARTY_OK=1
    else
        echo "⚠️ git clone 失败(继续构建,不含第三方插件):"
        sed 's/^/    /' /tmp/git-clone.log
    fi
fi

if [ "$THIRD_PARTY_OK" = "1" ]; then
    # 创建临时目录存放第三方 APK
    mkdir -p thirdparty

    # 复制第三方 APK 到临时目录(不覆盖 base 包)
    # rockchip/armv8 兼容 aarch64_generic 和 aarch64_cortex-a53;优先 aarch64_generic
    echo "复制第三方 APK 到 thirdparty/ 目录..."
    mkdir -p apk-merged thirdparty
    if [ -d /tmp/store-repo/apk/aarch64_generic ]; then
        find /tmp/store-repo/apk/aarch64_generic -name '*.apk' -exec cp -t apk-merged {} + 2>/dev/null || true
    fi

   # if [ -d /tmp/store-repo/apk/aarch64_cortex-a53 ]; then
   #     find /tmp/store-repo/apk/aarch64_cortex-a53 -name '*.apk' -exec cp -t apk-merged {} + 2>/dev/null || true
   # fi
    
    if [ -d apk-merged ] && [ -n "$(ls apk-merged/*.apk 2>/dev/null)" ]; then
        cp apk-merged/*.apk thirdparty/ 2>/dev/null
    else
        echo "⚠️ 未在仓库中找到 aarch64*/.apk,跳过第三方"
        THIRD_PARTY_OK=0
    fi

    APK_COUNT=$(find thirdparty -name '*.apk' 2>/dev/null | wc -l)
    echo "✅ 第三方目录现有 $APK_COUNT 个APK文件"
    if [ "$APK_COUNT" -eq 0 ]; then
        echo "⚪️ 未获取到任何第三方 apk,继续构建"
        THIRD_PARTY_OK=0
    fi
fi

if [ "$THIRD_PARTY_OK" = "1" ]; then
    # 把第三方 APK 物理放入 ImageBuilder 的 packages/ 目录,并显式重建
    # SIGNED packages.adb 索引。IB 默认的 `apk mkndx` 在出错时静默吞 stderr,
    # 后面 make image 会找不到包。
    echo "复制第三方 APK 到 imagebuilder/packages/ ..."
    mkdir -p packages

    # 排除已知不可用的 APK(glob),空就是不过滤
    SKIP_APKS=""

    APK_BIN="staging_dir/host/bin/apk"
    APK_KEYS_DIR="keys"
    APK_SIGN_KEY="$APK_KEYS_DIR/local-private-key.pem"
    if [ ! -s "$APK_SIGN_KEY" ]; then
        APK_SIGN_KEY="$APK_KEYS_DIR/build_key.apk.sec"
    fi

    # 把 apk 重命名为 canonical 名称 "{name}-{version}.apk"。apk-tools 在
    # add 时按 canonical 名查包,文件名 (比如带 -x86_64 后缀) 与 adb 里
    # 登记的 (name-version) 不一致,会抛 "package mentioned in index not
    # found"。这里用 `apk adbdump` 读 metadata 里的 name+version 后重命名。
    echo "🔖 重命名 apk 为 canonical 名称(name-version.apk)..."
    canoned=0
    cached=0
    skipped=0
    for f in thirdparty/*.apk; do
        [ -e "$f" ] || continue
        base=$(basename "$f")
        skip=0
        for s in $SKIP_APKS; do
            case "$base" in $s) skip=1 ;; esac
        done
        if [ "$skip" = "1" ]; then
            echo "  ↷ 跳过: $base"
            continue
        fi
        canon_name=$("$APK_BIN" adbdump "$f" 2>/dev/null \
            | awk '/^  name:/ {name=$2} /^  version:/ {ver=$2; print name; print ver}' | head -2)
        canon_pkg=$(echo "$canon_name" | head -1)
        canon_ver=$(echo "$canon_name" | sed -n '2p')
        if [ -z "$canon_pkg" ] || [ -z "$canon_ver" ]; then
            echo "  ⚠️ 无法读 metadata(可能是损坏的 apk):$base — 跳过"
            continue
        fi
        target="$canon_pkg-$canon_ver.apk"
        if [ -f "packages/$target" ] && [ "packages/$target" -nt "$f" ]; then
            cached=$((cached+1))
            continue
        fi
        cp -f "$f" "packages/$target"
        canoned=$((canoned+1))
    done
    echo "📦 重命名 $canoned 新 apk,缓存 $cached 个,跳过 $skipped 个"
    PKG_IN_POOL=$(ls packages/*.apk 2>/dev/null | wc -l)
    echo "✅ 第三方 APK 已合并到 packages/ (池中现共 $PKG_IN_POOL 个文件)"

    # 在 mkndx 之前先准备好 EC 签名 key。IB Makefile 的 _check_keys 目标
    # 是在 mkndx 之后才生成 keys,而我们的 mkndx 在这之前运行,所以
    # 生成的 packages.adb 是未签名的,后面 apk add 会判 UNTRUSTED。
    OPENSSL_BIN="staging_dir/host/bin/openssl"
    NE_KEY="$APK_KEYS_DIR/local-private-key.pem"
    NEED_KEY_GEN=0
    if [ ! -s "$NE_KEY" ] && [ ! -s "$APK_KEYS_DIR/build_key.apk.sec" ]; then
        NEED_KEY_GEN=1
    fi
    if [ "$NEED_KEY_GEN" = "1" ] && [ -x "$OPENSSL_BIN" ]; then
        echo "🔑 预生成 EC 签名 key(与 IB _check_keys 一致)..."
        mkdir -p "$APK_KEYS_DIR"
        if ! "$OPENSSL_BIN" ecparam -name prime256v1 -genkey -noout -out "$NE_KEY" 2>/dev/null; then
            echo "⚠️ ecparam 生成私钥失败,继续依赖 IB 的 _check_keys"
        else
            # IB sed: '1s/^/untrusted comment: Local build key\n/'
            sed -i '1s/^/untrusted comment: Local build key\n/' "$NE_KEY" 2>/dev/null
            if "$OPENSSL_BIN" ec -in "$NE_KEY" -pubout > "$APK_KEYS_DIR/local-public-key.pem" 2>/dev/null; then
                sed -i '1s/^/untrusted comment: Local build key\n/' "$APK_KEYS_DIR/local-public-key.pem" 2>/dev/null
                ls -la "$APK_KEYS_DIR/"
                echo "✅ EC key 就绪:$NE_KEY"
            else
                echo "⚠️ 导出公钥失败,继续依赖 IB 的 _check_keys"
            fi
        fi
    fi

    # 在 IB 子目录内运行 ../staging_dir/host/bin/apk mkndx。
    run_mkndx() {
        local args=("$@")
        local cmd=(../"$APK_BIN" mkndx)
        if [ -s "$APK_SIGN_KEY" ]; then
            cmd+=(--keys-dir "$(pwd)/$APK_KEYS_DIR")
            cmd+=(--sign "$(pwd)/$APK_SIGN_KEY")
        fi
        cmd+=(--allow-untrusted --output packages.adb "${args[@]}")
        "${cmd[@]}"
    }

    if [ -x "$APK_BIN" ]; then
        # IB 25.12.x 默认 CONFIG_SIGNATURE_CHECK=y,所有 packages.adb 必
        # 须用 local-private-key.pem 签名,否则 apk 读到时 UNTRUSTED。
        APK_FILES=()
        for f in packages/*.apk; do
            [ -e "$f" ] || continue
            APK_FILES+=("$(basename "$f")")
        done
        PKG_COUNT="${#APK_FILES[@]}"
        echo "🔧 显式重建 SIGNED packages.adb 索引(待索引 apk 数量: $PKG_COUNT)..."
        if [ "$PKG_COUNT" -eq 0 ]; then
            echo "⚠️ packages/ 是空的,没有 apk 可索引,跳过"
        elif (cd packages && run_mkndx "${APK_FILES[@]}"); then
            echo "✅ SIGNED packages.adb 已就绪 ($PKG_COUNT 个 apk)"
        else
            echo "⚠️ mkndx 整体失败,逐个诊断损坏的 apk ..."
            BAD=()
            for entry in "${APK_FILES[@]}"; do
                if ! (cd packages && run_mkndx "$entry"); then
                    echo "  ✗ 损坏: packages/$entry"
                    BAD+=("$entry")
                fi
            done
            if [ "${#BAD[@]}" -gt 0 ]; then
                echo "🚮 暂时移出损坏的 apk ..."
                mkdir -p packages/.bad
                for entry in "${BAD[@]}"; do
                    mv "packages/$entry" "packages/.bad/$entry"
                done
                APK_FILES=()
                for f in packages/*.apk; do
                    [ -e "$f" ] || continue
                    APK_FILES+=("$(basename "$f")")
                done
                if [ "${#APK_FILES[@]}" -eq 0 ]; then
                    echo "⚠️ 没有健康的 apk 留下来,跳过重建"
                elif (cd packages && run_mkndx "${APK_FILES[@]}"); then
                    echo "✅ 已用剩余的健康 apk 重建 SIGNED 索引(损坏 apk 的功能将不可用)"
                else
                    echo "⚠️ 即便移出损坏 apk 后仍无法生成索引,继续依赖 IB 自动重建"
                fi
            fi
        fi

        # 把 packages.adb 的 mtime 设到所有 *.apk 之后,避免 IB 因
        # mkndx 旧而重建产生未签名索引。
        if [ -f packages/packages.adb ]; then
            touch -d "@$(($(date +%s) + 60))" packages/packages.adb 2>/dev/null || \
                touch packages/packages.adb
            echo "🔒 packages.adb mtime 已更新,IB 不会重建"
        fi
    else
        echo "⚠️ 找不到 $APK_BIN,继续依赖 IB 自动重建(不推荐)"
    fi
fi

# ============================================
# 步骤3: 合并第三方插件到包列表
# ============================================
PACKAGES="$PACKAGES $CUSTOM_PACKAGES"

# ============================================
# [Docker 插件]
if [ "$INCLUDE_DOCKER" = "yes" ]; then
    echo "🐳 Docker enabled, adding docker packages"
    PACKAGES="$PACKAGES docker docker-compose luci-app-dockerman luci-i18n-dockerman-zh-cn"
fi

# 若构建openclash 则添加内核
if echo "$PACKAGES" | grep -q "luci-app-openclash"; then
    echo "✅ 已选择 luci-app-openclash，添加 openclash core"
    mkdir -p files/etc/openclash/core
    # Download clash_meta
    META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz"
    wget -qO- $META_URL | tar xOvz > files/etc/openclash/core/clash_meta
    chmod +x files/etc/openclash/core/clash_meta
    # 下载 GeoIP and GeoSite 数据库
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -O files/etc/openclash/GeoIP.dat
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O files/etc/openclash/GeoSite.dat
    echo "✅ openclash预装GeoData 数据库完成！"
else
    echo "⚪️ 未选择 luci-app-openclash"
fi

# 若构建nikki 则添加GeoIP and GeoSite
if echo "$PACKAGES" | grep -q "luci-app-nikki"; then
    # 创建目录
    mkdir -p files/etc/nikki/run/
    # 下载 GeoIP and GeoSite 数据库
    wget -q https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.dat -O files/etc/nikki/run/geoip.dat
    wget -q https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat -O files/etc/nikki/run/geosite.dat
    wget -q https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/country.mmdb -O files/etc/nikki/run/country.mmdb
    wget -q https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/GeoLite2-ASN.mmdb -O files/etc/nikki/run/GeoLite2-ASN.mmdb
    #chmod 755 files/etc/nikki/run/*
    # 下载 Zashboard
    wget -q https://github.com/Zephyruso/zashboard/releases/latest/download/dist.zip -O /tmp/dist.zip
    # 解压 Zashboard
    rm -rf files/etc/nikki/run/ui/*
    mkdir -p files/etc/nikki/run/ui
    # 解压 Zashboard到临时文件夹
    unzip -qo /tmp/dist.zip -d /tmp/zashboard
    # 将 dist 目录中的所有内容复制到 Nikki UI 目录
    cp -a /tmp/zashboard/dist/. files/etc/nikki/run/ui/
    # 删除临时文件
    rm -rf /tmp/zashboard
    rm -f /tmp/dist.zip
    # 设置目录和文件权限
    find files/etc/nikki/run -type d -exec chmod 755 {} \;
    find files/etc/nikki/run -type f -exec chmod 644 {} \;
    echo "✅ Nikki 预装 GeoData + Zashboard 完成！"
else
    echo "⚪️ 未选择 luci-app-nikki"
fi


# 若构建 luci-app-netspeedtest，则自动预装最新稳定版 Ookla Speedtest CLI
if echo "$PACKAGES" | grep -q "luci-app-netspeedtest"; then
    echo "🚀 检测到 luci-app-netspeedtest，开始下载最新稳定版 Ookla Speedtest CLI..."
    # 创建目标目录
    mkdir -p files/usr/libexec/netspeedtest
    OOKLA_ARCH="aarch64"
    # 创建临时目录
    rm -rf /tmp/ookla-speedtest
    mkdir -p /tmp/ookla-speedtest
    # ------------------------------------------------------------
    # 从 Ookla 官方 CLI 页面获取最新稳定版 aarch64 下载地址
    # ------------------------------------------------------------
    OOKLA_URL=$(wget -qO- --no-check-certificate \
        "https://www.speedtest.net/apps/cli" \
        | sed -n '/Download for Linux/,/<\/div>/p' \
        | sed -En "s|.*<a href=\"([^\"]+)\"[^>]*>${OOKLA_ARCH}</a>.*|\1|p" \
        | head -n 1)
    # 如果没有找到 URL，尝试兼容其他 HTML 格式
    if [ -z "$OOKLA_URL" ]; then
        OOKLA_URL=$(wget -qO- --no-check-certificate \
            "https://www.speedtest.net/apps/cli" \
            | grep -oE 'https?://[^"]+linux-aarch64[^"]+\.tgz' \
            | head -n 1)
    fi
    # 检查下载地址
    if [ -z "$OOKLA_URL" ]; then
        echo "❌ 无法从 Ookla 官方页面获取最新稳定版 aarch64 下载地址！"
        rm -rf /tmp/ookla-speedtest
        exit 1
    fi
    # 如果官方页面返回相对路径，则补充官方域名
    case "$OOKLA_URL" in
        http://*|https://*)
            ;;
        /*)
            OOKLA_URL="https://www.speedtest.net${OOKLA_URL}"
            ;;
        *)
            OOKLA_URL="https://www.speedtest.net/${OOKLA_URL}"
            ;;
    esac
    echo "🎯 Ookla ARCH: ${OOKLA_ARCH}"
    echo "🔗 Download: ${OOKLA_URL}"
    # ------------------------------------------------------------
    # 下载 Ookla Speedtest CLI（加入最多重试 5 次机制）
    # ------------------------------------------------------------
    MAX_RETRIES=5
    RETRY_COUNT=0
    DOWNLOAD_SUCCESS=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "📥 正在下载 (尝试 $RETRY_COUNT/$MAX_RETRIES)..."
        
        wget -q --no-check-certificate \
            "$OOKLA_URL" \
            -O /tmp/ookla-speedtest/ookla-speedtest.tgz

        # 检查下载文件是否成功且非空
        if [ -s /tmp/ookla-speedtest/ookla-speedtest.tgz ]; then
            DOWNLOAD_SUCCESS=1
            break
        else
            echo "⚠️ 第 $RETRY_COUNT 次下载失败，等待 5 秒后重试..."
            rm -f /tmp/ookla-speedtest/ookla-speedtest.tgz
            sleep 5
        fi
    done

    # 检查最终下载结果
    if [ $DOWNLOAD_SUCCESS -eq 0 ]; then
        echo "❌ Ookla Speedtest CLI 下载失败，已重试 $MAX_RETRIES 次，终止构建！"
        echo "URL: ${OOKLA_URL}"
        rm -rf /tmp/ookla-speedtest
        exit 1
    fi

    echo "📦 Ookla Speedtest CLI 下载完成："
    ls -lh /tmp/ookla-speedtest/ookla-speedtest.tgz
    # ------------------------------------------------------------
    # 解压
    # ------------------------------------------------------------
    tar -xzf \
        /tmp/ookla-speedtest/ookla-speedtest.tgz \
        -C /tmp/ookla-speedtest
    # 检查 speedtest 二进制
    if [ ! -f /tmp/ookla-speedtest/speedtest ]; then
        echo "❌ 解压后未找到 speedtest 二进制文件！"
        rm -rf /tmp/ookla-speedtest
        exit 1
    fi
    chmod 755 /tmp/ookla-speedtest/speedtest
    echo "🔍 检查 Ookla Speedtest CLI 文件..."
    if command -v file >/dev/null 2>&1; then
        file /tmp/ookla-speedtest/speedtest
    fi
    # 使用 readelf 检查 ELF Machine
    if command -v readelf >/dev/null 2>&1; then
        if ! readelf -h /tmp/ookla-speedtest/speedtest | grep -q "AArch64"; then
            echo "❌ Ookla Speedtest CLI 不是 AArch64 ELF 文件！"
            readelf -h /tmp/ookla-speedtest/speedtest
            rm -rf /tmp/ookla-speedtest
            exit 1
        fi
        echo "✅ 已确认 Ookla Speedtest CLI 为 AArch64 架构"
    fi
    # ------------------------------------------------------------
    # 安装到 luci-app-netspeedtest 实际使用的路径
    # ------------------------------------------------------------
    cp -f \
        /tmp/ookla-speedtest/speedtest \
        files/usr/libexec/netspeedtest/speedtest
    chmod 755 \
        files/usr/libexec/netspeedtest/speedtest
    # 检查最终文件
    if [ ! -x files/usr/libexec/netspeedtest/speedtest ]; then
        echo "❌ Ookla Speedtest CLI 安装失败！"
        rm -rf /tmp/ookla-speedtest
        exit 1
    fi
    echo "✅ 最新稳定版 Ookla Speedtest CLI 预装完成！"
    echo "   ARCH : ${OOKLA_ARCH}"
    echo "   PATH : files/usr/libexec/netspeedtest/speedtest"
    if command -v file >/dev/null 2>&1; then
        file files/usr/libexec/netspeedtest/speedtest
    fi
    # 清理临时文件
    rm -rf /tmp/ookla-speedtest
else
    echo "⚪️ 未选择 luci-app-netspeedtest"
fi

# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始构建......打印所有包名"
echo "$PACKAGES"

# ============================================
# 步骤5: 关闭 apk 签名校验
#
# IB 25.12 .config 默认 CONFIG_SIGNATURE_CHECK=y。我们的第三方 apk 由
# 不同作者发布,IB 的 apk add 读 packages.adb 时会 UNTRUSTED 整库丢弃。
#
# `make image CONFIG_SIGNATURE_CHECK=` 在 GHA 下不能让 apk add 真的
# 接收 --allow-untrusted,因为 IB Makefile 在 child make 之前
# `unset MAKEFLAGS`,把 cmdline override 抹掉;child make 重新读 .config,
# $(if $(CONFIG_SIGNATURE_CHECK),,--allow-untrusted) 退化成 strict-mode。
#
# 改方案: 直接 sed 改 .config 把 CONFIG_SIGNATURE_CHECK 设为空,
# parent 和 child 都读到空,apk add 拿到 --allow-untrusted。
# ============================================
if [ -f .config ] && grep -q "^CONFIG_SIGNATURE_CHECK=y" .config; then
    cp .config .config.bak.imm
    sed -i 's/^CONFIG_SIGNATURE_CHECK=y$/CONFIG_SIGNATURE_CHECK=/' .config
    echo "🔓 .config: CONFIG_SIGNATURE_CHECK 已置空(原值备份到 .config.bak.imm)"
    grep -n '^CONFIG_SIGNATURE_CHECK' .config
fi

#if [ -f Makefile ]; then
#    # 替换其中的默认签名检查开关，加上未信任签名放行参数
#    sed -i 's/--keys-dir/--allow-untrusted --keys-dir/g' Makefile 2>/dev/null || true
#fi

# ============================================
# 步骤6: 执行 make image
# ============================================
ROOTFS_PARTSIZE=${ROOTFS_PARTSIZE:-"2048"}
make image PROFILE=generic PACKAGES="$PACKAGES" FILES="files" ROOTFS_PARTSIZE=$ROOTFS_PARTSIZE

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
