
# Pop OS (and *buntu) Sound Fix for Intel Arrow Lake Audio (Alienware Area 51 2025)

Sound issues on Pop!_OS with Intel Arrow Lake audio hardware using RT722 (headphone jack) and RT1320 (speaker amplifier) codecs connected via SoundWire.

# Shilling my Website lol
Check out https://capybloominteractive.com

**What we are solving**
- No sound from internal speakers
- Sound works sporadically or stops after reboot
- Multiple "sof-soundwire" devices appear but none produce sound

## Why its happening

**1. Outdated ALSA UCM config**

Pop!_OS ships with `alsa-ucm-conf` version 1.2.8 which lacks RT722/RT1320 codec support. Version 1.2.10+ is required.

**2. Hardware Switches Disabled by Default**

Three hardware switches are disabled by default:
- `Speaker` - Main speaker enable
- `rt1320-1 OT23 L` - Left speaker output terminal
- `rt1320-1 OT23 R` - Right speaker output terminal

## How this script solves it

1. Updates `alsa-ucm-conf` to version 1.2.10+
2. Enables hardware switches immediately
3. Installs systemd service for automatic switch enabling on boot
4. Profit


## What to do

```bash
# Run the fix script
./fix-sound.sh

# Optionally reboot
sudo reboot
```

## Verification

```bash
# Check UCM version (should be 1.2.10+)
apt-cache policy alsa-ucm-conf

# Check systemd service to make sure it stays working lol
systemctl status sound-switches.service

# Test audio, if this doesnt work try youtube or something
pw-cat --playback /usr/share/sounds/freedesktop/stereo/bell.oga
```

## More info about what we're doing

### UCM Package Update

Updates from Pop!_OS 1.2.8 to Ubuntu 1.2.10:

```bash
sudo apt-mark unhold alsa-ucm-conf
sudo apt-get remove --purge -y alsa-ucm-conf
sudo apt-get install -y alsa-ucm-conf=1.2.10-1ubuntu5.7
sudo apt-mark hold alsa-ucm-conf
```

Package is held to prevent automatic downgrades.  This is important as it can undo all of our work (running the script I made)

### Hardware Switches

Required ALSA mixer controls enabled with:
```bash
amixer -c 1 sset 'Speaker' on
amixer -c 1 sset 'rt1320-1 FU' cap
amixer -c 1 sset 'rt1320-1 OT23 L' on
amixer -c 1 sset 'rt1320-1 OT23 R' on
```

### Systemd Service

Runs `enable-sound-switches.sh` on boot after sound system initialization.  That's why there's a 2 second sleep 

## Usage

**Longterm fix, also may need to run after updates:**
```bash
./fix-sound.sh
```

**Quick fix without install:**
```bash
./enable-sound-switches.sh
```

**Sound breaks after reboot:**

```bash
# Verify service is enabled
systemctl is-enabled sound-switches.service

# Check service status
systemctl status sound-switches.service

# Re-run fix and pray to the old gods and the new
./fix-sound.sh
```

## Uninstall if u hate sound

```bash
# Remove systemd service
sudo systemctl disable sound-switches.service
sudo rm /etc/systemd/system/sound-switches.service
sudo systemctl daemon-reload

# Revert UCM (will break sound :c )
sudo apt-mark unhold alsa-ucm-conf
sudo apt-get install alsa-ucm-conf=1.2.8-1pop1~1709769747~24.04~16ff971
```

**WARNING:** Use at your own risk and good luck c:
