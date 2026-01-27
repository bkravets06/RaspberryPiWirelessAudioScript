#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}"
echo "============================================"
echo "   Raspberry Pi Audio Receiver Setup"
echo "   AirPlay + Bluetooth + DLNA"
echo "============================================"
echo -e "${NC}"

# Ask for device name
read -p "Enter a name for this audio receiver (e.g., 'Kitchen Speaker'): " DEVICE_NAME

if [ -z "$DEVICE_NAME" ]; then
    DEVICE_NAME=$(hostname)
    echo -e "${YELLOW}No name entered, using hostname: $DEVICE_NAME${NC}"
fi

echo ""
echo -e "${GREEN}Setting up '$DEVICE_NAME' as an audio receiver...${NC}"
echo ""

# Update system
echo -e "${YELLOW}[1/6] Updating system packages...${NC}"
sudo apt update && sudo apt upgrade -y

# Install dependencies
echo -e "${YELLOW}[2/6] Installing dependencies...${NC}"
sudo apt install -y \
    pulseaudio \
    pulseaudio-module-bluetooth \
    bluez \
    bluez-tools \
    shairport-sync \
    gmediarender \
    avahi-daemon

# Configure Bluetooth
echo -e "${YELLOW}[3/6] Configuring Bluetooth...${NC}"

# Set Bluetooth device name
sudo sed -i "s/#Name = .*/Name = $DEVICE_NAME/" /etc/bluetooth/main.conf
if ! grep -q "^Name = " /etc/bluetooth/main.conf; then
    sudo sed -i "/\[General\]/a Name = $DEVICE_NAME" /etc/bluetooth/main.conf
fi

# Make Bluetooth discoverable and pairable
sudo sed -i "s/#DiscoverableTimeout = .*/DiscoverableTimeout = 0/" /etc/bluetooth/main.conf
sudo sed -i "s/#PairableTimeout = .*/PairableTimeout = 0/" /etc/bluetooth/main.conf

# Configure Shairport-Sync (AirPlay)
echo -e "${YELLOW}[4/6] Configuring Shairport-Sync (AirPlay)...${NC}"

sudo tee /etc/shairport-sync.conf > /dev/null <<EOF
general = {
    name = "$DEVICE_NAME";
    interpolation = "basic";
};

alsa = {
    output_device = "default";
    mixer_control_name = "PCM";
};
EOF

# Configure gmediarender (DLNA/UPnP)
echo -e "${YELLOW}[5/6] Configuring gmediarender (DLNA)...${NC}"

sudo tee /etc/systemd/system/gmediarender.service > /dev/null <<EOF
[Unit]
Description=gmediarender DLNA renderer
After=network-online.target sound.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/gmediarender -f "$DEVICE_NAME" -u $(cat /proc/sys/kernel/random/uuid)
Restart=on-failure
User=pi

[Install]
WantedBy=multi-user.target
EOF

# Create Bluetooth auto-accept pairing agent service
echo -e "${YELLOW}[6/6] Setting up Bluetooth pairing agent...${NC}"

sudo tee /etc/systemd/system/bt-agent.service > /dev/null <<EOF
[Unit]
Description=Bluetooth Agent
After=bluetooth.service
Requires=bluetooth.service

[Service]
Type=simple
ExecStart=/usr/bin/bt-agent -c NoInputNoOutput
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
echo -e "${YELLOW}Enabling services...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable bluetooth
sudo systemctl enable shairport-sync
sudo systemctl enable gmediarender
sudo systemctl enable bt-agent
sudo systemctl enable avahi-daemon

# Add pi user to required groups
sudo usermod -a -G bluetooth pi
sudo usermod -a -G audio pi

# Start services
sudo systemctl start bluetooth
sudo systemctl start shairport-sync
sudo systemctl start gmediarender
sudo systemctl start bt-agent

# Make Bluetooth discoverable
sudo bluetoothctl discoverable on
sudo bluetoothctl pairable on

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   Setup Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "Your device '${YELLOW}$DEVICE_NAME${NC}' is now available via:"
echo -e "  • ${GREEN}AirPlay${NC} - For Apple devices"
echo -e "  • ${GREEN}Bluetooth${NC} - For any Bluetooth device"
echo -e "  • ${GREEN}DLNA/UPnP${NC} - For Windows 'Cast to Device' & Android apps"
echo ""
echo -e "${YELLOW}Recommended: Reboot your Pi with 'sudo reboot'${NC}"
echo ""
