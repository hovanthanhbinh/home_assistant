#!/usr/bin/env bash
set -e

# ================== CONFIG ==================
HASS_DEB_URL="https://github.com/home-assistant/supervised-installer/releases/latest/download/homeassistant-supervised.deb"
HACS_URL="https://get.hacs.xyz"
# ============================================

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Vui lòng chạy script bằng root (sudo)${NC}"
    exit 1
  fi
}

pause() {
  read -rp "⏎ Nhấn Enter để tiếp tục..."
}

# ================== OS-AGENT ==================
install_os_agent() {
  if dpkg -l | grep -q os-agent; then
    echo -e "${GREEN}✔ OS-Agent đã được cài${NC}"
    return
  fi

  echo ">>> Phát hiện OS-Agent version mới nhất..."

  OS_VER=$(curl -fsSL https://api.github.com/repos/home-assistant/os-agent/releases/latest \
    | jq -r .tag_name | sed 's/^v//')

  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)  OS_ARCH="linux_x86_64" ;;
    aarch64) OS_ARCH="linux_aarch64" ;;
    armv7l)  OS_ARCH="linux_armv7" ;;
    *)
      echo -e "${RED}❌ Không hỗ trợ CPU: $ARCH${NC}"
      exit 1
      ;;
  esac

  OS_DEB="os-agent_${OS_VER}_${OS_ARCH}.deb"

  echo ">>> Tải OS-Agent: $OS_DEB"
  wget -q --show-progress \
    https://github.com/home-assistant/os-agent/releases/download/${OS_VER}/${OS_DEB}

  dpkg -i ${OS_DEB} || apt -f install -y
}

# ================== INSTALL ==================
install_ha() {
  echo "=== CÀI HOME ASSISTANT SUPERVISED ==="

  apt update
  apt install -y \
    curl wget jq dbus \
    network-manager avahi-daemon \
    ca-certificates gnupg lsb-release

  systemctl enable NetworkManager
  systemctl start NetworkManager

  if ! command -v docker >/dev/null; then
    echo ">>> Cài Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
  fi

  install_os_agent

  echo ">>> Cài Home Assistant Supervised..."
  HASS_DEB="homeassistant-supervised.deb"

  wget -q --show-progress -O "$HASS_DEB" \
    https://github.com/home-assistant/supervised-installer/releases/latest/download/homeassistant-supervised.deb

  BYPASS_OS_CHECK=true dpkg -i "$HASS_DEB" || \
  BYPASS_OS_CHECK=true apt-get install -f -y

  echo "✔ Hoàn tất cài Home Assistant"
}

# ================== UNINSTALL ==================
uninstall_ha() {
  echo -e "${RED}=== GỠ HOME ASSISTANT SUPERVISED ===${NC}"

  systemctl stop hassio-supervisor.service 2>/dev/null || true

  apt purge -y homeassistant-supervised os-agent || true
  rm -rf /usr/share/hassio /etc/hassio /var/lib/hassio
  rm -f /etc/systemd/system/hassio-supervisor.service

  echo ">>> Xóa container Home Assistant..."
  docker ps -aq | xargs -r docker rm -f
  docker image prune -af

  echo -e "${GREEN}✔ Đã gỡ hoàn toàn Home Assistant${NC}"
}

# ================== HACS ==================
install_hacs() {
  echo ">>> Cài HACS..."
  if [ ! -d "/config" ]; then
    echo -e "${RED}❌ Không tìm thấy /config (Home Assistant chưa chạy?)${NC}"
    return
  fi

  curl -fsSL "$HACS_URL" | bash -
  echo -e "${GREEN}✔ Cài HACS xong – restart Home Assistant${NC}"
}

# ================== STATUS ==================
status_ha() {
  echo "===== TRẠNG THÁI ====="
  docker ps
  systemctl status hassio-supervisor --no-pager || true
}

# ================== MENU ==================
show_menu() {
  clear
  echo "====================================="
  echo "   HOME ASSISTANT PRO TOOL"
  echo "====================================="
  echo "1️  Cài Home Assistant Supervised"
  echo "2️  Gỡ Home Assistant"
  echo "3️  Cài HACS"
  echo "4️  Kiểm tra trạng thái"
  echo "0️  Thoát"
  echo "-------------------------------------"
  read -rp "👉 Chọn: " choice

  case "$choice" in
    1) install_ha ;;
    2) uninstall_ha ;;
    3) install_hacs ;;
    4) status_ha ;;
    0) exit 0 ;;
    *) echo "❌ Lựa chọn không hợp lệ" ;;
  esac

  pause
}

# ================== MAIN ==================
require_root
while true; do
  show_menu
done
