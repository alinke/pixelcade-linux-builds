#!/bin/bash

function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

echo "Pixelcade Software installation - USB Connected Pixelcade LCD Marquee"
mkdir -p /etc/connman
echo "[General]" > /etc/connman/main.conf
echo "NetworkInterfaceBlacklist=eth1" >> /etc/connman/main.conf
batocera-save-overlay
echo "Please now USB connect your Pixelcade LCD Marquee to your Batocera device"
pause
curl -kLO -H "Cache-Control: no-cache" https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/main/install-scripts/setup-batocera.sh && chmod +x setup-batocera.sh && ./setup-batocera.sh lcdusb


