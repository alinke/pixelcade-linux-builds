#!/bin/bash
version=12
INSTALLDIR=$(readlink -f $(dirname "$0"))
pixelcadePort="/dev/ttyACM0"

cat << "EOF"
       _          _               _
 _ __ (_)_  _____| | ___ __ _  __| | ___
| '_ \| \ \/ / _ \ |/ __/ _` |/ _` |/ _ \
| |_) | |>  <  __/ | (_| (_| | (_| |  __/
| .__/|_/_/\_\___|_|\___\__,_|\__,_|\___|
|_|
EOF

echo "${magenta}       Pixelcade Launcher for MiSTer $version    ${white}"
echo ""
echo "Now connect Pixelcade LED to a USB hub connected to your MiSTer"
echo "If using Pixelcade LCD, your Pixelcade LCD will need to be connected to your WiFI or Ethernet network"
#let's check if pixelweb is already running and if so, kill it
if ps aux | grep -q 'pixelweb'; then
   echo "${yellow}Pixelcade Already Running${white}"
   ps -ef | grep pixelweb | grep -v grep | awk '{print $1}' | xargs kill
fi

# let's detect if Pixelcade is USB connected, could be 0 or 1 so we need to check both, don't exit because we may have LCD only
if ls /dev/ttyACM0 | grep -q '/dev/ttyACM0'; then
   echo "Pixelcade LED Marquee Detected on ttyACM0"
   pixelcadePort="/dev/ttyACM0"
else
    if ls /dev/ttyACM1 | grep -q '/dev/ttyACM1'; then
        echo "Pixelcade LED Marquee Detected on ttyACM1"
        pixelcadePort="/dev/ttyACM1"
    else
       echo "${red}Pixelcade LED Marquee was not detected, please ensure Pixelcade is USB connected to your MiSTer"
    fi
fi

cd $INSTALLDIR
echo "Pixelcade is Starting..."
./pixelweb -image "system/mister.png" -startup &
echo "3 second delay"
sleep 3

killall -9 pixelcadeLink 2>/dev/null

echo "localhost" > /media/fat/pixelcade/ip.txt #pixelcadeLink.sh uses this file to send the REST call so we'll always go localhost and then pixelweb will relay to LCD if needed
echo "Set Pixelcade IP to: localhost"

echo "Killing MiSTer and relaunching"
killall -9 MiSTer 2>/dev/null         #if this is removed, cores will take longer to load , reason unknown
sleep 1
nohup /media/fat/MiSTer 2>/dev/null &   #if you are not running MiSTer off the microSD card, change this path to match yours
nohup sh ${INSTALLDIR}./pixelcadeLink.sh 2>/dev/null &  #this script monitors /tmp which is where the selected game and console is written, see CORENAME, CURRENTPATH, and FULLPATH, Pixelcade uses this data
echo "Pixelcade is Ready and Running..."
