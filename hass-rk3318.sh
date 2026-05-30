#!/bin/bash

set -e

echo "================================================="
echo " Home Assistant Supervised Installer for RK3318 "
echo " Debian 12 / Armbian 26.x"
echo "================================================="

if [ "$(id -u)" != "0" ]; then
echo "Vui lòng chạy bằng root"
exit 1
fi

#=================================================

# Hàm tải file có retry

#=================================================
safe_download() {
local URL="$1"
local FILE="$2"
local TRY=0
local MAX=5

```
while [ $TRY -lt $MAX ]; do
    echo ">>> Download $FILE ($((TRY+1))/$MAX)"

    if wget --progress=bar:force:noscroll -O "$FILE" "$URL"; then
        return 0
    fi

    TRY=$((TRY+1))
    echo ">>> Download lỗi, thử lại sau 3 giây..."
    sleep 3
done

echo ">>> Không thể tải $FILE"
exit 1
```

}

#=================================================

# Kiểm tra kiến trúc

#=================================================
ARCH=$(uname -m)

if [ "$ARCH" != "aarch64" ]; then
echo ">>> Thiết bị không phải ARM64"
echo ">>> Kiến trúc hiện tại: $ARCH"
exit 1
fi

echo ">>> Architecture: $ARCH"

#=================================================

# Kiểm tra Internet

#=================================================
echo ">>> Kiểm tra kết nối Internet..."

if ! ping -c 1 github.com >/dev/null 2>&1; then

```
echo ">>> Sửa DNS..."

cat >/etc/resolv.conf <<EOF
```

nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

```
sleep 2

if ! ping -c 1 github.com >/dev/null 2>&1; then
    echo ">>> Không có Internet"
    exit 1
fi
```

fi

echo ">>> Internet OK"

#=================================================

# Update hệ thống

#=================================================
echo ">>> Update hệ thống"

apt-get update
apt-get upgrade -y
apt-get autoremove -y

#=================================================

# Cài dependency

#=================================================
echo ">>> Cài dependency"

apt-get install -y 
apparmor 
apparmor-utils 
jq 
wget 
curl 
udisks2 
libglib2.0-bin 
network-manager 
dbus 
lsb-release 
systemd-timesyncd 
systemd-resolved 
avahi-daemon 
software-properties-common 
socat 
bluez 
cifs-utils 
ca-certificates 
apt-transport-https 
gnupg

#=================================================

# Enable service bắt buộc

#=================================================
echo ">>> Enable NetworkManager"

systemctl enable NetworkManager
systemctl restart NetworkManager

echo ">>> Enable AppArmor"

systemctl enable apparmor || true
systemctl restart apparmor || true

#=================================================

# Docker

#=================================================
if ! command -v docker >/dev/null 2>&1; then

```
echo ">>> Cài Docker"

curl -fsSL https://get.docker.com | sh
```

else

```
echo ">>> Docker đã tồn tại"
```

fi

systemctl enable docker
systemctl restart docker

docker --version

#=================================================

# Cài OS-Agent

#=================================================
echo ">>> Cài OS-Agent"

OS_VER="1.8.1"
OS_FILE="os-agent_${OS_VER}_linux_aarch64.deb"
OS_URL="https://github.com/home-assistant/os-agent/releases/download/${OS_VER}/${OS_FILE}"

safe_download "$OS_URL" "$OS_FILE"

if ! dpkg -i "$OS_FILE"; then

```
apt-get install --fix-broken -y
dpkg -i "$OS_FILE"
```

fi

rm -f "$OS_FILE"

#=================================================

# Kiểm tra OS-Agent

#=================================================
sleep 3

if systemctl is-active os-agent >/dev/null 2>&1; then
echo ">>> OS-Agent OK"
else
echo ">>> Cảnh báo: OS-Agent chưa active"
fi

#=================================================

# Cài Home Assistant Supervised

#=================================================
echo ">>> Cài Home Assistant Supervised"

HASS_FILE="homeassistant-supervised.deb"
HASS_URL="https://github.com/home-assistant/supervised-installer/releases/latest/download/${HASS_FILE}"

safe_download "$HASS_URL" "$HASS_FILE"

if ! dpkg -i "$HASS_FILE"; then

```
echo ">>> Thử cài bằng apt"

BYPASS_OS_CHECK=true apt install -y ./"$HASS_FILE"
```

fi

rm -f "$HASS_FILE"

#=================================================

# Restart Supervisor

#=================================================
systemctl restart hassio-supervisor.service || true

#=================================================

# Hiển thị thông tin

#=================================================
IP=$(hostname -I | awk '{print $1}')

echo ""
echo "================================================="
echo " CÀI ĐẶT HOÀN TẤT "
echo "================================================="
echo ""
echo "Home Assistant đang khởi tạo."
echo "Lần đầu có thể mất 5-20 phút."
echo ""
echo "Truy cập:"
echo ""
echo "http://${IP}:8123"
echo ""
echo "Kiểm tra trạng thái:"
echo "systemctl status hassio-supervisor"
echo ""
echo "Khởi động lại box nếu cần:"
echo "reboot"
echo ""
echo "================================================="
