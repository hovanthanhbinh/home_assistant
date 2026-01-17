#!/bin/bash
set -e

# --- MÀU SẮC ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ">>> Syncing system time..."
timedatectl set-ntp true || true

echo -e "${GREEN}=== INSTALLING HOME ASSISTANT SUPERVISED (AUTO-DETECT) ===${NC}"

# --- 1. AUTO DETECT ARCH ---
ARCH=$(uname -m)
echo -n "🔍 Detecting Architecture: "

case $ARCH in
    aarch64|arm64)
        echo -e "${GREEN}ARM64 ($ARCH)${NC}"
        OS_AGENT_ARCH="aarch64"
        HA_MACHINE_TYPE="qemuarm-64"
        ;;
    x86_64)
        echo -e "${GREEN}AMD64 ($ARCH)${NC}"
        OS_AGENT_ARCH="amd64"
        HA_MACHINE_TYPE="generic-x86-64"
        ;;
    *)
        echo -e "${RED}UNSUPPORTED ($ARCH)${NC}"
        exit 1
        ;;
esac

echo -e "💡 Target Machine Type: ${YELLOW}$HA_MACHINE_TYPE${NC}"

# --- 2. UPDATE ---
echo -e "${GREEN}>>> [1/6] Updating System Dependencies...${NC}"
apt-get update && apt-get upgrade -y && apt autoremove -y

apt-get install -y jq curl wget

apt-get install -y \
    apparmor \
    udisks2 \
    libglib2.0-bin \
    network-manager \
    dbus \
    lsb-release \
    systemd-journal-remote \
    systemd-resolved \
    systemd-timesyncd \
    bluez cifs-utils

# --- 3. INSTALL DOCKER ---
echo -e "${GREEN}>>> [2/6] Checking Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
else
    echo "Docker is already installed."
fi

usermod -aG docker root

# --- 4. NETWORK MANAGER ---
echo -e "${GREEN}>>> [3/6] Configuring NetworkManager...${NC}"
touch /etc/NetworkManager/conf.d/100-disable-wifi-mac-randomization.conf
nmcli connection show > /dev/null 2>&1 || true

# --- 5. INSTALL OS-AGENT ---
echo -e "${GREEN}>>> [4/6] Installing OS-Agent (Latest)...${NC}"

LATEST_AGENT_VER=$(curl -sL https://api.github.com/repos/home-assistant/os-agent/releases/latest | jq -r ".tag_name")

if [ -z "$LATEST_AGENT_VER" ] || [ "$LATEST_AGENT_VER" == "null" ]; then
    echo -e "${RED}❌ Failed to fetch latest OS-Agent version.${NC}"
    exit 1
fi

AGENT_DEB="os-agent_${LATEST_AGENT_VER}_linux_${OS_AGENT_ARCH}.deb"
AGENT_URL="https://github.com/home-assistant/os-agent/releases/download/${LATEST_AGENT_VER}/${AGENT_DEB}"

echo "Downloading OS-Agent ${LATEST_AGENT_VER}..."
cd /tmp
rm -f "$AGENT_DEB"
wget -q "$AGENT_URL"

dpkg -i "$AGENT_DEB"
echo -e "${GREEN}✅ OS-Agent Installed.${NC}"

# --- 6. INSTALL SUPERVISED ---
echo -e "${GREEN}>>> [5/6] Installing Home Assistant Supervised...${NC}"

echo "machine=$HA_MACHINE_TYPE" > /etc/default/homeassistant-supervised

HASS_DEB="homeassistant-supervised.deb"
rm -f "$HASS_DEB"

# ⭐ LINK ĐÃ ĐƯỢC SỬA THEO YÊU CẦU ⭐
wget -q https://github.com/home-assistant/supervised-installer/releases/download/4.0.0/homeassistant-supervised.deb

echo "Installing package (Bypassing OS Check)..."
BYPASS_OS_CHECK=true dpkg -i "$HASS_DEB" || \
BYPASS_OS_CHECK=true apt-get install -f -y

# --- 7. FINISH ---
echo -e "${GREEN}>>> [6/6] Restarting Supervisor...${NC}"
systemctl restart hassio-supervisor.service

IP_ADDR=$(hostname -I | awk '{print $1}')
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}   INSTALLATION COMPLETE SUCCESSFULLY!       ${NC}"
echo -e "${GREEN}=============================================${NC}"
echo -e "Truy cập: http://$IP_ADDR:8123"
echo -e "Machine Type: ${YELLOW}$HA_MACHINE_TYPE${NC}"
echo -e "Note: Lần đầu khởi động mất 20p để load vào Hass"
