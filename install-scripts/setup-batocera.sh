#!/bin/bash
install_succesful=false
auto_update=false
pizero=false
pi4=false
pi3=false
odroidn2=false
machine_arch=default
version=23  #increment this as the script is updated
batocera_version=default
batocera_recommended_minimum_version=33
batocera_self_contained_version=38
batocera_self_contained=false
batocera_40_plus_version=40
batocera_39_version=39
batocera_40_plus=false
pixelcade_version=default
beta=false
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

echo "       Pixelcade LED for Batocera : Installer Version $version    "
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

INSTALLPATH="${HOME}/"
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

commandLineArg=$1

# let's make sure we have Baticera installation
if batocera-info | grep -q 'System'; then
        echo "Batocera Detected"
else
   echo "Sorry, Batocera was not detected, exiting..."
   exit 1
fi

if [[ "$commandLineArg" == "beta" ]]; then
   echo "[INFO] Installing Beta Version of Pixelcade"
   beta=true
fi

batocera_version="$(batocera-es-swissknife --version | cut -c1-2)" #get the version of Batocera

if [[ $batocera_version -ge $batocera_self_contained_version ]]; then #we couldn't get the Batocera version so just warn the user
  echo "[INFO] Your version of Batocera $batocera_version has Pixelcade support built in"
  batocera_self_contained=true
fi

if [[ $batocera_version -ge $batocera_40_plus_version ]]; then #we need to add the service file and enable in services
    batocera_40_plus=true
    if [[ ! -d ${INSTALLPATH}services ]]; then #does the ES scripts folder exist, make it if not
        mkdir ${INSTALLPATH}services
    fi
    wget -O ${INSTALLPATH}services/pixelcade https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/main/batocera/pixelcade
    chmod +x ${INSTALLPATH}services/pixelcade
    sleep 1
    batocera-services disable dmd_real #disable DMD server in case you user turned it on
    batocera-settings-set dmd.pixelcade.dmdserver 0
    batocera-services enable pixelcade #enable the pixelcade service
    echo "[INFO] Pixelcade added to Batocera services for Batocera V40 and up"
fi

if [[ $batocera_version -eq $batocera_39_version ]]; then #if a user was on V40 and then went back to V39, we have to disable pixelcade service
    batocera-services disable dmd_real #disable DMD server in case you user turned it on
    batocera-settings-set dmd.pixelcade.dmdserver 0
    batocera-services disable pixelcade #disable the pixelcade service
    echo "[INFO] Pixelcade service disabled for Batocera V39"
fi

if [[ $batocera_version == "default" ]]; then #we couldn't get the Batocera version so just warn the user
  echo "[INFO] Could not detect your Batocra version"
  echo "[INFO] Please note that Batocera V33 or higher is required"
  echo "[INFO] for Pixelcade to update while scrolling through games"
  pause
else
  if [[ $batocera_version -lt $batocera_recommended_minimum_version ]]; then
        echo "[INFO] Your Batocera version $batocera_version does not support Pixelcade updates during game scrolling"
        echo "[INFO] On Batocera version $batocera_version, Pixelcade will update only when a game is launched"
        echo "[INFO] Pixelcade updates during scrolling requires Batocera version $batocera_recommended_minimum_version or higher"
        while true; do
            read -p "Would you like to upgrade your Batocera version now (y/n) " yn
            case $yn in
                [Yy]* ) batocera-upgrade; break;;
                [Nn]* ) echo "Continuing Pixelcade Installation on your existing Batocera Version $batocera_version..."; break;;
                * ) echo "Please answer y or n";;
            esac
        done
    else
      echo "[INFO] Your Batocera version $batocera_version supports dynamic Pixelcade updates during front end scrolling"
  fi
fi

echo "Stopping Pixelcade (if running...)"
# let's make sure pixelweb is not already running
killall java #in the case user has java pixelweb running

if [[ $batocera_self_contained == "false" ]]; then #meaning below V38
    if pgrep pixelweb > /dev/null; then #this locks up on V38 
        echo "[INFO] Pixelcade is running, we'll stop it now before proceeding with installation"
        curl 127.0.0.1:8080/quit
    else
        echo "[INFO] Pixelcade was not already running, all good to proceed with installation"
    fi
else #V38 and above kill like this
     pkill -9 pixelweb    
fi

if [[ $batocera_version -ge $batocera_40_plus_version ]]; then 
    pkill -9 pixelweb
fi

#let's see if Pixelcade is there using lsusb
if ! command -v lsusb  &> /dev/null; then
    echo "${red}lsusb command not be found so cannot check if Pixelcade is USB connected${white}"
