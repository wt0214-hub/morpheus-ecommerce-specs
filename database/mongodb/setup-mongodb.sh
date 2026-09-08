#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "=== [$(date)] 開始自動配置 MongoDB ==="

# 確保設定檔開放全網段 0.0.0.0
CONF_FILE="/etc/mongod.conf"
[ -f /etc/mongodb.conf ] && CONF_FILE="/etc/mongodb.conf"

if [ -f "$CONF_FILE" ]; then
    echo "更新設定檔: $CONF_FILE"
    sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' "$CONF_FILE" || true
    sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/' "$CONF_FILE" || true
fi

# 重啟服務
echo "重新啟動 mongod 服務..."
systemctl daemon-reload || true
systemctl restart mongod || systemctl restart mongodb || true
systemctl enable mongod || systemctl enable mongodb || true

# 緩衝檢查機制：最多重試 10 次 (每次 1 秒) 等待 Port 27017 就緒
echo "等待 MongoDB Port 27017 就緒..."
READY=0
for i in {1..10}; do
    if ss -tulpn | grep -q ":27017"; then
        READY=1
        break
    fi
    sleep 1
done

if [ $READY -eq 1 ]; then
    echo "=== [$(date)] MongoDB 成功啟動並監聽 0.0.0.0:27017 ==="
else
    echo "=== [$(date)] 警告: MongoDB Port 27017 監聽異常 ===" >&2
    exit 1
fi
