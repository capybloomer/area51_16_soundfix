#!/bin/bash
################################################################################
# Pop!_OS Sound Fix for Intel Arrow Lake Audio (RT722/RT1320)
#
# This script fixes sound not on Pop!_OS systems with Intel Arrow Lake
# audio hardware that uses RT722 (headphone jack) and RT1320 (speaker amp)
# codecs connected via SoundWire.  
#
# 1. Updates alsa-ucm-conf to version 1.2.10+ (required for RT722/RT1320)
# 2. Enables hardware switches immediately for current session
# 3. Installs systemd service to enable switches automatically on boot
# 4. Tests audio output
#
# Usage:
#   ./fix-sound.sh
#
# Author: Capybloom Interactive
# Date: October 21, 2025
################################################################################

set -e  

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' 

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_step() {
    echo -e "\n${CYAN}===${NC} $1 ${CYAN}===${NC}\n"
}

if [ "$EUID" -eq 0 ]; then
    print_error "Please do NOT run this script with sudo"
    print_info "The script will ask for sudo password when needed"
    exit 1
fi

echo " "
echo "     Pop OS Sound Fix for Intel Arrow Lake Audio                           "
echo "     RT722/RT1320 Codec Support                                             "
echo " "
echo "---"

print_step "Step 1: Checking ALSA UCM Configuration"

CURRENT_VERSION=$(apt-cache policy alsa-ucm-conf | grep "Installed:" | awk '{print $2}')
print_info "Current version: $CURRENT_VERSION"

if [[ $CURRENT_VERSION == *"1.2.10"* ]] || [[ $CURRENT_VERSION > "1.2.10" ]]; then
    print_success "UCM version is already 1.2.10 or newer, skipping update"
    UCM_UPDATED=0
elif [[ $CURRENT_VERSION == *"1.2.8"* ]] || [[ $CURRENT_VERSION < "1.2.10" ]]; then
    print_warning "UCM version is outdated (need 1.2.10+)"
    print_info "This version lacks RT722/RT1320 codec support"

    read -p "Would you like to update to UCM 1.2.10? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_step "Step 1a: Updating alsa-ucm-conf Package"

        print_info "Removing package hold (if any exist lol)..."
        sudo apt-mark unhold alsa-ucm-conf 2>/dev/null || true

        print_info "Removing old version..."
        sudo apt-get remove --purge -y alsa-ucm-conf

        print_info "Installing Ubuntu version 1.2.10..."
        sudo apt-get install -y alsa-ucm-conf=1.2.10-1ubuntu5.7

        print_info "Holding package to prevent downgrades..."
        sudo apt-mark hold alsa-ucm-conf

        print_success "UCM updated to 1.2.10"
        UCM_UPDATED=1

        print_info "Verifying UCM configuration files..."
        if [ -d "/usr/share/alsa/ucm2/sof-soundwire" ]; then
            RT722_FOUND=$(find /usr/share/alsa/ucm2 -name "*rt722*" 2>/dev/null)
            RT1320_FOUND=$(find /usr/share/alsa/ucm2 -name "*rt1320*" 2>/dev/null)

            if [ -n "$RT722_FOUND" ] && [ -n "$RT1320_FOUND" ]; then
                print_success "RT722 and RT1320 UCM files confirmed"
            else
                print_error "Uh oh.. UCM files not found - this may cause issues"
            fi
        fi
    else
        print_warning "Skipping UCM update.  Sound maaaay not work properly"
        UCM_UPDATED=0
    fi
else
    print_warning "Unknown UCM version: $CURRENT_VERSION"
    UCM_UPDATED=0
fi

if [ $UCM_UPDATED -eq 1 ]; then
    print_step "Step 2: Restarting Audio Services"

    print_info "Restarting PipeWire and WirePlumber..."
    systemctl --user restart pipewire pipewire-pulse wireplumber
    sleep 3
    print_success "Audio services restarted"
fi

print_step "Step 3: Detecting Sound Card"

CARD_NUM=$(aplay -l 2>/dev/null | grep "sof-soundwire" | head -1 | sed 's/card \([0-9]\).*/\1/')