else
   if lsusb | grep -q '1b4f:0008'; then
      echo "${yellow}Pixelcade LED Marquee Detected${white}"
   elif lsusb | grep -q '2e8a:1050'; then 
      echo "${yellow}[INFO] Pixelcade LED Marquee Detected${white}"
   else  
      echo "${red}[ERROR] Sorry, Pixelcade LED Marquee was not detected, pleasse ensure Pixelcade is USB connected to your Pi and the toggle switch on the Pixelcade board is pointing towards USB, exiting...${white}"
      exit 1
   fi
fi

# The possible platforms are:
# linux_arm64
# linux_386
# linux_amd64
# linux_arm_v6
# linux_arm_v7

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

chmod a+x ${INSTALLPATH}pixelcade/pixelweb

if [[ -d ${INSTALLPATH}ptemp ]]; then
    rm -r ${INSTALLPATH}ptemp
fi

#creating a temp dir for the Pixelcade common system files & scripts
mkdir ${INSTALLPATH}ptemp
cd ${INSTALLPATH}ptemp

#this is a hack for now as the native pixelweb artwork instlaller does not always work on non arm64
#if [[ $machine_arch != "arm64" ]]; then
    #get the Pixelcade artwork
#    wget -O ${INSTALLPATH}ptemp/master.zip https://github.com/alinke/pixelcade/archive/refs/heads/master.zip
#    unzip master.zip
#    cd ~/ptemp/pixelcade-master
#    cp -r -v * ${INSTALLPATH}pixelcade
#    cp -r -v * ~/pixelcade
#    cd ${INSTALLPATH}ptemp
#else 
   # chmod a+x ${INSTALLPATH}pixelcade/pixelweb
   # cd ${INSTALLPATH}pixelcade && ./pixelweb -install-artwork #install the artwork

   # if [[ $? == 2 ]]; then #this means artwork is already installed so let's check for updates and get if so
   #     echo "Checking for new Pixelcade artwork..."
   #     cd ${INSTALLPATH}pixelcade && ./pixelweb -update-artwork
   # fi
#fi

#get the Pixelcade system files
wget -O ${INSTALLPATH}ptemp/main.zip https://github.com/alinke/pixelcade-linux/archive/refs/heads/main.zip
unzip main.zip

if [[ ! -d ${INSTALLPATH}configs/emulationstation/scripts ]]; then #does the ES scripts folder exist, make it if not
    mkdir ${INSTALLPATH}configs/emulationstation/scripts
fi

#pixelcade scripts for emulationstation events
#copy over the custom scripts
echo "${yellow}Removing Legacy Pixelcade Scripts called 01-pixelcade.sh (if they exist)...${white}"
find ${INSTALLPATH}configs/emulationstation/scripts -type f -name "01-pixelcade.sh" -ls
find ${INSTALLPATH}configs/emulationstation/scripts -type f -name "01-pixelcade.sh" -exec rm {} \;
echo "${yellow}Installing Pixelcade EmulationStation Scripts for Batocera...${white}"
#copy over the custom scripts
cp -r -f ${INSTALLPATH}ptemp/pixelcade-linux-main/batocera/scripts ${INSTALLPATH}configs/emulationstation #note this will overwrite existing scripts
find ${INSTALLPATH}configs/emulationstation/scripts -type f -iname "*.sh" -exec chmod +x {} \; #make all the scripts executble
#hi2txt for high score scrolling
echo "${yellow}Installing hi2txt for High Scores...${white}" #note this requires java
cp -r -f ${INSTALLPATH}ptemp/pixelcade-linux-main/hi2txt ${INSTALLPATH}pixelcade #for high scores

# We need to handle two cases here for custom.sh
# 1. the user had the older java pixelweb so we need to remove that line and replace
# 2. the user already has the new pixelweb so we don't touch it

