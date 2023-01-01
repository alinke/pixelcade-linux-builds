#!/bin/bash
install_succesful=false
auto_update=false
pizero=false
pi4=false
pi3=false
odroidn2=false
machine_arch=default
version=8  #increment this as the script is updated

cat << "EOF"
       _          _               _
 _ __ (_)_  _____| | ___ __ _  __| | ___
| '_ \| \ \/ / _ \ |/ __/ _` |/ _` |/ _ \
| |_) | |>  <  __/ | (_| (_| | (_| |  __/
| .__/|_/_/\_\___|_|\___\__,_|\__,_|\___|
|_|
EOF

echo "       Pixelcade LED for Batocera : Installer Version $version    "
echo ""
echo "This script will install Pixelcade in your /userdata/system folder"
echo "Plese ensure you have at least 500 MB of free disk space in /userdata/system"
echo "Now connect Pixelcade to a free USB port on your device"
echo "Ensure the toggle switch on the Pixelcade board is pointing towards USB and not BT"
echo "Grab a coffee or tea as this installer will take around 10 minutes depending on your Internet connection speed"

INSTALLPATH="${HOME}/"
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# let's make sure we have Baticera installation
if batocera-info | grep -q 'System'; then
        echo "Batocera Detected"
else
   echo "Sorry, Batocera was not detected, exiting..."
   exit 1
fi

killall java #in the case user has java pixelweb running

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

# The possible platforms are:
#linux_arm64
#linux_386
#linux_amd64
#linux_arm_v6
#linux_arm_v7

#rcade is armv7 userspace and aarch64 kernel space so it shows aarch64 🤣
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
  echo "[ERROR] Your platorm WAS NOT Detected"
  echo "[WARNING] Guessing that you are on aarch64 but be aware Pixelcade may not work"
  machine_arch=amd64
fi

if [[ -d "${INSTALLPATH}pixelcade" ]]; then #create the pixelcade folder if it's not there
   mkdir ${INSTALLPATH}pixelcade
fi

cd ${INSTALLPATH}pixelcade
echo "Installing Pixelcade Software..."
wget https://github.com/alinke/pixelcade-linux/raw/main/builds/linux_${machine_arch}/pixelweb
chmod +x pixelweb
echo "Getting the latest Pixelcade Artwork..."
./pixelweb -install-artwork #install the artwork

if [[ -d ${INSTALLPATH}ptemp ]]; then
    rm -r ${INSTALLPATH}ptemp
fi

#creating a temp dir for the Pixelcade system files
mkdir ${INSTALLPATH}ptemp
cd ${INSTALLPATH}ptemp

#get the Pixelcade system files
wget https://github.com/alinke/pixelcade-linux/archive/refs/heads/main.zip
unzip main.zip

if [[ ! -d ${INSTALLPATH}configs/emulationstation/scripts ]]; then #does the ES scripts folder exist, make it if not
    mkdir ${INSTALLPATH}configs/emulationstation/scripts
fi

cp -a -f ${INSTALLPATH}ptemp/pixelcade-linux-main/v2/system ${INSTALLPATH}pixelcade #system folder, .initial-date will go in here
#pixelcade scripts for emulationstation events
#copy over the custom scripts
echo "${yellow}Installing Pixelcade EmulationStation Scripts...${white}"
cp -r -f ${INSTALLPATH}ptemp/pixelcade-linux-main/batocera/scripts ${INSTALLPATH}configs/emulationstation #note this will overwrite existing scripts
find ${INSTALLPATH}configs/emulationstation/scripts -type f -iname "*.sh" -exec chmod +x {} \; #make all the scripts executble
#hi2txt for high score scrolling
echo "${yellow}Installing hi2txt for High Scores...${white}"
cp -r -f ${INSTALLPATH}ptemp/pixelcade-linux-main/hi2txt ${INSTALLPATH}pixelcade #for high scores

#if [[ $odroidn2 == "true" || "$machine_arch" == "amd64" || "$machine_arch" == "386" ]]; then
#  echo "${yellow}Setting Pixelcade Explicit Port for Odroid N2 or X86...${white}"
#    sed -i "s|port=COM99|port=${PixelcadePort}|" "${INSTALLPATH}pixelcade/settings.ini"
#fi
# need to remove a few lines in console.csv
sed -i '/all,mame/d' ${INSTALLPATH}pixelcade/console.csv
sed -i '/favorites,mame/d' ${INSTALLPATH}pixelcade/console.csv
sed -i '/recent,mame/d' ${INSTALLPATH}pixelcade/console.csv


#cd /userdata/system/pixelcade && /userdata/system/jdk/bin/java -jar pixelweb.jar -b &
# cd ~/pixelcade && ./pixelweb -system-image batocera &

# We need to handle two cases here for custom.sh
# 1. the user had the older java pixelweb so we need to remove that line and replace
# 2. the user already has the new pixelweb so we don't touch it

if [[ ! -f ${INSTALLPATH}custom.sh ]]; then #custom.sh is not there already so let's create one with pixelcade autostart
   if [[ $odroidn2 == "true" || "$machine_arch" == "amd64" || "$machine_arch" == "386" ]]; then  #if we have an Odroid N2+ (am assuming Odroid N2 is same behavior) or x86, Pixelcade will hang on first start so a special startup script is needed to get around this issue which also had to be done for the ALU
        cp ${INSTALLPATH}ptemp/pixelcade-linux-main/batocera/v2/odroidn2/custom.sh ${INSTALLPATH} #with the startup flag
    else
        cp ${INSTALLPATH}ptemp/pixelcade-linux-main/batocera/v2/custom.sh ${INSTALLPATH} #without the startup flag
    fi
else                                                     #custom.sh is already there so let's check if old java pixelweb is there

  if cat ${INSTALLPATH}custom.sh | grep "^[^#;]" | grep -q 'pixelweb.jar -b -a -s'; then  #user has the old java pixelweb with the extra startup bash code lines
      echo "Backing up custom.sh to custom.bak"
      cp custom.sh custom.bak
      echo "Commenting out old java pixelweb version"
      sed -e '/pixelweb.jar -b -a -s/,+12 s/^/#/' -i custom.sh #comment out 12 lines after the match
      sed -e '/userdata/,+2 s/^/#/' -i custom.sh
      echo "Adding pixelweb to startup"
      echo -e "cd ~/pixelcade && ./pixelweb -system-image batocera -startup &\n" >> custom.sh
  fi

  if cat ${INSTALLPATH}custom.sh | grep "^[^#;]" | grep -q 'java'; then  #ignore any comment line, user has the old java pixelweb, we need to comment out this line and replace
      echo "Backing up custom.sh to custom.bak"
      cp custom.sh custom.bak
      echo "Commenting out old java pixelweb version"
      sed -e '/java/ s/^#*/#/' -i custom.sh #comment out the line
      echo "Adding pixelweb to startup"
      echo -e "cd ~/pixelcade && ./pixelweb -system-image batocera &\n" >> custom.sh
  fi

  if cat ${INSTALLPATH}custom.sh | grep -q '-system-image'; then
      echo "Pixelcade was already added to custom.sh, skipping..."
  else
      echo "Adding Pixelcade Listener auto start to your existing custom.sh ..."  #if we got here, then the user already has a custom.sh but there is not pixelcade in there yet
    if [[ $odroidn2 == "true" || "$machine_arch" == "amd64" || "$machine_arch" == "386" ]]; then
      echo "Adding Pixelcade to startup with startup flag in custom.sh"
      echo -e "cd ~/pixelcade && ./pixelweb -system-image batocera -startup &\n" >> custom.sh
    else
      echo "Adding Pixelcade to startup in custom.sh"
      echo -e "cd ~/pixelcade && ./pixelweb -system-image batocera &\n" >> custom.sh
    fi
  fi
fi

chmod +x ${INSTALLPATH}custom.sh

cd ${INSTALLPATH}pixelcade

#echo "Checking for Pixelcade LCDs..."
#${INSTALLPATH}pixelcade/jdk/bin/java -jar pixelcadelcdfinder.jar -nogui #check for Pixelcade LCDs
# TO DO add the Pixelcade LCD check later

#now let's run pixelweb and make sure things are working
source ${INSTALLPATH}custom.sh #run pixelweb
sleep 2
curl "localhost:8080/arcade/stream/mame/1941" #send a test image for the user to see

echo "Cleaning Up..."
cd ${INSTALLPATH}

if [[ -f master.zip ]]; then
    rm master.zip
fi

rm ${SCRIPTPATH}/setup-batocera.sh

if [[ -d ${INSTALLPATH}ptemp ]]; then
    rm -r ${INSTALLPATH}ptemp
fi

echo ""
echo "**** INSTALLATION COMPLETE ****"
install_succesful=true

echo " "
while true; do
    read -p "Is the 1941 Game Logo Displaying on Pixelcade Now? (y/n)" yn
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
