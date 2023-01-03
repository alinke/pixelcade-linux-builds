#!/bin/bash
java_installed=false
install_succesful=false
auto_update=false #this doesn't do anything, keep on false
PIXELCADE_PRESENT=false
version=10  #increment this as the script is updated
machine_arch=default

cat << "EOF"
       _          _               _
 _ __ (_)_  _____| | ___ __ _  __| | ___
| '_ \| \ \/ / _ \ |/ __/ _` |/ _` |/ _ \
| |_) | |>  <  __/ | (_| (_| | (_| |  __/
| .__/|_/_/\_\___|_|\___\__,_|\__,_|\___|
|_|
EOF

echo "       Pixelcade LED for EmuELEC : Installer Version $version    "
echo ""
echo "This script will install Pixelcade in your /storage/roms folder"
echo "Plese ensure you have at least 800 MB of free disk space in /storage/roms"
echo "Now connect Pixelcade to a free USB port on your device (Odroid, Android Box, etc)"
echo "Ensure the toggle switch on the Pixelcade board is pointing towards USB and not BT"
echo "Grab a coffee or tea as this installer will take around 15 minutes"

INSTALLPATH="/storage/roms/"

function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

# let's detect if Pixelcade is USB connected, could be 0 or 1 so we need to check both
if ls /dev/ttyACM0 | grep -q '/dev/ttyACM0'; then
   echo "Pixelcade LED Marquee Detected on ttyACM0"
else
    if ls /dev/ttyACM1 | grep -q '/dev/ttyACM1'; then
        echo "Pixelcade LED Marquee Detected on ttyACM1"
    else
       echo "Sorry, Pixelcade LED Marquee was not detected, pleasse ensure Pixelcade is USB connected to your Pi and the toggle switch on the Pixelcade board is pointing towards USB, exiting..."
       exit 1
    fi
fi

# let's make sure we have EmuELEC installation
if lsb_release -a | grep -q 'EmuELEC'; then
        echo "EmuELEC Detected"
else
   echo "Sorry, EmuELEC was not detected, exiting..."
   exit 1
fi

echo "Stopping Pixelcade (if running...)"
# let's make sure pixelweb is not already running
killall java #in the case user has java pixelweb running
curl localhost:8080/quit

#. /etc/profile

#ee_console enable
#echo "Checking JDK..." > /dev/console

JDKDEST="${HOME}/roms/bios/jdk"
JDKNAME="zulu18.0.45-ea-jdk18.0.0-ea.18"
CDN="https://cdn.azul.com/zulu/bin"

# Alternate just for reference
#CDN="https://cdn.azul.com/zulu-embedded/bin"

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

if cat /proc/device-tree/model | grep -q 'Raspberry Pi 3'; then
   echo "${yellow}Raspberry Pi 3 detected..."
   pi3=true
fi

if cat /proc/device-tree/model | grep -q 'Pi 4'; then
   printf "${yellow}Raspberry Pi 4 detected...\n"
   pi4=true
fi

if cat /proc/device-tree/model | grep -q 'Pi Zero W'; then
   printf "${yellow}Raspberry Pi Zero detected...\n"
   pizero=true
fi

if cat /proc/device-tree/model | grep -q 'ODROID-N2'; then
   printf "${yellow}ODroid N2 or N2+ detected...\n"
   odroidn2=true
fi

if [[ $machine_arch == "default" ]]; then
  echo "[ERROR] Your device platform WAS NOT Detected"
  echo "[WARNING] Guessing that you are on aarch64 but be aware Pixelcade may not work"
  machine_arch=arm64
fi

mkdir -p "${JDKDEST}"

OLDVERSION="$(cat ${JDKDEST}/eeversion 2>/dev/null)"
if [ "${JDKNAME}" != "${OLDVERSION}" ]; then
   JDKINSTALLED="no"
   rm -rf "${JDKDEST}"
   mkdir -p "${JDKDEST}"
fi

if [ "${JDKINSTALLED}" == "no" ]; then
echo -e "GET http://google.com HTTP/1.0\n\n" | nc google.com 80
if [ $? -ne 0 ]; then
    echo "No internet connection, exiting..."
    text_viewer -e -w -t "No Internet!" -m "You need to be connected to the internet to download the JDK\nNo internet connection, exiting...";
    exit 1
