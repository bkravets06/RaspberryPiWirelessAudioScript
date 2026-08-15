# piaudio

Turn a Raspberry Pi into a wireless speaker that works from **iPhone and Android**, with one command and no app required on either platform.

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/bkravets06/RaspberryPiWirelessAudioScript/main/piaudio)"
```

That single file is the whole project. It installs the receivers, configures audio, and leaves behind a `piaudio` command for managing things afterwards.

---

## What you get

| | iPhone / iPad | Android | Needs an app? | Multi-room |
|---|---|---|---|---|
| **AirPlay 2** | Native | — | No | Yes, native grouping |
| **Bluetooth** | Native | Native | No | No |
| **Spotify Connect** *(opt-in)* | In Spotify | In Spotify | Spotify | Yes, via Spotify |
| **DLNA / UPnP** | — | Yes | Yes (BubbleUPnP, VLC) | Per-app |

**Android's best experience is Bluetooth** — pair once and every app on the phone plays through the Pi, with the volume buttons working normally. Spotify Connect is worth enabling if you use Spotify, since it streams over WiFi and doesn't tie up the phone's Bluetooth radio.

> **Why no Google Cast?** Google doesn't publish a Cast receiver you can run on your own hardware — it's licensed to manufacturers only. Any project claiming Cast support on a Pi is reverse-engineered and breaks regularly. Bluetooth and Spotify Connect are the reliable native paths on Android.

---

## Install

On a fresh Raspberry Pi OS install (Lite or Desktop, both work):

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/bkravets06/RaspberryPiWirelessAudioScript/main/piaudio)"
```

It asks for a name, picks your audio output, and installs everything. Prefer to read the script first? That's the safer habit:

```bash
curl -fsSL https://raw.githubusercontent.com/bkravets06/RaspberryPiWirelessAudioScript/main/piaudio -o piaudio
less piaudio
chmod +x piaudio && sudo ./piaudio
```

### Unattended

```bash
sudo ./piaudio -y --name "Kitchen" --no-upgrade
```

| Option | Default | |
|---|---|---|
| `-n, --name NAME` | hostname | Name your phone shows |
| `-o, --output DEVICE` | auto | ALSA device, e.g. `hw:CARD=Device,DEV=0` |
| `--airplay 2\|1\|off` | `2` | `1` skips the compile; `off` disables AirPlay |
| `--bluetooth on\|off` | `on` | |
| `--dlna on\|off` | `on` | |
| `--spotify on\|off` | `off` | Adds a third-party apt repo — see below |
| `--no-upgrade` | | Skip `apt upgrade`, much faster |
| `-y, --yes` | | Never prompt |

**AirPlay 2 has to be compiled** (10–20 minutes) because Debian doesn't ship it enabled. If you only need one speaker and don't want to wait, `--airplay 1` installs in seconds and still works fine from an iPhone — you lose multi-room grouping and per-speaker volume sync. The installer checks whether your distro already ships an AirPlay 2 build and skips the compile if so.

---

## Connecting

**iPhone / iPad** — Control Center → long-press the audio card → AirPlay icon → pick your speaker.

**Android** — Settings → Bluetooth → pair with your speaker's name. It shows up as a loudspeaker and stays discoverable, so you only do this once.

**Spotify (either platform)** — Now Playing → Devices → pick your speaker.

**Android via DLNA** — install [BubbleUPnP](https://play.google.com/store/apps/details?id=com.bubblesoft.android.bubbleupnp) or VLC, choose your Pi as the renderer.

---

## Managing it

```bash
piaudio status                  # what's running, and who's connected
piaudio test                    # play a test tone
piaudio logs                    # follow all logs
piaudio logs shairport-sync     # or just one service
sudo piaudio rename "Patio"     # change the name everywhere at once
sudo piaudio output             # switch audio output
sudo piaudio restart
sudo piaudio uninstall          # removes everything, restores your configs
```

`piaudio status` output:

```
  Kitchen (192.168.1.42)
  output: USB Audio Device @ 44100Hz

  ● AirPlay 2 timing       nqptp.service
  ● AirPlay                shairport-sync.service
  ● Bluetooth stack        bluetooth.service
  ● Bluetooth audio        bluealsa.service
  ● Bluetooth playback     bluealsa-aplay.service
  ● DLNA/UPnP              piaudio-dlna.service
  ● Network discovery      avahi-daemon.service

  Bluetooth connected:
    Ben's Pixel
```

---

## Multi-room

Run the installer on each Pi with a different name. On iOS, Control Center → AirPlay → tick several speakers; each gets its own volume slider, and AirPlay 2 keeps them in sync via `nqptp`.

Bluetooth is point-to-point and can't do multi-room. On Android, use Spotify Connect (Spotify's own group feature) or a DLNA app that supports grouping.

---

## Requirements

