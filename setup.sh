#!/bin/bash

# ==============================================================
# SAP BAS Proxy Auto-Deploy (With Watchdog)
# ==============================================================

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
INSTALL_DIR="$HOME/.sap-proxy"
XRAY_VERSION="v1.8.4" 
PORT=8080
WS_PATH="/ray"
UUID=$(cat /proc/sys/kernel/random/uuid)
CF_TOKEN=""
DOMAIN=""

# 帮助
usage() {
    echo -e "${BLUE}Usage:${NC} $0 -t <CF_TOKEN> -d <DOMAIN> [-u <UUID>]"
    exit 1
}

# 解析参数
while getopts "t:d:u:" opt; do
  case $opt in
    t) CF_TOKEN="$OPTARG" ;;
    d) DOMAIN="$OPTARG" ;;
    u) UUID="$OPTARG" ;;
    *) usage ;;
  esac
done

if [ -z "$CF_TOKEN" ] || [ -z "$DOMAIN" ]; then
    usage
fi

echo -e "${GREEN}>>> Installing to $INSTALL_DIR ...${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 1. 下载核心文件
if [ ! -f "xray" ]; then
    wget -q -O xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip"
    unzip -q -o xray.zip && rm xray.zip && chmod +x xray
fi

if [ ! -f "cloudflared" ]; then
    wget -q -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
    chmod +x cloudflared
fi

# 2. 生成配置文件 config.json
cat > config.json <<EOF
{
  "log": { "loglevel": "error" },
  "inbounds": [
    {
      "port": $PORT,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": { "clients": [ { "id": "$UUID", "level": 0 } ], "decryption": "none" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "$WS_PATH" } }
    }
  ],
  "outbounds": [ { "protocol": "freedom" } ]
}
EOF

# 3. 生成启动脚本 run.sh (被监控调用的脚本)
cat > run.sh <<EOF
#!/bin/bash
cd "$INSTALL_DIR"
# Start Xray if not running
if ! pgrep -x "xray" > /dev/null; then
    nohup ./xray -c config.json > /dev/null 2>&1 &
fi
# Start Cloudflared if not running
if ! pgrep -f "cloudflared tunnel" > /dev/null; then
    nohup ./cloudflared tunnel --no-autoupdate run --token $CF_TOKEN > /dev/null 2>&1 &
fi
EOF
chmod +x run.sh

# 4. 注入 .bashrc (包含您的监控钩子)
# 先清理旧的配置
sed -i '/# SAP Proxy Hook/d' ~/.bashrc
sed -i '/monitor_proxy_sap/,/fi/d' ~/.bashrc

# 写入新的 Hook
echo -e "${YELLOW}>>> Injecting Monitor Hook to .bashrc...${NC}"
cat >> ~/.bashrc <<EOF

# SAP Proxy Hook & Watchdog
if [ -f "$INSTALL_DIR/run.sh" ]; then
    # 1. Initial start
    bash "$INSTALL_DIR/run.sh" >/dev/null 2>&1 &

    # 2. Define Monitor Function
    monitor_proxy_sap() {
        while true; do
            # Check processes
            if ! pgrep -x "xray" >/dev/null 2>&1 || ! pgrep -f "cloudflared tunnel" >/dev/null 2>&1; then
                bash "$INSTALL_DIR/run.sh" >/dev/null 2>&1 &
            fi
            sleep 30
        done
    }

    # 3. Start Monitor (Singleton check to prevent duplicates in multiple terminals)
    # We check if the function name appears in process list (tricky) or just check for the sleep loop
    # Here we use a simple pid check or just run it. 
    # Since sleep 30 is low cost, we allow it, or we can check if a loop is running.
    # Ideally, pgrep -f "sleep 30" is too generic.
    # Let's accept one instance per terminal session or rely on run.sh being idempotent.
    
    # Simple approach: Run it in background and disown
    monitor_proxy_sap >/dev/null 2>&1 & disown
fi
EOF

# 5. 首次启动
bash ./run.sh

# 6. 打印链接
VLESS_LINK="vless://${UUID}@${DOMAIN}:443?security=tls&encryption=none&type=ws&path=${WS_PATH//\//%2F}&host=${DOMAIN}&sni=${DOMAIN}#SAP-BAS-Proxy"

echo -e "\n${GREEN}================ SUCCESS ================${NC}"
echo -e " UUID: ${UUID}"
echo -e " Domain: ${DOMAIN}"
echo -e "${YELLOW}${VLESS_LINK}${NC}"
echo -e "${GREEN}=========================================${NC}"
