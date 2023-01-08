#!/bin/bash
pixelcade_detected=false
java_installed=false
INSTALLDIR=$(readlink -f $(dirname "$0"))

cat << "EOF"
       _          _               _
 _ __ (_)_  _____| | ___ __ _  __| | ___
| '_ \| \ \/ / _ \ |/ __/ _` |/ _` |/ _ \
| |_) | |>  <  __/ | (_| (_| | (_| |  __/
| .__/|_/_/\_\___|_|\___\__,_|\__,_|\___|
|_|
EOF

echo "${magenta}       Pixelcade LED Launcher for MiSTer $version    ${white}"
echo ""
echo "Now connect Pixelcade to a USB hub connected to your MiSTer"
echo "Ensure the toggle switch on the Pixelcade board is pointing towards USB and not BT"
#let's check if pixelweb is already running and if so, kill it
if ps aux | grep -q 'pixelweb'; then
   echo "${yellow}Pixelcade Already Running${white}"
   ps -ef | grep pixelweb | grep -v grep | awk '{print $1}' | xargs kill
fi
# detect what OS we have
if ls /dev/ttyACM0 | grep -q '/dev/ttyACM0'; then
   echo "${yellow}Pixelcade LED Marquee Detected${white}"
else
  echo "${red}Sorry, a Pixelcade LED Marquee was not detected, please ensure Pixelcade is USB connected to your Pi and the toggle switch on the Pixelcade board is pointing towards USB, exiting..."
  exit 1
fi

cd $INSTALLDIR
echo "Pixelcade is Starting..."
./pixelweb -image "system/mister.png" -startup &
echo "10 second delay"
sleep 10

saveIP=`cat /media/fat/pixelcade/ip.txt`  #this will be localhost for Pixelcade LED and would be a real IP if using Pixelcade LCD

killall -9 pixelcadeLink 2>/dev/null

if [ "${saveIP}" == "" ]; then
 echo "Finding Pixelcade"
 ${INSTALLDIR}/pixelcadeFinder |grep Peer| tail -1| cut -d' ' -f2 > /media/fat/pixelcade/ip.txt
 echo "Pixelcade IP: `cat /media/fat/pixelcade/ip.txt`"
else
 echo "Using saved Pixelcade: `cat /media/fat/pixelcade/ip.txt`"
fi

echo "Killing MiSTer and relaunching"
killall -9 MiSTer 2>/dev/null         #if this is removed, cores will take longer to load , reason unknown
sleep 1
nohup /media/fat/MiSTer 2>/dev/null &   #if you are not running MiSTer off the microSD card, change this path to match yours
nohup sh ${INSTALLDIR}./pixelcadeLink.sh 2>/dev/null &  #this script monitors /tmp which is where the selected game and console is written, see CORENAME, CURRENTPATH, and FULLPATH, Pixelcade uses this data
echo "Pixelcade is Ready and Running..."