if [[ $batocera_self_contained == "false" ]]; then #we need to add to modify custom.sh
    cd ${INSTALLPATH}
    if [[ ! -f ${INSTALLPATH}custom.sh ]]; then #custom.sh is not there already so let's create one with pixelcade autostart
        wget -O ${INSTALLPATH}custom.sh https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/main/batocera/custom.sh #with startup flag
    else    #custom.sh is already there so let's check if old java pixelweb is there

      if cat ${INSTALLPATH}custom.sh | grep "^[^#;]" | grep -q 'pixelweb.jar -b -a -s'; then  #user has the old java pixelweb with the extra startup bash code lines
          echo "Backing up custom.sh to custom.bak"
          cp custom.sh custom.bak
          echo "Commenting out old java pixelweb version with extra startup lines"
          sed -e '/pixelweb.jar -b -a -s/,+12 s/^/#/' -i custom.sh #comment out 12 lines after the match
          sed -e '/userdata/,+2 s/^/#/' -i custom.sh
          echo "Adding pixelweb to startup"
          echo -e "cd /userdata/system/pixelcade && ./pixelweb -image "system/batocera.png" -startup &\n" >> custom.sh
      fi

      if cat ${INSTALLPATH}custom.sh | grep "^[^#;]" | grep -q 'java'; then  #ignore any comment line, user has the old java pixelweb, we need to comment out this line and replace
          echo "Backing up custom.sh to custom.bak"
          cp custom.sh custom.bak
          echo "Commenting out old java pixelweb version"
          sed -e '/java/ s/^#*/#/' -i custom.sh #comment out the line
          echo "Adding pixelweb to startup"
          echo -e "cd /userdata/system/pixelcade && ./pixelweb -image "system/batocera.png" -startup &\n" >> custom.sh #we'll just need to assume startup flag is needed now even though  may not have been in the past
      fi

      if cat ${INSTALLPATH}custom.sh | grep "^[^#;]" | grep -q 'pixelweb -image'; then #this means the startup text we want is already there
          echo "Pixelcade already added to custom.sh, skipping..."
      else
        if cat ${INSTALLPATH}custom.sh | grep -q 'start)'; then #this means we have a custom.sh with a start)
            echo "custom.sh start is here..."
            sed -i "/start)/a\\\tcd ${INSTALLPATH}pixelcade && ./pixelweb -image "system/batocera.png" -startup &" ${INSTALLPATH}custom.sh #insert pixelweb after start)  , note \\\t is a tab
        else
            echo "Adding Pixelcade Listener auto start to your existing custom.sh for non-vanilla Batocera image..."  #if we got here, then the user already has a custom.sh but there is not pixelcade in there yet
            echo "cd ${INSTALLPATH}pixelcade && ./pixelweb -image "system/batocera.png" -startup &" >> ${INSTALLPATH}custom.sh #insert pixelweb after start)  , note \\\t is a tab
        fi
      fi
    fi
    chmod +x ${INSTALLPATH}custom.sh
    # because we are not on self contained, pixelweb won't be running so let's start it now
    cd ${INSTALLPATH}pixelcade && ./pixelweb -image "system/batocera.png" -startup & #note we dont' want to start pixelweb if we are on V38 or above as it's already running
else #we have self contained V38 or above so let's make sure custom.sh has pixelweb removed
    if cat ${INSTALLPATH}custom.sh | grep "^[^#;]" | grep -q 'pixelcade'; then  #ignore any comment line, user has the old java pixelweb, we need to comment out this line and replace
        echo "Backing up custom.sh to custom.bak"
        cp custom.sh custom.bak
        echo "Commenting out pixelweb in custom.sh as we no longer need it here"
        sed -e '/pixelcade/ s/^#*/#/' -i ${INSTALLPATH}custom.sh #comment out the line
    fi
fi
#echo "Checking for Pixelcade LCDs..."
#${INSTALLPATH}pixelcade/jdk/bin/java -jar pixelcadelcdfinder.jar -nogui #check for Pixelcade LCDs
# TO DO add the Pixelcade LCD check later

chmod a+x ${INSTALLPATH}pixelcade/pixelweb
cd ${INSTALLPATH}pixelcade && ./pixelweb -install-artwork #install the artwork

if [[ $? == 2 ]]; then #this means artwork is already installed so let's check for updates and get if so
    echo "Checking for new Pixelcade artwork..."
    cd ${INSTALLPATH}pixelcade && ./pixelweb -update-artwork
fi

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
pixelcade_version="$(cd ${INSTALLPATH}pixelcade && ./pixelweb -version)"
echo "[INFO] $pixelcade_version Installed"

if [[ $batocera_40_plus == "true" ]]; then 
  echo "[INFO] Starting Pixelcade..."
  batocera-services start pixelcade
else 
  echo "[INFO] Please now Reboot"
fi

echo " "
echo "[INFO] An LED art pack is available at https://pixelcade.org/artpack/"
echo "[INFO] The LED art pack adds additional animated marquees for select games"
echo "[INFO] After purchase, you'll receive a serial code and then install with this command:"
echo "[INFO] cd ~/pixelcade && ./pixelweb --install-artpack <serial code>"