if [ -z "$CARD_NUM" ]; then
    print_error "sof-soundwire card not found!"
    print_info "Available sound cards:"
    aplay -l | sed 's/^/    /'
    echo ""
    print_error "Cannot continue without sound card :c "
    print_warning "Try rebooting and running this script again"
    exit 1
else
    print_success "Found sof-soundwire as card $CARD_NUM"
fi

print_step "Step 4: Enabling Hardware Switches"

print_info "Enabling Speaker switch..."
if amixer -c "$CARD_NUM" sset 'Speaker' on &>/dev/null; then
    print_success "Speaker switch enabled"
else
    print_warning "Speaker switch not found..."
fi

print_info "Enabling RT1320 amplifier..."
if amixer -c "$CARD_NUM" sset 'rt1320-1 FU' cap &>/dev/null; then
    print_success "RT1320 amplifier enabled"
else
    print_warning "RT1320 FU control not found (are you sure this is the right laptop?)"
fi

print_info "Enabling RT1320 left output..."
if amixer -c "$CARD_NUM" sset 'rt1320-1 OT23 L' on &>/dev/null; then
    print_success "RT1320 left output enabled"
else
    print_warning "RT1320 OT23 L not found (seriously, this might be the wrong laptop lol)"
fi

print_info "Enabling RT1320 right output..."
if amixer -c "$CARD_NUM" sset 'rt1320-1 OT23 R' on &>/dev/null; then
    print_success "RT1320 right output enabled"
else
    print_warning "RT1320 OT23 R not found"
fi

print_step "Step 5: Setting Default Audio Output"

SPEAKER_SINK=$(pactl list sinks short | grep "pro-output-2" | awk '{print $2}')
if [ -n "$SPEAKER_SINK" ]; then
    print_info "Setting default output to speakers..."
    pactl set-default-sink "$SPEAKER_SINK"
    print_success "Default output set to: $SPEAKER_SINK"
else
    print_warning "Speaker output (pro-output-2) not found"
    print_info "Available outputs:"
    pactl list sinks short | sed 's/^/    /'
fi

print_step "Step 6: Installing Systemd Service"

if [ ! -f "$SCRIPT_DIR/enable-sound-switches.sh" ]; then
    print_error "enable-sound-switches.sh not found in $SCRIPT_DIR"
    print_warning "Skipping systemd service installation"
else
    print_info "Installing systemd service for automatic switch enabling on boot..."

    sudo cp "$SCRIPT_DIR/enable-sound-switches.sh" "$SCRIPT_DIR/enable-sound-switches.sh.tmp"
    sudo mv "$SCRIPT_DIR/enable-sound-switches.sh.tmp" "$SCRIPT_DIR/enable-sound-switches.sh"
    sudo chmod +x "$SCRIPT_DIR/enable-sound-switches.sh"

    if [ -f "$SCRIPT_DIR/sound-switches.service" ]; then
        sed "s|/home/capy/Sound|$SCRIPT_DIR|g" "$SCRIPT_DIR/sound-switches.service" | sudo tee /etc/systemd/system/sound-switches.service > /dev/null

        sudo systemctl daemon-reload
        sudo systemctl enable sound-switches.service

        print_success "Systemd service installed and enabled"
        print_info "Sound switches will be enabled automatically on every boot"
    else
        print_warning "sound-switches.service file not found - skipping systemd installation"
    fi
fi

print_step "Step 7: Testing Audio Output"

if [ -f /usr/share/sounds/freedesktop/stereo/bell.oga ]; then
    print_info "Playing test sound in 2 seconds..."
    sleep 2

    if pw-cat --playback /usr/share/sounds/freedesktop/stereo/bell.oga 2>/dev/null; then
        echo ""
        read -p "Did you hear for whom the bell tolled (you)? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_success "yay, it worked"
        else
            print_warning "Bell successfully played but you didnt hear it"
            print_info "Make sure your sound is turned up or try a youtube video or something."
        fi
    else
        print_error "Failed to play test sound"
    fi
else
    print_warning "Test sound file not found"
    print_info "Try playing audio from youtube or something"
fi

print_step "Installation Complete"

echo "--"
print_success "Sound fix has been applied!"

print_info "For troubleshooting check:"
echo "  - systemctl status sound-switches.service"
echo "  - journalctl -u sound-switches.service"
echo "---"
echo "Good luck, friend."
