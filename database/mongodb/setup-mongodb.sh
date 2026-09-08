#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "=== [$(date)] 開始自動配置 MongoDB ==="

# 1. 偵測並處理 systemd 原生服務
CONF_FILE=""
SERVICE_NAME=""

if [ -f /etc/mongod.conf ]; then
    CONF_FILE="/etc/mongod.conf"
    SERVICE_NAME="mongod"
elif [ -f /etc/mongodb.conf ]; then
    CONF_FILE="/etc/mongodb.conf"
    SERVICE_NAME="mongodb"
fi

if [ -n "$CONF_FILE" ]; then
    echo "找到設定檔: $CONF_FILE，修改監聽 IP..."
    sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' "$CONF_FILE" || true
    sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/' "$CONF_FILE" || true

    systemctl daemon-reload || true
    systemctl restart "$SERVICE_NAME" || true
    systemctl enable "$SERVICE_NAME" || true
fi

# 2. 如果是用 Docker 容器跑的 MongoDB
if command -v docker &> /dev/null; then
    CONTAINER_ID=$(docker ps -q --filter "ancestor=mongo" -f "name=mongo" | head -n 1)
    if [ -n "$CONTAINER_ID" ]; then
        echo "偵測到 MongoDB 運行於 Docker 容器 ($CONTAINER_ID)..."
    fi
fi

# 3. 循環重試等待 Port 27017 就緒 (最多等 15 秒)
echo "檢查 MongoDB Port 27017 監聽狀態..."
READY=0
for i in {1..15}; do
    if ss -tulpn | grep -q ":27017"; then
        READY=1
        break
    fi
    sleep 1
done

if [ $READY -eq 1 ]; then
    echo "=== [$(date)] MongoDB 成功啟動並監聽 Port 27017 ==="
else
    echo "=== [$(date)] 警告: MongoDB Port 27017 監聽異常 ===" >&2
    # 輸出目前監聽的 Port 與服務狀態協助排查
    ss -tulpn || true
    systemctl status "$SERVICE_NAME" --no-pager || true
    exit 1
fi
