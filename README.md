# Raspberry Pi Wireless Audio Receiver

A one-line setup script to turn any Raspberry Pi into a wireless audio receiver supporting **AirPlay**, **Bluetooth**, and **DLNA/UPnP**.

## Supported Protocols

| Protocol | Works With | How to Connect |
|----------|-----------|----------------|
| **AirPlay** | iPhone, iPad, Mac | AirPlay menu → Select your device |
| **Bluetooth** | Android, Windows, any phone | Bluetooth settings → Pair |
| **DLNA/UPnP** | Windows, Android | "Cast to Device" / Apps like BubbleUPnP |

## Quick Install

On a fresh Raspberry Pi (with Raspberry Pi OS), run:

```bash
curl -sSL https://raw.githubusercontent.com/bkravets06/RaspberryPiWirelessAudioScript/main/setup.sh | bash
```

The script will:
1. Ask you to name your audio receiver (this name appears in AirPlay/Bluetooth menus)
2. Install and configure all necessary packages
3. Set up services to start automatically on boot

After installation, **reboot your Pi**:
```bash
sudo reboot
```

## Requirements

- Raspberry Pi (any model with WiFi/Bluetooth, or with USB adapters)
- Raspberry Pi OS - **both Desktop and Lite versions are supported**
- Speaker connected via 3.5mm jack, HDMI, or USB audio
- Network connection (WiFi or Ethernet)

> **Note:** The script auto-detects your username, so it works whether you use the default `pi` user or a custom username created during imaging.

## What Gets Installed

- **shairport-sync** - AirPlay receiver
- **gmediarender** - DLNA/UPnP renderer
- **PulseAudio + Bluetooth modules** - Bluetooth A2DP audio
- **bluez & bluez-tools** - Bluetooth stack and utilities
- **avahi-daemon** - Network discovery (mDNS)

## Troubleshooting

### No audio output
```bash
# Check if services are running
sudo systemctl status shairport-sync
sudo systemctl status gmediarender
sudo systemctl status bluetooth

# Test audio output
speaker-test -t wav -c 2
```

### Bluetooth not discoverable
```bash
sudo bluetoothctl
> discoverable on
> pairable on
```

### Change device name after setup
Edit the name in these locations:
- `/etc/shairport-sync.conf`
- `/etc/bluetooth/main.conf`
- `/etc/systemd/system/gmediarender.service`

Then restart services:
```bash
sudo systemctl restart shairport-sync gmediarender bluetooth
```

## License

MIT License - Feel free to use and modify!
