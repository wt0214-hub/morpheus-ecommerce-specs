#!/bin/bash
set -e

# 避免 apt-get 安裝或更新時彈出互動式對話框卡死自動化流程
export DEBIAN_FRONTEND=noninteractive

echo "=== [$(date)] 開始自動配置 MongoDB ==="

# 判斷設定檔路徑（相容 mongod.conf 與 mongodb.conf）
CONF_FILE=""
SERVICE_NAME=""

if [ -f /etc/mongod.conf ]; then
    CONF_FILE="/etc/mongod.conf"
    SERVICE_NAME="mongod"
elif [ -f /etc/mongodb.conf ]; then
    CONF_FILE="/etc/mongodb.conf"
    SERVICE_NAME="mongodb"
else
    echo "未偵測到 MongoDB 設定檔，嘗試安裝套件..."
    apt-get update -y
    apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" mongodb || apt-get install -y mongodb-org || true
    
    if [ -f /etc/mongod.conf ]; then
        CONF_FILE="/etc/mongod.conf"
        SERVICE_NAME="mongod"
    elif [ -f /etc/mongodb.conf ]; then
        CONF_FILE="/etc/mongodb.conf"
        SERVICE_NAME="mongodb"
    else
        echo "錯誤: 無法找到或建立 MongoDB 設定檔" >&2
        exit 1
    fi
fi

# 解除僅限 127.0.0.1 限制，開放全網段監聽 (0.0.0.0) 供 K8s Worker 存取
sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' "$CONF_FILE" || true
sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/' "$CONF_FILE" || true

# 重新啟動服務並設定開機自啟
systemctl daemon-reload
systemctl restart "$SERVICE_NAME"
systemctl enable "$SERVICE_NAME"

# 簡易自檢驗證
if ss -tulpn | grep -q ":27017"; then
    echo "=== [$(date)] MongoDB 成功配置並監聽 Port 27017 ==="
else
    echo "=== [$(date)] 警告: MongoDB Port 27017 監聽異常 ===" >&2
    exit 1
fi