- Raspberry Pi 2 / Zero 2 W or newer. AirPlay 2 is noticeably more CPU-hungry than AirPlay 1; on a Zero 2 W consider `--airplay 1`.
- Raspberry Pi OS, Lite or Desktop, Bullseye or later.
- A speaker on the 3.5mm jack, HDMI, USB, or a DAC HAT.
- Wired or wireless network.

---

## How it works

Audio goes **straight to ALSA** — there is no PulseAudio or PipeWire session involved. That's deliberate: a per-user sound server is the usual reason these setups work on Desktop images and mysteriously fail on Lite, or break after a reboot when nobody has logged in.

```
 iPhone ──AirPlay 2──▶ shairport-sync ─┐
                          + nqptp      │
 Android ─Bluetooth──▶ bluez-alsa ─────┤
                     (bluealsa-aplay)  ├──▶ ALSA dmix ──▶ your speaker
 Spotify ──Connect───▶ librespot ──────┤
                                       │
 DLNA app ──UPnP─────▶ gmediarender ───┘
```

`dmix` is a shared software mixer, so all four receivers can hold the sound card simultaneously instead of locking each other out. Each one does its own software volume, which means the volume control on your phone works even on outputs with no hardware mixer (HDMI and most USB DACs), and adjusting AirPlay volume doesn't clobber the Bluetooth level.

The installer also:

- sets the Bluetooth class to *loudspeaker* so phones show a speaker icon and offer media audio,
- runs a `NoInputNoOutput` pairing agent, since a speaker has no keypad to confirm a PIN on,
- keeps the adapter discoverable and pairable permanently,
- disables WiFi power saving, which is the usual cause of AirPlay stutter on a Pi,
- gives the DLNA renderer a stable UUID so it doesn't reappear as a new device after every reboot.

Original files it touches (`/etc/asound.conf`, `/etc/bluetooth/main.conf`, `/etc/shairport-sync.conf`) are backed up to `/var/backups/piaudio/` and restored by `piaudio uninstall`.

### About the Spotify option

Spotify Connect is **off by default** because it installs [Raspotify](https://github.com/dtcooper/raspotify), which adds a third-party apt repository to your Pi. That's a persistent change to where your system gets packages, so it's your call rather than a silent default. Everything else comes from Raspberry Pi OS's own repositories, except shairport-sync and nqptp when compiled from their upstream sources.

### About Bluetooth pairing

The Pi accepts pairing requests automatically, exactly like a commercial Bluetooth speaker. That means **anyone within radio range can pair with it** while it's discoverable. That's the normal trade-off for a speaker, but if the Pi lives somewhere public, run with `--bluetooth off` and use AirPlay or DLNA instead.

---

## Troubleshooting

**Nothing plays / no sound**

```bash
piaudio status
piaudio test
```

If the test tone is silent, the output device is wrong — `sudo piaudio output` lets you pick another. On the 3.5mm jack, check the level with `alsamixer`.

**AirPlay speaker doesn't appear on the iPhone**

```bash
systemctl status nqptp shairport-sync
piaudio logs shairport-sync
```

AirPlay 2 will not work without `nqptp` running. Also confirm the phone and Pi are on the same network and subnet — AirPlay discovery is mDNS and doesn't cross VLANs or guest networks.

**Bluetooth pairs but no audio**

Almost always a conflict with PipeWire's Bluetooth plugin on Desktop images — both it and bluez-alsa try to claim the same BlueZ endpoint:

```bash
sudo apt remove libspa-0.2-bluetooth
sudo reboot
```

**Bluetooth not discoverable**

```bash
sudo systemctl restart piaudio-bluetooth
bluetoothctl show
```

**Audio stutters over WiFi**

Ethernet is the real fix. Otherwise confirm power saving is off (`iw dev wlan0 get power_save`) and move the Pi closer to the router — 2.4 GHz is often congested.

**Start over**

```bash
sudo piaudio uninstall && sudo piaudio install
```

---

## Upgrading from the old `setup.sh`

Version 1 of this repo used `setup.sh` with PulseAudio. Version 2 replaces it with the single `piaudio` executable and drops PulseAudio entirely. Bluetooth in particular never actually produced sound in v1 — A2DP audio arrives as a capture stream and nothing was routing it to the speaker.

The cleanest upgrade path is a fresh Pi OS image. On an existing v1 install, remove the old services first:

```bash
sudo systemctl disable --now shairport-sync nqptp gmediarender bt-agent bt-discoverable
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/bkravets06/RaspberryPiWirelessAudioScript/main/piaudio)"
```

---

## Credits

Built on [shairport-sync](https://github.com/mikebrady/shairport-sync) and [nqptp](https://github.com/mikebrady/nqptp) by Mike Brady, [bluez-alsa](https://github.com/arkq/bluez-alsa), [gmediarender](https://github.com/hzeller/gmrender-resurrect), and [librespot](https://github.com/librespot-org/librespot) via [Raspotify](https://github.com/dtcooper/raspotify).

MIT License.
