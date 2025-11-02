#!/bin/bash
# This script ensures all the hardware switches are enabled for sound to work for sof-audio-pci-intel-mtl
sleep 2
CARD_NUM=$(aplay -l 2>/dev/null | grep "sof-audio-pci-intel-mtl" | head -1 | sed 's/card \([0-9]\).*/\1/')
if [ -z "$CARD_NUM" ]; then
    echo "Error: sof-audio-pci-intel-mtl card not found"
    exit 1
fi
amixer -c "$CARD_NUM" sset 'Speaker' on 2>/dev/null
amixer -c "$CARD_NUM" sset 'rt1320-1 FU' cap 2>/dev/null
amixer -c "$CARD_NUM" sset 'rt1320-1 OT23 L' on 2>/dev/null
amixer -c "$CARD_NUM" sset 'rt1320-1 OT23 R' on 2>/dev/null
echo "Sound switches enabled on card $CARD_NUM"
exit 0
