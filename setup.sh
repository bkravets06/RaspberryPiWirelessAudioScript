#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the current user (works even if not 'pi')
CURRENT_USER=${SUDO_USER:-$USER}

echo -e "${GREEN}"
echo "============================================"
echo "   Raspberry Pi Audio Receiver Setup"
echo "   AirPlay 2 + Bluetooth + DLNA"
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
echo -e "Running as user: ${YELLOW}$CURRENT_USER${NC}"
echo -e "${YELLOW}Note: Building shairport-sync from source for AirPlay 2 - this may take 10-15 minutes on a Pi.${NC}"
echo ""

# Update system
echo -e "${YELLOW}[1/9] Updating system packages...${NC}"
sudo apt update && sudo apt upgrade -y

# Install dependencies
echo -e "${YELLOW}[2/9] Installing dependencies...${NC}"
sudo apt install -y \
    alsa-utils \
    pulseaudio \
    pulseaudio-module-bluetooth \
    bluez \
    bluez-tools \
    gmediarender \
    avahi-daemon \
    build-essential \
    git \
    autoconf \
    automake \
    libtool \
    libpopt-dev \
    libconfig-dev \
    libasound2-dev \
    libavahi-client-dev \
    libssl-dev \
    libsoxr-dev \
    libplist-dev \
    libsodium-dev \
    libavutil-dev \
    libavcodec-dev \
    libavformat-dev \
    uuid-dev \
    libgcrypt-dev \
    xxd

# Configure PulseAudio for headless operation (Lite compatibility)
echo -e "${YELLOW}[3/9] Configuring PulseAudio for headless operation...${NC}"

# Create PulseAudio config directory for the user
mkdir -p /home/$CURRENT_USER/.config/pulse

# Enable PulseAudio system-wide autospawn for headless
sudo tee /etc/pulse/client.conf.d/00-autospawn.conf > /dev/null <<EOF
autospawn = yes
EOF

# Create a systemd user service for PulseAudio
mkdir -p /home/$CURRENT_USER/.config/systemd/user
tee /home/$CURRENT_USER/.config/systemd/user/pulseaudio.service > /dev/null <<EOF
[Unit]
Description=PulseAudio Sound Server
After=sound.target

[Service]
Type=simple
ExecStart=/usr/bin/pulseaudio --daemonize=no --log-target=journal
Restart=on-failure

[Install]
WantedBy=default.target
EOF

chown -R $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/.config

# Enable lingering for the user (allows user services to run at boot without login)
sudo loginctl enable-linger $CURRENT_USER

# Configure Bluetooth
echo -e "${YELLOW}[4/9] Configuring Bluetooth...${NC}"

# Set Bluetooth device name
sudo sed -i "s/#Name = .*/Name = $DEVICE_NAME/" /etc/bluetooth/main.conf
if ! grep -q "^Name = " /etc/bluetooth/main.conf; then
    sudo sed -i "/\[General\]/a Name = $DEVICE_NAME" /etc/bluetooth/main.conf
fi

# Make Bluetooth discoverable and pairable permanently
sudo sed -i "s/#DiscoverableTimeout = .*/DiscoverableTimeout = 0/" /etc/bluetooth/main.conf
sudo sed -i "s/#PairableTimeout = .*/PairableTimeout = 0/" /etc/bluetooth/main.conf
sudo sed -i "s/DiscoverableTimeout = .*/DiscoverableTimeout = 0/" /etc/bluetooth/main.conf
sudo sed -i "s/PairableTimeout = .*/PairableTimeout = 0/" /etc/bluetooth/main.conf

# Build and install NQPTP (required for AirPlay 2 clock synchronization)
echo -e "${YELLOW}[5/9] Building NQPTP (AirPlay 2 timing daemon)...${NC}"

BUILD_DIR=$(mktemp -d)
cd "$BUILD_DIR"

git clone https://github.com/mikebrady/nqptp.git
cd nqptp
autoreconf -fi
./configure --with-systemd-startup
make
sudo make install

cd "$BUILD_DIR"

# Build and install shairport-sync with AirPlay 2 support
echo -e "${YELLOW}[6/9] Building shairport-sync with AirPlay 2 support (this takes a few minutes)...${NC}"

