# Raspberry Pi Wireless Audio Receiver

A one-line setup script to turn any Raspberry Pi into a wireless audio receiver supporting **AirPlay 2**, **Bluetooth**, and **DLNA/UPnP** with **multi-room** and **remote volume control**.

## Supported Protocols

| Protocol | Works With | Multi-Room | Volume Control | How to Connect |
|----------|-----------|------------|----------------|----------------|
| **AirPlay 2** | iPhone, iPad, Mac | Native grouping | From device | Control Center > AirPlay |
| **Bluetooth** | Android, Windows, any phone | No | From device (AVRCP) | Bluetooth settings > Pair |
| **DLNA/UPnP** | Android, Windows | Via app (BubbleUPnP) | From app | BubbleUPnP / "Cast to Device" |

## Quick Install

On a fresh Raspberry Pi (with Raspberry Pi OS), run:

```bash
curl -sSL https://raw.githubusercontent.com/bkravets06/RaspberryPiWirelessAudioScript/main/setup.sh | bash
```

The script will:
1. Ask you to name your audio receiver (this name appears in AirPlay/Bluetooth/DLNA menus)
2. Install dependencies and build shairport-sync from source with AirPlay 2 support
3. Set up all services to start automatically on boot

After installation, **reboot your Pi**:
```bash
sudo reboot
```

> **Note:** Building from source takes about 10-15 minutes on a Raspberry Pi 4. Be patient during steps 5 and 6.

## Multi-Room Setup

Run the script on each Raspberry Pi, giving each one a unique name (e.g., "Kitchen", "Bedroom", "Living Room").

### Apple Devices (AirPlay 2)
1. Open **Control Center** on your iPhone/iPad
2. Long-press the **audio card** (top-right area)
3. Tap the **AirPlay icon**
4. Select **multiple speakers** - each Pi appears by name
5. Adjust **per-speaker volume** with individual sliders

### Android Devices
1. Install [**BubbleUPnP**](https://play.google.com/store/apps/details?id=com.bubblesoft.android.bubbleupnp) from the Play Store
2. Select a Pi as the **renderer** (output device)
3. Play audio from any source on your phone
4. Use the **volume slider** in the app to control speaker volume

### Any Device (Bluetooth)
1. Open Bluetooth settings on your phone
2. Pair with the Pi by name
3. Audio plays through the connected Pi
4. Volume is controlled from your phone

## Volume Control

Volume works from your casting device across all protocols:

- **AirPlay 2**: Hardware volume buttons and Control Center sliders control speaker volume directly. In multi-room mode, per-speaker volume sliders appear.
- **Bluetooth**: Standard AVRCP remote volume - your phone's volume buttons control the speaker.
- **DLNA**: Volume is controlled through the casting app (e.g., BubbleUPnP volume slider).

## Requirements

- Raspberry Pi 2, Pi Zero 2 W, or newer (AirPlay 2 needs more CPU than AirPlay 1)
- Raspberry Pi OS - **both Desktop and Lite versions are supported**
- Speaker connected via 3.5mm jack, HDMI, or USB audio
- Network connection (WiFi or Ethernet)

> **Note:** The script auto-detects your username, so it works whether you use the default `pi` user or a custom username created during imaging.

## What Gets Installed

- **shairport-sync** (built from source) - AirPlay 2 receiver with multi-room support
- **NQPTP** - PTP timing daemon for AirPlay 2 audio synchronization
- **gmediarender** - DLNA/UPnP renderer
- **PulseAudio + Bluetooth modules** - Bluetooth A2DP audio
- **bluez & bluez-tools** - Bluetooth stack and utilities
- **avahi-daemon** - Network discovery (mDNS)

## Troubleshooting

### No audio output
```bash
# Check if services are running
sudo systemctl status nqptp
sudo systemctl status shairport-sync
sudo systemctl status gmediarender
sudo systemctl status bluetooth

# Test audio output
speaker-test -t wav -c 2
```

### AirPlay device not showing up
```bash
# Make sure NQPTP is running (required for AirPlay 2)
sudo systemctl status nqptp

# Restart both services
sudo systemctl restart nqptp
sudo systemctl restart shairport-sync

# Check shairport-sync logs
journalctl -u shairport-sync -f
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
