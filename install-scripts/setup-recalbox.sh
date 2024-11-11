#!/bin/bash
install_succesful=false
auto_update=false
pizero=false
pi4=false
pi3=false
odroidn2=false
machine_arch=default
version=12  #increment this as the script is updated
pixelcade_version=default
NEWLINE=$'\n'

# Here's what this script does:

# Downloads pixelweb to /etc/init.d/pixelcade
# Adds a startup script (S99MyScript.py) that runs pixelweb in the background at startup
# adds java to /etc/init.d/pixelcade/jdk/java #only need this for high scores
# installs pixlecade artwork in /recalbox/share/pixelcade-art
# downloads Pixelcade ES scripts to /recalbox/share/userscripts



cat << "EOF"
       _          _               _
 _ __ (_)_  _____| | ___ __ _  __| | ___
| '_ \| \ \/ / _ \ |/ __/ _` |/ _` |/ _ \
| |_) | |>  <  __/ | (_| (_| | (_| |  __/
| .__/|_/_/\_\___|_|\___\__,_|\__,_|\___|
|_|
EOF

echo "       Pixelcade LED Marquee for RecalBox : Installer Version $version    "
echo ""
echo "This script will install the Pixelcade LED software in /recalbox/share/pixelcade-art"
echo "Plese ensure you have at least 800 MB of free disk space in /recalbox/share/"
echo "You'll need to have Pixelcade plugged into a free USB port on your RecalBox device"
echo "Ensure the toggle switch on the Pixelcade board is pointing towards USB and not BT"
echo "Grab a coffee or tea as this installer will take around 20-30 minutes depending on your Internet connection speed"

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

#mount -o remount,rw /  #have to do this to get write access, removing though as it's needed in the main command now

INSTALLPATH="/etc/init.d/"
ARTPATH="/recalbox/share/pixelcade-art/"
ESSCRIPTS="/recalbox/share/userscripts/"


echo "Stopping Pixelcade (if running...)"
# let's make sure pixelweb is not already running
killall java #in the case user has java pixelweb running
curl localhost:7070/quit

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

if [[ ! -d "${ARTPATH}" ]]; then #create the pixelcade-art folder if it's not there
   mkdir ${ARTPATH}
fi

#java needed for high scores, hi2txt
cd ${INSTALLPATH}pixelcade
JDKDEST="${INSTALLPATH}pixelcade/jdk"

if [[ ! -d $JDKDEST ]]; then #does Java exist already
    if [[ $machine_arch == "arm64" ]]; then
          echo "${yellow}Installing Compact Java JRE 11 64-Bit for aarch64...${white}" #these will unzip and create the jdk folder
          curl -kLO https://github.com/alinke/pixelcade-jre/raw/main/jdk-aarch64.zip #this is a 64-bit small JRE , same one used on the ALU
          unzip jdk-aarch64.zip
          chmod +x ${INSTALLPATH}pixelcade/jdk/bin/java
          rm ${INSTALLPATH}pixelcade/jdk-aarch64.zip
    elif [ $machine_arch == "arm_v7" ]; then
          echo "${yellow}Installing Compact Java JRE 11 32-Bit for aarch32...${white}"
          curl -kLO https://github.com/alinke/pixelcade-jre/raw/main/jdk-aarch32.zip
          unzip jdk-aarch32.zip
          chmod +x ${INSTALLPATH}pixelcade/jdk/bin/java
          rm ${INSTALLPATH}pixelcade/jdk-aarch32.zip
    elif [ $machine_arch == "386" ]; then #pi zero is arm6 and cannot run the normal java :-( so have to get this special one
          echo "${yellow}Installing Compact Java JRE 11 32-Bit for X86...${white}"
          curl -kLO https://github.com/alinke/pixelcade-jre/raw/main/jdk-x86-32.zip
          unzip jdk-x86-32.zip
          chmod +x ${INSTALLPATH}pixelcade/jdk/bin/java
          rm ${INSTALLPATH}pixelcade/jdk-x86-32.zip
    elif [ $machine_arch == "amd64" ]; then #pi zero is arm6 and cannot run the normal java :-( so have to get this special one
          echo "${yellow}Installing Compact Java JRE 11 64-Bit for X86...${white}"
          curl -kLO https://github.com/alinke/pixelcade-jre/raw/main/jdk-x86-64.zip
          unzip jdk-x86-64.zip
          chmod +x ${INSTALLPATH}pixelcade/jdk/bin/java
          rm ${INSTALLPATH}pixelcade/jdk-x86-64.zip
    else
      echo "${red}Sorry, do not have a Java JDK for your platform.${NEWLINE}You'll need to install a Java JDK or JRE manually under ${INSTALLPATH}pixelcade/jdk/bin/java${NEWLINE}Note Java is only needed for high score functionality so you can also skip it"
    fi
