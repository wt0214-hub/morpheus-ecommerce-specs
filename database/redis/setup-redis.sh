#!/bin/bash
set -e

# 避免 apt-get 安裝或更新時彈出互動式對話框卡死自動化流程
export DEBIAN_FRONTEND=noninteractive

echo "=== [$(date)] 開始自動安裝與配置 Redis ==="

# 更新套件清單並安裝 Redis Server
apt-get update -y
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" redis-server

# 設定全網段監聽 (0.0.0.0) 並關閉保護模式 (防重複附加)
grep -q "^bind 0.0.0.0" /etc/redis/redis.conf || echo "bind 0.0.0.0" >> /etc/redis/redis.conf
grep -q "^protected-mode no" /etc/redis/redis.conf || echo "protected-mode no" >> /etc/redis/redis.conf

# 重新啟動服務並設定開機自啟
systemctl daemon-reload
systemctl restart redis-server
systemctl enable redis-server

# 簡易自檢驗證
if ss -tulpn | grep -q "0.0.0.0:6379"; then
    echo "=== [$(date)] Redis 成功安裝並監聽 0.0.0.0:6379 ==="
else
    echo "=== [$(date)] 警告: Redis 監聽異常，請確認設定 ===" >&2
    exit 1
fi
