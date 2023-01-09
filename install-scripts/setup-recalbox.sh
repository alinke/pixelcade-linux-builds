#!/bin/bash
install_succesful=false
auto_update=false
pizero=false
pi4=false
pi3=false
odroidn2=false
machine_arch=default
version=10  #increment this as the script is updated
batocera_version=default
batocera_recommended_minimum_version=33
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

echo "       Pixelcade LED for RecalBox : Installer Version $version    "
echo ""
echo "This script will install the Pixelcade LED software in $HOME/pixelcade"
echo "Plese ensure you have at least 800 MB of free disk space in $HOME"
echo "Now connect Pixelcade to a free USB port on your device"
echo "Ensure the toggle switch on the Pixelcade board is pointing towards USB and not BT"
echo "Grab a coffee or tea as this installer will take around 10 minutes depending on your Internet connection speed"

function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

INSTALLPATH="/recalbox/share/"

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

echo "Stopping Pixelcade (if running...)"
# let's make sure pixelweb is not already running
killall java #in the case user has java pixelweb running
curl localhost:8080/quit

# let's detect if Pixelcade is USB connected, could be 0 or 1 so we need to check both
if ls /dev/ttyACM0 | grep -q '/dev/ttyACM0'; then
   echo "Pixelcade LED Marquee Detected on ttyACM0"
else
    if ls /dev/ttyACM1 | grep -q '/dev/ttyACM1'; then
        echo "Pixelcade LED Marquee Detected on ttyACM1"
    else
       echo "Sorry, Pixelcade LED Marquee was not detected.${NEWLINE}Please ensure Pixelcade is USB connected to your Pi and the toggle switch on the Pixelcade board is pointing towards USB, exiting..."
       exit 1
    fi
fi

# The possible platforms are:
# linux_arm64
# linux_386
# linux_amd64
# linux_arm_v6
# linux_arm_v7

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
  echo "[ERROR] Your device platform WAS NOT Detected"
  echo "[WARNING] Guessing that you are on aarch64 but be aware Pixelcade may not work"
  machine_arch=arm64
fi

if [[ ! -d "${INSTALLPATH}pixelcade" ]]; then #create the pixelcade folder if it's not there
   mkdir ${INSTALLPATH}pixelcade
fi

#java needed for high scores, hi2txt
cd ${INSTALLPATH}pixelcade
JDKDEST="${INSTALLPATH}pixelcade/jdk"

if [[ ! -d $JDKDEST ]]; then #does Java exist already
    if [[ $machine_arch == "arm64" ]]; then
          echo "${yellow}Installing Java JRE 11 64-Bit for aarch64...${white}" #these will unzip and create the jdk folder
          curl -kLO https://github.com/alinke/pixelcade-jre/raw/main/jdk-aarch64.zip #this is a 64-bit small JRE , same one used on the ALU
          unzip jdk-aarch64.zip
          chmod +x ${INSTALLPATH}pixelcade/jdk/bin/java
    elif [ $machine_arch == "arm_v7" ]; then
          echo "${yellow}Installing Java JRE 11 32-Bit for aarch32...${white}"
          curl -kLO https://github.com/alinke/pixelcade-jre/raw/main/jdk-aarch32.zip
          unzip jdk-aarch32.zip
          chmod +x ${INSTALLPATH}pixelcade/jdk/bin/java
    elif [ $machine_arch == "386" ]; then #pi zero is arm6 and cannot run the normal java :-( so have to get this special one
          echo "${yellow}Installing Java JRE 11 32-Bit for X86...${white}"
          curl -kLO https://github.com/alinke/pixelcade-jre/raw/main/jdk-x86-32.zip
          unzip jdk-x86-32.zip
          chmod +x ${INSTALLPATH}pixelcade/jdk/bin/java
    elif [ $machine_arch == "amd64" ]; then #pi zero is arm6 and cannot run the normal java :-( so have to get this special one
          echo "${yellow}Installing Java JRE 11 64-Bit for X86...${white}"
          curl -kLO https://github.com/alinke/pixelcade-jre/raw/main/jdk-x86-64.zip
          unzip jdk-x86-64.zip
          chmod +x ${INSTALLPATH}pixelcade/jdk/bin/java
    else
      echo "${red}Sorry, do not have a Java JDK for your platform.${NEWLINE}You'll need to install a Java JDK or JRE manually under ${INSTALLPATH}pixelcade/jdk/bin/java${NEWLINE}Note Java is only needed for high score functionality so you can also skip it"
    fi
fi

if [[ -f master.zip ]]; then
    rm master.zip
fi