git clone https://github.com/mikebrady/shairport-sync.git
cd shairport-sync
autoreconf -fi
./configure --sysconfdir=/etc \
    --with-alsa \
    --with-soxr \
    --with-avahi \
    --with-ssl=openssl \
    --with-systemd-startup \
    --with-airplay-2
make
sudo make install

# Clean up build directory
cd /
rm -rf "$BUILD_DIR"

# Configure shairport-sync (AirPlay 2)
echo -e "${YELLOW}[7/9] Configuring shairport-sync (AirPlay 2)...${NC}"

sudo tee /etc/shairport-sync.conf > /dev/null <<EOF
general = {
    name = "$DEVICE_NAME";
    ignore_volume_control = "no";
    volume_range_db = 60;
    default_airplay_volume = -24.0;
};

alsa = {
    output_device = "default";
    mixer_control_name = "PCM";
};
EOF

# Configure gmediarender (DLNA/UPnP)
echo -e "${YELLOW}[8/9] Configuring gmediarender (DLNA)...${NC}"

# Generate a persistent UUID for this device
UUID=$(cat /proc/sys/kernel/random/uuid)

sudo tee /etc/systemd/system/gmediarender.service > /dev/null <<EOF
[Unit]
Description=gmediarender DLNA renderer
After=network-online.target sound.target pulseaudio.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/gmediarender -f "$DEVICE_NAME" -u $UUID
Restart=on-failure
User=$CURRENT_USER
Environment=PULSE_SERVER=unix:/run/user/$(id -u $CURRENT_USER)/pulse/native

[Install]
WantedBy=multi-user.target
EOF

# Create Bluetooth auto-accept pairing agent service
echo -e "${YELLOW}[9/9] Setting up Bluetooth pairing agent...${NC}"

sudo tee /etc/systemd/system/bt-agent.service > /dev/null <<EOF
[Unit]
Description=Bluetooth Agent
After=bluetooth.service
Requires=bluetooth.service

[Service]
Type=simple
ExecStartPre=/bin/sleep 2
ExecStart=/usr/bin/bt-agent -c NoInputNoOutput
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

# Create a service to make Bluetooth discoverable on boot
sudo tee /etc/systemd/system/bt-discoverable.service > /dev/null <<EOF
[Unit]
Description=Make Bluetooth Discoverable
After=bluetooth.service bt-agent.service
Requires=bluetooth.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 3
ExecStart=/usr/bin/bluetoothctl discoverable on
ExecStartPost=/usr/bin/bluetoothctl pairable on
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
echo -e "${YELLOW}Enabling services...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable nqptp
sudo systemctl enable bluetooth
sudo systemctl enable shairport-sync
sudo systemctl enable gmediarender
sudo systemctl enable bt-agent
sudo systemctl enable bt-discoverable
sudo systemctl enable avahi-daemon

# Add user to required groups
sudo usermod -a -G bluetooth $CURRENT_USER
sudo usermod -a -G audio $CURRENT_USER

# Enable user's PulseAudio service
sudo -u $CURRENT_USER XDG_RUNTIME_DIR=/run/user/$(id -u $CURRENT_USER) systemctl --user enable pulseaudio.service || true

# Start services
sudo systemctl start nqptp
sudo systemctl start bluetooth
sudo systemctl start avahi-daemon
sudo systemctl start shairport-sync

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   Setup Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "Your device '${YELLOW}$DEVICE_NAME${NC}' is now available via:"
echo -e "  ${GREEN}AirPlay 2${NC}  - Apple devices (supports multi-room)"
echo -e "  ${GREEN}Bluetooth${NC}  - Any Bluetooth device"
echo -e "  ${GREEN}DLNA/UPnP${NC} - Android (BubbleUPnP) & Windows"
echo ""
echo -e "${GREEN}Multi-room setup:${NC}"
echo -e "  Run this script on each Pi with a unique name."
echo -e "  ${GREEN}Apple:${NC}   Open Control Center > long-press audio > select multiple speakers"
echo -e "  ${GREEN}Android:${NC} Use BubbleUPnP app to cast to any speaker"
echo ""
echo -e "${GREEN}Volume control:${NC}"
echo -e "  Volume can be adjusted from your phone for all protocols."
echo ""
echo -e "${RED}IMPORTANT: You must reboot for all changes to take effect!${NC}"
echo -e "${YELLOW}Run: sudo reboot${NC}"
echo ""
