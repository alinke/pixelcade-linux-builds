#!/bin/bash
install_succesful=false
auto_update=false
pizero=false
pi4=false
pi3=false
odroidn2=false
machine_arch=default
version=2  #increment this as the script is updated
pixelcade_version=default
NEWLINE=$'\n'

# Run this script with this command
# wget https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/main/install-scripts/setup-batocera.sh && chmod +x setup-batocera.sh && ./setup-batocera.sh

cat << "EOF"
       _          _               _
 _ __ (_)_  _____| | ___ __ _  __| | ___
| '_ \| \ \/ / _ \ |/ __/ _` |/ _` |/ _ \
| |_) | |>  <  __/ | (_| (_| | (_| |  __/
| .__/|_/_/\_\___|_|\___\__,_|\__,_|\___|
|_|
EOF

echo "       Pixelcade LCD Updater for Linux : Installer Version $version    "
echo ""
echo "This script will update your Pixelcade LCD with the latest artwork and system files"
echo "Please ensure this device is on the same network as your Pixelcade LCD"
echo "Grab a coffee or tea as this installer will take around 10 minutes depending on your Internet connection speed"

function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

INSTALLPATH="${HOME}/"

# The possible platforms are:
# linux_arm64
# linux_386
# linux_amd64
# linux_arm_v6
# linux_arm_v7
# darwin

#rcade is armv7 userspace and aarch64 kernel space so it shows aarch64
#Pi model B+ armv6, no work

if uname -m | grep -q 'armv6'; then
   echo "${yellow}arm_v6 Detected..."
   machine_arch=arm_v6
fi

if uname -m | grep -q 'armv7'; then
   echo "${yellow}arm_v7 Detected..."
   machine_arch=arm_v7
fi

if uname -m | grep -q 'aarch32'; then
   echo "${yellow}aarch32 Detected..."
   aarch32=arm_v7
fi

if uname -m | grep -q 'aarch64'; then
   echo "${yellow}aarch64 Detected..."
   machine_arch=arm64
fi

if uname -m | grep -q 'x86'; then
   echo "${yellow}x86 32-bit Detected..."
   machine_arch=386
fi

if uname -m | grep -q 'amd64'; then
   echo "${yellow}x86 64-bit Detected..."
   machine_arch=amd64
fi

if uname -m | grep -q 'x86_64'; then
   echo "${yellow}x86 64-bit Detected..."
   machine_arch=amd64
fi

if [[ "$(uname)" == "Darwin" ]]; then
    echo "${yellow}Mac OS Detected..."
    machine_arch=darwin
fi

if [[ $machine_arch == "default" ]]; then
    echo "[ERROR] Your device platform WAS NOT Detected"
    echo "[WARNING] Guessing that you are on aarch64 but be aware Pixelcade may not work"
    machine_arch=arm64
fi

echo "Downloading Pixelcade LCD Updater..."

if [[ -d ${INSTALLPATH}pixelcade ]]; then
   wget -O ${INSTALLPATH}pixelcade/lcdupdate https://github.com/alinke/pixelcade-linux-builds/raw/main/lcdupdater/linux_${machine_arch}/lcdupdate
   cd ${INSTALLPATH}pixelcade
else
    wget -O ${INSTALLPATH}lcdupdate https://github.com/alinke/pixelcade-linux-builds/raw/main/lcdupdater/linux_${machine_arch}/lcdupdate
    cd ${INSTALLPATH}
fi

chmod +x lcdupdate
./lcdupdate

