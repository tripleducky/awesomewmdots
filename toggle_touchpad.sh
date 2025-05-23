#!/bin/bash

TOUCHPAD_NAME="DELL0A6E:00 04F3:317E Touchpad"  # Change to your touchpad's name

# Check if any mouse is connected
if xinput list | grep -q "Logitech G203"; then  # Replace "Mouse" with your device's identifier
    xinput disable "$TOUCHPAD_NAME"
else
    xinput enable "$TOUCHPAD_NAME"
fi
