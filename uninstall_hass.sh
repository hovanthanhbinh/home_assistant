#!/bin/bash
set -e

# ===== FIX CRLF (nếu có) =====
sed -i 's/\r$//' "$0" 2>/dev/null || true

# ===== MÀU =====
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}=== BẮT ĐẦU GỠ BỎ HOME ASSISTANT SUPERVISED ===${NC}"

# ===== CHECK ROOT =====
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Vui lòng chạy script bằng root hoặc sudo${NC}"
  exit 1
fi

# ===== STOP SERVICES =====
echo -e "${YELLOW}>>> Dừng Supervisor & các service liên quan...${NC}"
systemctl stop hassio-supervisor.service 2>/dev/null || true
systemctl disable hassio-supervisor.service 2>/dev/null || true
systemctl stop haos-agent.service 2>/dev/null || true
systemctl disable haos-agent.service 2>/dev/null || true

# ===== REMOVE PACKAGES =====
echo -e "${YELLOW}>>> Gỡ homeassistant-supervised & os-agent...${NC}"
apt-get remove -y homeassistant-supervised os-agent 2>/dev/null || true
apt-get purge -y homeassistant-supervised os-agent 2>/dev/null || true

# ===== REMOVE CONFIG FILES =====
echo -e "${YELLOW}>>> Xóa file cấu hình...${NC}"
rm -f /etc/hassio.json
rm -f /etc/systemd/system/hassio-supervisor.service
rm -rf /etc/hassio

# ===== REMOVE DATA =====
echo -e "${YELLOW}>>> Xóa thư mục dữ liệu Home Assistant...${NC}"
rm -rf /usr/share/hassio
rm -rf /usr/share/hassio-addons
rm -rf /usr/share/hassio-backups
rm -rf /usr/share/hassio-media
rm -rf /usr/share/hassio-share
rm -rf /usr/share/hassio-ssl

# ===== DOCKER CLEANUP =====
if command -v docker >/dev/null 2>&1; then
  echo -e "${YELLOW}>>> Xóa container Home Assistant...${NC}"
  docker ps -aq | xargs -r docker rm -f

  echo -e "${YELLOW}>>> Xóa image Home Assistant (SAFE MODE)...${NC}"
  docker images --format "{{.Repository}} {{.ID}}" \
    | grep -E 'homeassistant|ghcr.io/home-assistant|hassio' \
    | awk '{print $2}' \
    | xargs -r docker rmi -f || true

  echo -e "${YELLOW}>>> Dọn Docker rác (prune)...${NC}"
  docker system prune -f
else
  echo -e "${YELLOW}>>> Docker không tồn tại – bỏ qua bước Docker${NC}"
fi

# ===== NETWORK CLEANUP (OPTIONAL) =====
echo -e "${YELLOW}>>> Reset cấu hình NetworkManager (nếu có)...${NC}"
if [ -d /etc/NetworkManager ]; then
  rm -f /etc/NetworkManager/system-connections/default*
  systemctl restart NetworkManager 2>/dev/null || true
fi

# ===== DONE =====
echo -e "${GREEN}=== GỠ HOME ASSISTANT SUPERVISED HOÀN TẤT ===${NC}"
echo -e "${GREEN}✔ Hệ thống đã sạch Home Assistant${NC}"
echo -e "${YELLOW}ℹ Khuyến nghị reboot lại thiết bị${NC}"
