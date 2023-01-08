#!/bin/bash
stretch_os=false
buster_os=false
ubuntu_os=false
retropie=false
pizero=false
pi4=false
java_installed=false
install_succesful=false
auto_update=false
attractmode=false
black=`tput setaf 0`
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
blue=`tput setaf 4`
magenta=`tput setaf 5`
white=`tput setaf 7`
reset=`tput sgr0`
machine_arch=default
version=10  #increment this as the script is updated
#echo "${red}red text ${green}green text${reset}"

cat << "EOF"
       _          _               _
 _ __ (_)_  _____| | ___ __ _  __| | ___
| '_ \| \ \/ / _ \ |/ __/ _` |/ _` |/ _ \
| |_) | |>  <  __/ | (_| (_| | (_| |  __/
| .__/|_/_/\_\___|_|\___\__,_|\__,_|\___|
|_|
EOF

#check Space
#check if user_launch is there, if so then add runpixelcade.sh there,if not then tell user to upgrade mister first
#check if mister example is there or mister.ini and modify
# MiSTer_example.ini
#_user-startup.sh

echo "${magenta}       Pixelcade for MiSTer : Installer Version $version    ${white}"
echo ""
echo "Now connect Pixelcade to a free USB port on your MiSTer"
echo "Ensure the toggle switch on the Pixelcade board is pointing towards USB and not BT"
echo "Grab some coffee or tea, this installer will take around 30 minutes to complete"

INSTALLPATH="/media/fat/"

function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

echo "Stopping Pixelcade (if running...)"
# let's make sure pixelweb is not already running
killall java #in the case user has java pixelweb running
curl localhost:8080/quit

#do we have enough disk space?
cd /media/fat
FREE=`df -k --output=avail "$PWD" | tail -n1`   # df -k not df -h
if [[ $FREE -lt 1048576 ]]; then               # 1G = 10*1024*1024k
  echo "${yellow}Sorry, you'll need at least 1 GB of free disk space on /media/fat${white}"
  exit 1
fi

#do we have an upgraded MiSTer?
if [ -f "/media/fat/linux/_user-startup.sh" ] || [ -f "/media/fat/linux/user-startup.sh" ]; then
      echo "${yellow}Updated MiSTer Detected, Good${white}"
else
      echo "${red}Pixelcade is not compatible with this version of MiSTer as no /media/fat/linux/_user-startup.sh was found. Please upgrade to the latest MiSTer first${white}"
      exit 1
fi

#is Pixelcade already installed?
if [[ -d "/media/fat/pixelcade" ]]; then
    echo "${yellow}Pixelcade is already installed, updating to the latest including artwork${white}"
fi

# let's detect if Pixelcade is connected
if ls /dev/ttyACM0 | grep -q '/dev/ttyACM0'; then
   echo "${yellow}Pixelcade LED Marquee Detected on /dev/ttyACM0${white}"
elif ls /dev/ttyACM1 | grep -q '/dev/ttyACM1'; then
  echo "${yellow}Pixelcade LED Marquee Detected on /dev/ttyACM1${white}"
else
   echo "${red}Pixelcade LED Marquee was not detected, pleasse ensure Pixelcade is USB connected to your Pi and the toggle switch on the Pixelcade board is pointing towards USB"
fi

# TO DO ask user if they want to install on SD card or USB
if [[ -d "/media/fat" ]]; then
  echo "${yellow}MiSTer SD Card Found${white}"
else
   echo "${yellow}MiSTer SD Card Not Found, Sorry setup cannot continue..."
   exit 1
fi

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

cd /media/fat/

if [[ ! -d "${INSTALLPATH}pixelcade" ]]; then #create the pixelcade folder if it's not there
   mkdir ${INSTALLPATH}pixelcade
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

echo "${yellow}Downloading Additional Files Needed for Pixelcade MiSTer...${white}"
cd /media/fat/pixelcade
wget https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/main/mister/ip.txt
wget https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/main/mister/pixelcadeLink.sh
wget https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/main/mister/runpixelcade.sh
chmod +x /media/fat/pixelcade/runpixelcade.sh

echo "${yellow}Adding Pixelcade MiSTer to Startup...${white}"

if [[ ! -f "/media/fat/linux/user-startup.sh" ]]; then #is the user startup is NOT there
    if [[ -f "/media/fat/linux/_user-startup.sh" ]]; then #user the default user-startup.sh that comes with MiSTer
        mv /media/fat/linux/_user-startup.sh /media/fat/linux/user-startup.sh
        cd /media/fat/linux
        grep -qxF 'cd /media/fat/pixelcade && ./runpixelcade.sh' user-startup.sh || echo 'cd /media/fat/pixelcade && ./runpixelcade.sh' >> user-startup.sh
    else #the defaut is not there so let's make a new one from scratch
        echo -e "echo ***" \$\1 "***\n\ncd /media/fat/pixelcade && ./runpixelcade.sh" >> /media/fat/linux/user-startup.sh
    fi
else
    if cat /media/fat/linux/user-startup.sh | grep -q 'runpixelcade'; then
        echo "Pixelcade was already added to user-startup.sh, skipping..."
    else
        echo "Adding Pixelcade Listener auto start to user-startup.sh ..."
        sed -i -e '$acd /media/fat/pixelcade && ./runpixelcade.sh' /media/fat/linux/user-startup.sh
    fi
fi
chmod +x /media/fat/linux/user-startup.sh


echo "${yellow}Modifying MiSTer.ini to turn on current game logging which is needed for Pixelcade...${white}"
cd /media/fat
if [[ -f "/media/fat/MiSTer.ini" ]]; then
      echo "${yellow}Updating your existing MiSTer.ini${white}"
      sed -i '/^\[MiSTer\]/a\log_file_entry=1' MiSTer.ini
elif [[ -f "/media/fat/MiSTer_example.ini" ]]; then
      echo "${yellow}Adding MiSTer.ini${white}"
      mv /media/fat/MiSTer_example.ini /media/fat/MiSTer.ini
      sed -i '/^\[MiSTer\]/a\log_file_entry=1' MiSTer.ini
      exit 1
else  #then worst case let's add a new MiSTer.ini
      echo "${yellow}Getting a vanilla MiSTer.ini${white}"
      cd /media/fat && wget https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/main/mister/MiSTer.ini
fi

echo ""
pixelcade_version="$(cd ${INSTALLPATH}pixelcade && ./pixelweb -version)"
echo "[INFO] $pixelcade_version Installed"
install_succesful=true

echo "Cleaning up..."
if [[ -f ${INSTALLPATH}setup-mister.sh ]]; then
    rm ${INSTALLPATH}setup-mister.sh.sh
fi

if [[ -f /storage/setup-mister.sh.sh ]]; then
    rm /storage/setup-mister.sh.sh
fi

#let's run Pixelcade now
/media/fat/linux/user-startup.sh
sleep 3

while true; do
    read -p "Is Pixelcade Up and Running? (y/n)" yn
    case $yn in
        [Yy]* ) echo "INSTALLATION COMPLETE , please now reboot and then Pixelcade will be controlled by MiSTer" && install_succesful=true; break;;
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

echo "${yellow}Installation Complete, Please Reboot your MiSTer...${white}"
while true; do
    read -p "${magenta}Reboot Now? (y/n)${white}" yn
    case $yn in
        [Yy]* ) sudo reboot; break;;
        [Nn]* ) echo "${yellow}Please reboot when you get a chance" && exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
