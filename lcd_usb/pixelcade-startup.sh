#!/bin/bash
# startup script for a dedicated Pi for Pixelcade
connected=false
usbConnected=false
ethernetConnected=false
retries=0
/home/pi/pixelcade/system/announce & #this is mDNS
cat << "EOF"
       _          _               _
 _ __ (_)_  _____| | ___ __ _  __| | ___
| '_ \| \ \/ / _ \ |/ __/ _` |/ _` |/ _ \
| |_) | |>  <  __/ | (_| (_| | (_| |  __/
| .__/|_/_/\_\___|_|\___\__,_|\__,_|\___|
|_|
EOF
sleep 10

# Check USB gadget connectivity
if [[ $(cat /sys/class/net/usb0/carrier) -eq 1 ]]; then #it would return 0 if we are not USB connected
    usbConnected=true
fi

# Connectivity check for user's specific WiFi network
export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/host/run/dbus/system_bus_socket

echo "Checking WiFi connectivity..."
USER_WIFI_SSID=$(head -n 1 /home/pi/pixelcade/user/pixelcade/settings/.wifi)  # Get the user's WiFi SSID

CURRENT_WIFI_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2)
if [ "$CURRENT_WIFI_SSID" == "$USER_WIFI_SSID" ]; then
    connected=true
    echo "Connected to the user's WiFi network: $CURRENT_WIFI_SSID"
else
    echo "Not connected to the user's WiFi network."
    connected=false
fi

# Are we Ethernet connected?
if [ -e /sys/class/net/eth0 ] && [ "$(cat /sys/class/net/eth0/carrier)" = "1" ]; then
    connected=true
    ethernetConnected=true
fi

if [ "$connected" = false ]; then
    echo "Attempting to connect to WiFi..."
    sudo snap connect network-manager:nmcli
    arr_lines=()
    while IFS= read -r line; do
        arr_lines+=("$line")
    done < /home/pi/pixelcade/user/pixelcade/settings/.wifi

    SSID="${arr_lines[0]}"
    PASS="${arr_lines[1]}"

    sudo -u pi nmcli c delete "${SSID}" 2>/dev/null
    effort=$(sudo -u pi nmcli d wifi connect "${SSID}" password "${PASS}" 2>&1)
    echo "$effort" | grep "successfully activated" >/dev/null
    if [ "$?" -eq 0 ]; then
        connected=true
        echo "WiFi connected successfully to $SSID."
    else
        echo "WiFi connection failed."
    fi
fi

# Remove first-time connection marker if it exists
if [[ -f "$HOME/pixelcade/deletemeafterwificonnect.txt" ]]; then
    sudo rm "$HOME/pixelcade/deletemeafterwificonnect.txt"
fi

# Check for User USB Media
echo "Checking for User USB Media..."
"/home/pi/pixelcade/system/addUSBShare.sh" &

sudo killall -9 mplayer

if [ "$connected" = false ] && [ "$usbConnected" = false ]; then
    /home/pi/pixelcade/gsho -platform linuxfb /home/pi/pixelcade/lcdmarquees/pixelcade-error.jpg &
elif [ "$ethernetConnected" = true ] && [ "$usbConnected" = false ]; then
    /home/pi/pixelcade/gsho -platform linuxfb /home/pi/pixelcade/lcdmarquees/pixelcade-ethernetonly.jpg &    
elif [ "$ethernetConnected" = true ] && [ "$usbConnected" = true ]; then
    /home/pi/pixelcade/gsho -platform linuxfb /home/pi/pixelcade/lcdmarquees/pixelcade-ethernetusb.jpg &        
elif [ "$connected" = true ] && [ "$usbConnected" = false ]; then
    /home/pi/pixelcade/gsho -platform linuxfb /home/pi/pixelcade/lcdmarquees/pixelcade-wifionly.jpg &
elif [ "$connected" = false ] && [ "$usbConnected" = true ]; then
    /home/pi/pixelcade/gsho -platform linuxfb /home/pi/pixelcade/lcdmarquees/pixelcade-usbonly.jpg &
elif [ "$connected" = true ] && [ "$usbConnected" = true ]; then
    /home/pi/pixelcade/gsho -platform linuxfb /home/pi/pixelcade/lcdmarquees/pixelcade-usbwifi.jpg &
else
    /home/pi/pixelcade/gsho -platform linuxfb /home/pi/pixelcade/lcdmarquees/pixelcade-error.jpg &
fi

echo "Startup succeeded"
exit