fi
    echo "Downloading JDK please be patient..."
    cd ${JDKDEST}/..
    wget "${CDN}/${JDKNAME}-linux_aarch64.tar.gz"
    echo "Inflating JDK please be patient..."
    tar xvfz ${JDKNAME}-linux_aarch64.tar.gz ${JDKNAME}-linux_aarch64/lib
    tar xvfz ${JDKNAME}-linux_aarch64.tar.gz ${JDKNAME}-linux_aarch64/bin
    tar xvfz ${JDKNAME}-linux_aarch64.tar.gz ${JDKNAME}-linux_aarch64/conf
    rm ${JDKNAME}-linux_aarch64/lib/*.zip
    mv ${JDKNAME}-linux_aarch64/* ${JDKDEST}
    rm -rf ${JDKNAME}-linux_aarch64*

    for del in jmods include demo legal man DISCLAIMER LICENSE readme.txt release Welcome.html; do
        rm -rf ${JDKDEST}/${del}
    done
    echo "JDK done! loading core!"
    cp -rf /usr/lib/libretro/freej2me-lr.jar ${HOME}/roms/bios
    echo "${JDKNAME}" > "${JDKDEST}/eeversion"
fi


if [[ -f master.zip ]]; then
    rm master.zip
fi

cd ${INSTALLPATH}pixelcade
echo "Installing Pixelcade Software..."
if [[ -f pixelweb ]]; then
    echo "Removed previous version of Pixelcade (pixelweb - Pixelcade Listener)..."
    rm pixelweb
fi
wget https://github.com/alinke/pixelcade-linux-builds/raw/main/linux_${machine_arch}/pixelweb
chmod +x pixelweb
./pixelweb -install-artwork #install the artwork

if [[ $? == 2 ]]; then #this means artwork is already installed so let's check for updates and get if so
  echo "Checking for new Pixelcade artwork..."
  cd ${INSTALLPATH}pixelcade && ./pixelweb -update-artwork
fi

if [[ -d ${INSTALLPATH}ptemp ]]; then
    rm -r ${INSTALLPATH}ptemp
fi

#creating a temp dir for the Pixelcade common system files & scripts
mkdir ${INSTALLPATH}ptemp
cd ${INSTALLPATH}ptemp

#get the Pixelcade system files
wget https://github.com/alinke/pixelcade-linux/archive/refs/heads/main.zip
unzip main.zip

if [[ ! -d /storage/.emulationstation/scripts ]]; then #does the ES scripts folder exist, make it if not
    mkdir /storage/.emulationstation/scripts
fi

#copy over the custom scripts
echo "${yellow}Installing Pixelcade EmulationStation Scripts...${white}"
cp -r -f ${INSTALLPATH}ptemp/pixelcade-linux-main/emuelec/scripts /storage/.emulationstation #note this will overwrite existing scripts
find /storage/.emulationstation/scripts -type f -iname "*.sh" -exec chmod +x {} \; #make all the scripts executble
#hi2txt for high score scrolling
echo "${yellow}Installing hi2txt for High Scores...${white}"
cp -r -f ${INSTALLPATH}ptemp/pixelcade-linux-main/hi2txt ${INSTALLPATH} #for high scores

# let's make sure we have EmuELEC installation
if lsb_release -a | grep -q '4.4-TEST'; then
        echo "EmuELEC 4.4-TEST Detected so let's copy over the patched retroarch for RetroAchievements"
        cp -f ${INSTALLPATH}ptemp/pixelcade-linux-main/retroarch/retroarch /emuelec/bin/retroarch
        chmod +x /emuelec/bin/retroarch
fi

sed -i '/all,mame/d' ${INSTALLPATH}pixelcade/console.csv
sed -i '/favorites,mame/d' ${INSTALLPATH}pixelcade/console.csv
sed -i '/recent,mame/d' ${INSTALLPATH}pixelcade/console.csv

if cat /storage/.config/custom_start.sh | grep "^[^#;]" | grep -q 'java'; then  #ignore any comment line, user has the old java pixelweb, we need to comment out this line and replace
    echo "Backing up custom.sh to custom.bak"
    cp /storage/.config/custom_start.sh /storage/.config/custom_start.bak
    echo "Replacing old java pixelweb with new pixelweb"
    sed -i '/java -jar pixelweb.jar/c\cd /storage/roms/pixelcade && ./pixelweb -image "system/emuelec.png" -startup &' /storage/.config/custom_start.sh #comment out the line
fi

if cat /storage/.config/custom_start.sh | grep -q 'pixelweb -image'; then
    echo "Pixelcade was already added to custom_start.sh, skipping..."
else
    echo "Adding Pixelcade Listener auto start to custom_start.sh ..."
    sed -i '/^"before")/a cd /storage/roms/pixelcade && ./pixelweb -image "system/emuelec.png" -startup &' /storage/.config/custom_start.sh  #insert this line after "before"
fi

#TO DO fix this later lastly let's just check for Pixelcade LCD
#cd ${INSTALLPATH}pixelcade
#echo "Checking for Pixelcade LCDs..."
#${INSTALLPATH}bios/jdk/bin/java -jar pixelcadelcdfinder.jar -nogui #check for Pixelcade LCDs

cd /storage/roms/pixelcade && ./pixelweb -image "system/emuelec.png" -startup &

chmod +x /storage/.config/custom_start.sh

echo "Cleaning up..."
if [[ -d ${INSTALLPATH}ptemp ]]; then
    rm -r ${INSTALLPATH}ptemp
fi

if [[ -f ${INSTALLPATH}setup-emuelec.sh ]]; then
    rm ${INSTALLPATH}setup-emuelec.sh
fi

if [[ -f /storage/setup-emuelec.sh ]]; then
    rm /storage/setup-emuelec.sh
fi

echo ""
pixelcade_version="$(cd ${INSTALLPATH}pixelcade && ./pixelweb -version)"
echo "[INFO] $pixelcade_version Installed"
install_succesful=true

sleep 5

echo " "
echo "[INFO] An LED art pack is available at https://pixelcade.org/artpack/"
echo "[INFO] The LED art pack adds additional animated marquees for select games"
echo "[INFO] After purchase, you'll receive a serial code and then install with this command:"
echo "[INFO] cd ~/pixelcade && ./pixelweb --install-artpack <serial code>"

while true; do
    read -p "Is Pixelcade Up and Running? (y/n)" yn
    case $yn in
        [Yy]* ) echo "INSTALLATION COMPLETE , please now reboot and then Pixelcade will be controlled by Batocera" && install_succesful=true; break;;
        [Nn]* ) echo "It may still be ok and try rebooting, you can also refer to https://pixelcade.org/download-pi/ for troubleshooting steps" && exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

if [ "$install_succesful" = true ] ; then
  while true; do
      read -p "Reboot Now? (y/n)" yn
      case $yn in
          [Yy]* ) reboot; break;;
          [Nn]* ) echo "Please reboot when you get a chance" && exit;;
          * ) echo "Please answer yes or no.";;
      esac
  done
fi
