#!/usr/bin/env bash
set -e

# ================= CONFIG =================
HASS_DEB_URL="https://github.com/home-assistant/supervised-installer/releases/latest/download/homeassistant-supervised.deb"
HACS_URL="https://get.hacs.xyz"
# =========================================

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"

# ================= UTILS ==================
require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Vui lòng chạy bằng root (sudo)${NC}"
    exit 1
  fi
}

pause() {
  read -rp "⏎ Nhấn Enter để tiếp tục..."
}

get_local_ip() {
  ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}'
}

# ================= TIME FIX =================
sync_time() {
  echo ">>> Đồng bộ thời gian hệ thống..."

  apt install -y systemd-timesyncd >/dev/null 2>&1 || true
  timedatectl set-ntp true || true
  sleep 3

  if ! timedatectl status | grep -q "System clock synchronized: yes"; then
    echo "⚠ NTP chưa sync – ép lấy thời gian từ internet"
    date -s "$(curl -sI https://google.com | grep -i '^date:' | cut -d' ' -f2-)" || true
  fi

  echo ">>> Làm sạch apt cache cũ"
  apt clean
  rm -rf /var/lib/apt/lists/*
}

# ================= OS-AGENT =================
install_os_agent() {
  if dpkg -l | grep -q os-agent; then
    echo "✔ OS-Agent đã được cài"
    return
  fi

  echo ">>> Phát hiện OS-Agent mới nhất..."

  OS_VER=$(curl -fsSL https://api.github.com/repos/home-assistant/os-agent/releases/latest \
    | jq -r .tag_name | sed 's/^v//')

  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)  OS_ARCH="linux_x86_64" ;;
    aarch64) OS_ARCH="linux_aarch64" ;;
    armv7l)  OS_ARCH="linux_armv7" ;;
    *)
      echo -e "${RED}❌ CPU không hỗ trợ: $ARCH${NC}"
      exit 1
      ;;
  esac

  OS_DEB="os-agent_${OS_VER}_${OS_ARCH}.deb"

  wget -q --show-progress \
    https://github.com/home-assistant/os-agent/releases/download/${OS_VER}/${OS_DEB}

  dpkg -i "$OS_DEB" || apt -f install -y
}

# ================= INSTALL HASS =================
install_ha() {
  echo -e "${YELLOW}=== CÀI HOME ASSISTANT SUPERVISED ===${NC}"

  sync_time

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

  wget -q --show-progress -O "$HASS_DEB" "$HASS_DEB_URL"

  BYPASS_OS_CHECK=true dpkg -i "$HASS_DEB" || \
  BYPASS_OS_CHECK=true apt-get install -f -y

  echo -e "${GREEN}✔ Cài Home Assistant hoàn tất${NC}"
}

# ================= UNINSTALL =================
uninstall_ha() {
  echo -e "${RED}=== GỠ HOME ASSISTANT ===${NC}"

  systemctl stop hassio-supervisor.service 2>/dev/null || true

  apt purge -y homeassistant-supervised os-agent || true
  rm -rf /usr/share/hassio /etc/hassio /var/lib/hassio

  echo ">>> Xóa container Docker..."
  docker ps -aq | xargs -r docker rm -f
  docker image prune -af

  echo -e "${GREEN}✔ Đã gỡ Home Assistant${NC}"
}

# ================= HACS =================
install_hacs() {
  echo ">>> Cài HACS..."

  HASS_CONFIG="/usr/share/hassio/homeassistant"

  if [ ! -d "$HASS_CONFIG" ]; then
    echo -e "${RED}❌ Không tìm thấy $HASS_CONFIG${NC}"
    echo "👉 Home Assistant cần chạy ít nhất 1 lần"
    return
  fi

  cd "$HASS_CONFIG"

  if [ -d "custom_components/hacs" ]; then
    echo "✔ HACS đã tồn tại"
    return
  fi

  mkdir -p custom_components
  curl -fsSL "$HACS_URL" | bash -

  echo -e "${GREEN}✔ Cài HACS thành công${NC}"
}

# ================= STATUS =================
status_ha() {
  echo "===== TRẠNG THÁI ====="
  docker ps
  systemctl status hassio-supervisor --no-pager || true
}

# ================= OPEN / POWER =================
open_hass() {
  IP=$(get_local_ip)
  echo "🌐 Truy cập Home Assistant:"
  echo "👉 http://${IP}:8123"
}

do_reboot() {
  read -rp "⚠ Reboot thiết bị? (y/N): " c
  [[ "$c" =~ ^[Yy]$ ]] && reboot
}

do_poweroff() {
  read -rp "⚠ Tắt thiết bị? (y/N): " c
  [[ "$c" =~ ^[Yy]$ ]] && poweroff
}

# ================= MENU =================
show_menu() {
  clear
  IP=$(get_local_ip)

  echo "====================================="
  echo "   HOME ASSISTANT PRO TOOL (FINAL)"
  echo "====================================="
  echo "📡 IP thiết bị: ${IP:-N/A}"
  echo "🌐 Home Assistant: http://${IP:-IP}:8123"
  echo "-------------------------------------"
  echo "1️  Cài Home Assistant Supervised"
  echo "2️  Gỡ Home Assistant"
  echo "3️  Cài HACS"
  echo "4️  Kiểm tra trạng thái"
  echo "5️  Hướng dẫn truy cập Home Assistant"
  echo "6️  Reboot thiết bị"
  echo "7️  Tắt thiết bị"
  echo "0️  Thoát"
  echo "-------------------------------------"
  read -rp "👉 Chọn: " choice

  case "$choice" in
    1) install_ha ;;
    2) uninstall_ha ;;
    3) install_hacs ;;
    4) status_ha ;;
    5) open_hass ;;
    6) do_reboot ;;
    7) do_poweroff ;;
    0) exit 0 ;;
    *) echo "❌ Lựa chọn không hợp lệ" ;;
  esac

  pause
}

# ================= MAIN =================
require_root
while true; do
  show_menu
done
