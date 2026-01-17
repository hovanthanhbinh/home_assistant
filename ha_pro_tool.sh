#!/usr/bin/env bash
set -e

if [ ! -t 0 ]; then
  exec </dev/tty
fi


# ================== CONFIG ==================
HASS_DEB_URL="https://github.com/home-assistant/supervised-installer/releases/download/4.0.0/homeassistant-supervised.deb"
OS_AGENT_BASE="https://github.com/home-assistant/os-agent/releases/download/1.8.1"
ARCH="$(dpkg --print-architecture)"
IP_ADDR="$(hostname -I | awk '{print $1}')"

# ================== FUNCTIONS ==================
pause() {
  read -rp "👉 Nhấn Enter để tiếp tục..."
}

install_os_agent() {
  echo ">>> Cài OS-Agent..."
  case "$ARCH" in
    amd64) OS_DEB="os-agent_1.8.1_linux_x86_64.deb" ;;
    arm64) OS_DEB="os-agent_1.8.1_linux_aarch64.deb" ;;
    armhf) OS_DEB="os-agent_1.8.1_linux_armv7.deb" ;;
    *) echo "❌ Kiến trúc không hỗ trợ: $ARCH"; return ;;
  esac

  wget -qO /tmp/os-agent.deb "$OS_AGENT_BASE/$OS_DEB"
  dpkg -i /tmp/os-agent.deb || apt-get -f install -y
}

install_hass() {
  echo ">>> Cài Home Assistant Supervised"

  apt update
  apt install -y \
    apparmor \
    jq \
    wget \
    curl \
    udisks2 \
    libglib2.0-bin \
    network-manager \
    dbus \
    systemd-journal-remote \
    docker.io

  systemctl enable --now docker

  install_os_agent

  echo ">>> Cài Home Assistant Supervised (.deb)"
  wget -qO /tmp/homeassistant-supervised.deb "$HASS_DEB_URL"

  BYPASS_OS_CHECK=true dpkg -i /tmp/homeassistant-supervised.deb || \
  BYPASS_OS_CHECK=true apt-get -f install -y

  echo "✅ Cài Home Assistant hoàn tất"
}

uninstall_hass() {
  echo ">>> Gỡ Home Assistant"
  apt purge -y homeassistant-supervised
  rm -rf /usr/share/hassio /etc/hassio /var/lib/docker
  echo "✅ Đã gỡ Home Assistant"
}

install_hacs() {
  echo ">>> Cài HACS..."

  if [ ! -d "/usr/share/hassio/homeassistant" ]; then
    echo "❌ Home Assistant chưa chạy"
    return
  fi

  mkdir -p /usr/share/hassio/homeassistant/custom_components
  cd /usr/share/hassio/homeassistant/custom_components

  wget -qO hacs.zip https://github.com/hacs/integration/releases/latest/download/hacs.zip
  unzip -o hacs.zip -d hacs
  rm hacs.zip

  echo "✅ Cài HACS xong → restart Home Assistant"
}

status_check() {
  docker ps --format "table {{.Names}}\t{{.Status}}"
}

guide() {
  echo "===================================="
  echo "🌐 Truy cập Home Assistant:"
  echo "👉 http://$IP_ADDR:8123"
  echo "===================================="
}

# ================== MENU ==================
while true; do
  clear
  echo "====================================="
  echo "   HOME ASSISTANT PRO TOOL (FINAL)"
  echo "====================================="
  echo "📡 IP thiết bị: $IP_ADDR"
  echo "🌐 Home Assistant: http://$IP_ADDR:8123"
  echo "-------------------------------------"
  echo "1️⃣  Cài Home Assistant Supervised"
  echo "2️⃣  Gỡ Home Assistant"
  echo "3️⃣  Cài HACS"
  echo "4️⃣  Kiểm tra trạng thái"
  echo "5️⃣  Hướng dẫn truy cập Home Assistant"
  echo "6️⃣  Reboot thiết bị"
  echo "7️⃣  Tắt thiết bị"
  echo "0️⃣  Thoát"
  echo "-------------------------------------"

  read -rp "👉 Chọn: " choice

  case "$choice" in
    1) install_hass; pause ;;
    2) uninstall_hass; pause ;;
    3) install_hacs; pause ;;
    4) status_check; pause ;;
    5) guide; pause ;;
    6) reboot ;;
    7) poweroff ;;
    0) exit 0 ;;
    *) echo "❌ Lựa chọn không hợp lệ"; pause ;;
  esac
done