fi

if [[ -f master.zip ]]; then
    rm master.zip
fi

cd ${INSTALLPATH}pixelcade
echo "Installing Pixelcade Software..."

if [[ $beta == "true" ]]; then
    url="https://github.com/alinke/pixelcade-linux-builds/raw/main/beta/linux_${machine_arch}/pixelweb"
    if wget --spider "$url" 2>/dev/null; then
        echo "[BETA] A Pixelcade LED beta version is available so let's get it..."
        wget -O "${INSTALLPATH}pixelcade/pixelweb" "$url"
    else
        echo "There is no beta available at this time so we'll go with the production version"
        prod_url="https://github.com/alinke/pixelcade-linux-builds/raw/main/linux_${machine_arch}/pixelweb"
        wget -O "${INSTALLPATH}pixelcade/pixelweb" "$prod_url"
    fi
else
    prod_url="https://github.com/alinke/pixelcade-linux-builds/raw/main/linux_${machine_arch}/pixelweb"
    wget -O "${INSTALLPATH}pixelcade/pixelweb" "$prod_url"
fi

#wget -O ${INSTALLPATH}pixelcade/pixelweb https://github.com/alinke/pixelcade-linux-builds/raw/main/linux_${machine_arch}/pixelweb
chmod +x pixelweb

./pixelweb -p ${ARTPATH} -install-artwork #install the artwork here and set this as pixelcade root

if [[ $? == 2 ]]; then #this means artwork is already installed so let's check for updates and get if so
  echo "Checking for new Pixelcade artwork..."
  cd ${INSTALLPATH}pixelcade && ./pixelweb -p ${ARTPATH} -update-artwork
fi

if [[ ! -d /recalbox/share/userscripts ]]; then #does the ES scripts folder exist, make it if not
    mkdir /recalbox/share/userscripts
fi

#pixelcade scripts for emulationstation events
#copy over the custom scripts
echo "${yellow}Installing Pixelcade EmulationStation Scripts...${white}"
wget -O ${ESSCRIPTS}systembrowse[systembrowsing].sh https://raw.githubusercontent.com/alinke/pixelcade-linux/main/recalbox/scripts/systembrowse%5Bsystembrowsing%5D.sh
wget -O ${ESSCRIPTS}gamescroll[gamelistbrowsing].sh https://raw.githubusercontent.com/alinke/pixelcade-linux/main/recalbox/scripts/gamescroll%5Bgamelistbrowsing%5D.sh
wget -O ${ESSCRIPTS}gamelaunch[rungame].sh https://raw.githubusercontent.com/alinke/pixelcade-linux/main/recalbox/scripts/gamelaunch%5Brungame%5D.sh
wget -O ${ESSCRIPTS}esquit[start].sh https://raw.githubusercontent.com/alinke/pixelcade-linux/main/recalbox/scripts/esquit%5Bstart%5D.sh
find ${ESSCRIPTS} -type f -iname "*.sh" -exec chmod +x {} \; #make all the scripts executble but this may not actually be necessary with RecalBox ?
#hi2txt for high score scrolling
echo "${yellow}Installing hi2txt for High Scores...${white}" #note this requires java
if [[ ! -d ${INSTALLPATH}pixelcade/hi2txt ]]; then
    mkdir ${INSTALLPATH}pixelcade/hi2txt