cd ${INSTALLPATH}pixelcade
echo "Installing Pixelcade Software..."
wget -O ${INSTALLPATH}pixelcade/pixelweb https://github.com/alinke/pixelcade-linux-builds/raw/main/linux_${machine_arch}/pixelweb
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
wget -O ${INSTALLPATH}ptemp/main.zip https://github.com/alinke/pixelcade-linux/archive/refs/heads/main.zip
unzip main.zip

if [[ ! -d ${INSTALLPATH}configs/emulationstation/scripts ]]; then #does the ES scripts folder exist, make it if not
    mkdir ${INSTALLPATH}configs/emulationstation/scripts
fi

#pixelcade scripts for emulationstation events
#copy over the custom scripts
echo "${yellow}Installing Pixelcade EmulationStation Scripts...${white}"
cp -r -f ${INSTALLPATH}ptemp/pixelcade-linux-main/batocera/scripts ${INSTALLPATH}configs/emulationstation #note this will overwrite existing scripts
find ${INSTALLPATH}configs/emulationstation/scripts -type f -iname "*.sh" -exec chmod +x {} \; #make all the scripts executble
#hi2txt for high score scrolling
echo "${yellow}Installing hi2txt for High Scores...${white}" #note this requires java
cp -r -f ${INSTALLPATH}ptemp/pixelcade-linux-main/hi2txt ${INSTALLPATH}pixelcade #for high scores

# need to remove a few lines in console.csv
sed -i '/all,mame/d' ${INSTALLPATH}pixelcade/console.csv
sed -i '/favorites,mame/d' ${INSTALLPATH}pixelcade/console.csv
sed -i '/recent,mame/d' ${INSTALLPATH}pixelcade/console.csv

# We need to handle two cases here for custom.sh
# 1. the user had the older java pixelweb so we need to remove that line and replace
# 2. the user already has the new pixelweb so we don't touch it

STARTUPPATH="/etc/init.d/"
cd ${STARTUPPATH}

mount -o remount,rw /  #have to do this to get write access to this file

if [[ ! -f ${STARTUPPATH}custom.sh ]]; then #custom.sh is not there already so let's create one with pixelcade autostart
     wget -O ${STARTUPPATH}custom.sh https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/recalbox/batocera/custom.sh #with startup flag
else    #custom.sh is already there so let's check if old java pixelweb is there
  if cat ${STARTUPPATH}custom.sh | grep "^[^#;]" | grep -q 'java'; then  #ignore any comment line, user has the old java pixelweb, we need to comment out this line and replace
      echo "Backing up custom.sh to custom.bak"
      cp custom.sh custom.bak
      echo "Commenting out old java pixelweb version"
      sed -e '/java/ s/^#*/#/' -i custom.sh #comment out the line
      echo "Adding pixelweb to startup"
      echo -e "cd ${INSTALLPATH}pixelcade && ./pixelweb -image "system/recalbox.png" -startup &\n" >> custom.sh #we'll just need to assume startup flag is needed now even though  may not have been in the past
  fi
  if cat ${STARTUPPATH}custom.sh | grep -q 'pixelweb -image'; then #this means the startup text we want is already there
      echo "Pixelcade already added to custom.sh, skipping..."
  else
      echo "Adding Pixelcade Listener auto start to your existing custom.sh ..."  #if we got here, then the user already has a custom.sh but there is not pixelcade in there yet
      sed -i "/^"before")/a cd ${INSTALLPATH}pixelcade && ./pixelweb -image "system/recalbox.png" -startup &" ${STARTUPPATH}custom.sh  #insert this line after "before"
  fi
fi

chmod +x ${STARTUPPATH}custom.sh
cd ${INSTALLPATH}pixelcade

#echo "Checking for Pixelcade LCDs..."
#${INSTALLPATH}pixelcade/jdk/bin/java -jar pixelcadelcdfinder.jar -nogui #check for Pixelcade LCDs
# TO DO add the Pixelcade LCD check later

#now let's run pixelweb and let the user know things are working
cd ${INSTALLPATH}pixelcade && ./pixelweb -image "system/recalbox.png" -startup &

echo "Cleaning Up..."
cd ${INSTALLPATH}

if [[ -f master.zip ]]; then
    rm master.zip
fi

rm ${SCRIPTPATH}/setup-recalbox.sh

if [[ -d ${INSTALLPATH}ptemp ]]; then
    rm -r ${INSTALLPATH}ptemp
fi

echo ""
pixelcade_version="$(cd ${INSTALLPATH}pixelcade && ./pixelweb -version)"
echo "[INFO] $pixelcade_version Installed"
install_succesful=true

echo "Pausing for 5 seconds..."
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
