#!/bin/bash
set -e

echo "=== BẮT ĐẦU GỠ BỎ HOME ASSISTANT SUPERVISED TRÊN HỆ THỐNG ==="

# 1. Dừng dịch vụ Supervisor (nếu có)
echo ">>> Dừng dịch vụ hassio-supervisor..."
systemctl stop hassio-supervisor.service || true
systemctl disable hassio-supervisor.service || true

# 2. Xóa gói Supervisor + OS-Agent
echo ">>> Gỡ Supervisor và OS-Agent..."
apt-get remove --purge -y homeassistant-supervised os-agent || true

# 3. Xóa cấu hình còn sót
echo ">>> Xóa file cấu hình hassio.json..."
rm -f /etc/hassio.json

echo ">>> Xóa thư mục dữ liệu Home Assistant..."
rm -rf /usr/share/hassio
rm -rf /var/lib/docker/volumes/hassio*

# 4. Gỡ Docker containers/images của Home Assistant
echo ">>> Xóa container và image Home Assistant..."
docker ps -a | grep hassio | awk '{print $1}' | xargs -r docker rm -f
docker images | grep hassio | awk '{print $3}' | xargs -r docker rmi -f

# 5. Gỡ Docker hoàn toàn (tùy chọn)
read -p "Bạn có muốn gỡ luôn Docker? (y/n): " REMOVE_DOCKER
if [[ "$REMOVE_DOCKER" == "y" || "$REMOVE_DOCKER" == "Y" ]]; then
    echo ">>> Gỡ Docker CE..."
    apt-get remove --purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    apt-get autoremove -y
    rm -rf /var/lib/docker
fi

# 6. Hoàn tất
echo "=== HOÀN TẤT GỠ BỎ HOME ASSISTANT ==="