fi
wget -O ${INSTALLPATH}pixelcade/hi2txt/hi2txt.jar https://github.com/alinke/pixelcade-linux/raw/main/hi2txt/hi2txt.jar
wget -O ${INSTALLPATH}pixelcade/hi2txt/hi2txt.zip https://github.com/alinke/pixelcade-linux/raw/main/hi2txt/hi2txt.zip

# need to remove a few lines in console.csv
sed -i '/all,mame/d' ${ARTPATH}console.csv
sed -i '/favorites,mame/d' ${ARTPATH}console.csv
sed -i '/recent,mame/d' ${ARTPATH}console.csv

# We need to handle two cases here for S99MyScript.py
# 1. the user had the older java pixelweb so we need to remove that line and replace
# 2. the user already has the new pixelweb so we don't touch it

cd ${INSTALLPATH}

if [[ ! -f ${INSTALLPATH}S99MyScript.py ]]; then #S99MyScript.py is not there already so let's create one with pixelcade autostart
     wget -O ${INSTALLPATH}S99MyScript.py https://github.com/alinke/pixelcade-linux-builds/raw/main/recalbox/S99MyScript.py
else    #S99MyScript.py is already there so let's check if old java pixelweb is there
  if cat ${INSTALLPATH}S99MyScript.py | grep "^[^#;]" | grep -q 'java'; then  #ignore any comment line, user has the old java pixelweb, we need to comment out this line and replace
      echo "Backing up S99MyScript.py to S99MyScript.bak"
      cp S99MyScript.py S99MyScript.bak
      echo "Commenting out old java pixelweb version"
      sed -e '/java/ s/^#*/#/' -i S99MyScript.py #comment out the line
      echo "Adding pixelweb to startup"
      echo -e "cd ${INSTALLPATH}pixelcade && ./pixelweb -p ${ARTPATH} -port 7070 -image "system/recalbox.png" -startup &\n" >> ${INSTALLPATH}S99MyScript.py #we'll just need to assume startup flag is needed now even though  may not have been in the past
  fi
  if cat ${INSTALLPATH}S99MyScript.py | grep -q 'pixelweb -image'; then #this means the startup text we want is already there
      echo "Pixelcade already added to S99MyScript.py, skipping..."
  else
      echo "Adding Pixelcade Listener auto start to your existing S99MyScript.py ..."  #if we got here, then the user already has a S99MyScript.py but there is not pixelcade in there yet
      sed -i "/^"before")/a cd ${INSTALLPATH}pixelcade && ./pixelweb -p ${ARTPATH} -port 7070 -image "system/recalbox.png" -startup &" ${INSTALLPATH}S99MyScript.py  #insert this line after "before" , note 7070 is needed as something else already using 8080
  fi
fi

chmod +x ${INSTALLPATH}S99MyScript.py
cd ${INSTALLPATH}pixelcade

#now let's run pixelweb and let the user know things are working
cd ${INSTALLPATH}pixelcade && ./pixelweb -p ${ARTPATH} -port 7070 -image "system/recalbox.png" -startup &

echo "Cleaning Up..."
rm ${SCRIPTPATH}/setup-recalbox.sh

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
echo "[INFO] cd /etc/init.d/pixelcade && ./pixelweb -p ${ARTPATH} --install-artpack <serial code>"

# mount -o remount,ro / #put back into read only


while true; do
    read -p "Is Pixelcade Up and Running? (y/n)" yn
    case $yn in
        [Yy]* ) echo "INSTALLATION COMPLETE , please now reboot and then Pixelcade will be controlled by RecalBox" && install_succesful=true; break;;
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
