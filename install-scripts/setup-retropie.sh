#!/bin/bash
stretch_os=false
buster_os=false
ubuntu_os=false
jessie_os=false
retropie=false
pizero=false
pi4=false
pi3=false
java_installed=false
install_succesful=false
PIXELCADE_PRESENT=false #did we do an upgrade and pixelcade was already there
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
upgrade_artwork=false
upgrade_software=false
version=10  #increment this as the script is updated

cat << "EOF"
       _          _               _
 _ __ (_)_  _____| | ___ __ _  __| | ___
| '_ \| \ \/ / _ \ |/ __/ _` |/ _` |/ _ \
| |_) | |>  <  __/ | (_| (_| | (_| |  __/
| .__/|_/_/\_\___|_|\___\__,_|\__,_|\___|
|_|
EOF

echo "       Pixelcade LED for RetroPie : Installer Version $version    "
echo ""
echo "This script will install Pixelcade in your /home/pi folder"
echo "${red}IMPORTANT:${white} This script will work on Pi 3 and Pi 4 devices"
echo "Plese ensure you have at least 800 MB of free disk space in /home/pi"
echo "Now connect Pixelcade to a free USB port on your device"
echo "Ensure the toggle switch on the Pixelcade board is pointing towards USB and not BT"
echo "Grab a coffee or tea as this installer will take around 15 minutes"

INSTALLPATH="/home/pi/"

# let's see what installation we have
if lsb_release -a | grep -q 'stretch'; then
        echo "${yellow}Linux Stretch Detected${white}"
        stretch_os=true
        echo "Installing curl..."
        sudo apt install -y curl
elif cat /etc/os-release | grep -q 'stretch'; then
       echo "${yellow}Linux Stretch Detected${white}"
       stretch_os=true
       echo "Installing curl..."
       sudo apt install -y curl
elif cat /etc/os-release | grep -q 'jessie'; then
      echo "${yellow}Linux Jessie Detected${white}"
      jessie_os=true
      echo "Installing curl..."
      sudo apt install -y curl
elif lsb_release -a | grep -q 'buster'; then
      echo "${yellow}Linux Buster Detected${white}"
      buster_os=true
      echo "Installing curl..."
      sudo apt install -y curl
elif cat /etc/os-release | grep -q 'buster'; then
      echo "${yellow}Linux Buster Detected${white}"
      buster_os=true
      echo "Installing curl..."
      sudo apt install -y curl
elif lsb_release -a | grep -q 'ubuntu'; then
      echo "${yellow}Ubuntu Linux Detected${white}"
      ubuntu_os=true
      echo "Installing curl..."
      sudo apt install -y curl
else
   echo "${red}Sorry, neither Linux Stretch, Linux Buster, or Ubuntu were detected, exiting..."
   exit 1
fi

#******************* MAIN SCRIPT START ******************************
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

killall java #need to stop pixelweb.jar if already running
curl localhost:8080/quit

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

if cat /proc/device-tree/model | grep -q 'Pi 4'; then #this counts Pi 400 too
   printf "${yellow}Raspberry Pi 4 detected...\n"
   pi4=true
   #machine_arch=arm64
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

#Now we need to check if we have the ES version that includes the game-select and system-select events
#ES verion Data Points
# Jan '23 BEFORE Pi updater: Version 2.10.1rp, built Dec 26 2021 - 16:25:37
# Jan '23 on Pi 4 after Pi updater: Version 2.11.0rp, built Dec 10 2022 - 12:26:20
# so looks like we need 2.11

es_version=$(cd /usr/bin && ./emulationstation -h | grep 'Version')
es_version=${es_version#*Version } #get onlly the line with Version
es_version=${es_version%,*} # keep all text before the comma // Version 2.10.1rp, built Dec 26 2021 - 16:25:37, built Dec 26 2021 - 16:25:37
es_version_numeric=$(echo $es_version | sed 's/[^0-9.]*//g') #now remove all letters // Version 2.10.1rp ==> 2.10.1
es_version_result=$(echo $es_version_numeric $es_minimum_version | awk '{if ($1 >= $2) print "pass"; else print "fail"}')

if [[ ! $es_version_result == "pass" ]]; then #we need to update to the latest EmulationStation to get the new game-select and system-select events
    while true; do
        read -p "${red}[IMPORTANT] Pixelcade needs EmulationStation version $es_minimum_version or higher, type y to upgrade your RetroPie and EmulationStation now and then choose "Update" from the RetroPie GUI menu(y/n)${white}" yn
        case $yn in
          [Yy]* ) sudo ~/RetroPie-Setup/retropie_setup.sh; break;;
          [Nn]* ) echo "${yellow}Continuing Pixelcade installation without RetroPie update, NOT RECOMMENDED${white}"; break;;
            * ) echo "Please answer y or n";;
        esac
    done
else
  echo "${green}Your EmulationStation version $es_version is good & meets the minimum EmulationStation version $es_minimum_version that is required for Pixelcade${white}"
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
      echo "${red}Sorry, do not have a Java JDK for your platform, you'll need to install a Java JDK or JRE manually under /userdata/system/jdk"
    fi
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

# we have all the pre-requisites so let's continue
#sudo apt-get -y update

# this is where pixelcade will live but if it's already there, then we need to do a refresh and not a git clone

mkdir ${INSTALLPATH}ptemp
cd ${INSTALLPATH}ptemp
if [[ ! -d ${INSTALLPATH}ptemp/pixelcade-linux-main ]]; then
    sudo rm -r ${INSTALLPATH}ptemp/pixelcade-linux-main
fi

echo "${yellow}Installing Pixelcade System Files...${white}"
#get the Pixelcade system files
wget https://github.com/alinke/pixelcade-linux/archive/refs/heads/main.zip
unzip main.zip
#git clone --depth 1 https://github.com/alinke/pixelcade-linux.git #we could do git clone here but batocera doesn't support git so let's be consistent with the code

if [[ ! -d ${INSTALLPATH}.emulationstation/scripts ]]; then #does the ES scripts folder exist, make it if not
    mkdir ${INSTALLPATH}.emulationstation/scripts
fi

#pixelcade system folder
cp -a -f ${INSTALLPATH}ptemp/pixelcade-linux-main/system ${INSTALLPATH}pixelcade #TO DO fix this
#pixelcade scripts for emulationstation events
echo "${yellow}Installing Pixelcade EmulationStation Scripts...${white}"
sudo cp -a -f ${INSTALLPATH}ptemp/pixelcade-linux-main/retropie/scripts ${INSTALLPATH}.emulationstation #note this will overwrite existing scripts
sudo find ${INSTALLPATH}.emulationstation/scripts -type f -iname "*.sh" -exec chmod +x {} \; #make all the scripts executble
#hi2txt for high score scrolling
echo "${yellow}Installing hi2txt for High Scores...${white}"
cp -r -f ${INSTALLPATH}ptemp/pixelcade-linux-main/hi2txt ${INSTALLPATH}pixelcade #for high scores

#now lets check if the user also has attractmode installed
if [[ -d "//home/pi/.attract" ]]; then
  echo "${yellow}Attract Mode front end detected, installing Pixelcade plug-in for Attract Mode...${white}"
  attractmode=true
  cd /home/pi/.attract
  #sudo cp -r /home/pi/pixelcade/attractmode-plugin/Pixelcade /home/pi/.attract/plugins
  cp -r ${INSTALLPATH}ptemp/pixelcade-linux-main/attractmode-plugin/Pixelcade /home/pi/.attract/plugins
    #let's also enable the plug-in saving the user from having to do that
  if cat attract.cfg | grep -q 'Pixelcade'; then
     echo "${yellow}Pixelcade Attract Mode plug-in already in attract.cfg, please ensure it's enabled from the Attract Mode GUI${white}"
  else
     echo "${yellow}Enabling Pixelcade Attract Mode plug-in in attract.cfg...${white}"
     sed -i -e '$a\' attract.cfg
     sed -i -e '$a\' attract.cfg
     sudo sed -i '$ a plugin\tPixelcade' attract.cfg
     sudo sed -i '$ a enabled\tyes' attract.cfg
  fi
  #don't forget to make the scripts executable
  sudo chmod +x /home/pi/.attract/plugins/Pixelcade/scripts/update_pixelcade.sh
  sudo chmod +x /home/pi/.attract/plugins/Pixelcade/scripts/display_marquee_text.sh
else
  attractmode=false
  echo "${yellow}Attract Mode front end is not installed..."
fi

sed -i '/all,mame/d' ${INSTALLPATH}pixelcade/console.csv
sed -i '/favorites,mame/d' ${INSTALLPATH}pixelcade/console.csv
sed -i '/recent,mame/d' ${INSTALLPATH}pixelcade/console.csv
#add to retropie startup
if [ "$retropie" = true ] ; then

    if cat /opt/retropie/configs/all/autostart.sh | grep "^[^#;]" | grep -q 'java'; then  #ignore any comment line, user has the old java pixelweb, we need to comment out this line and replace
        echo "${yellow}Backing up autostart.sh to autostart.bak${white}"
        cp autostart.sh autostart.bak
        echo "${yellow}Commenting out old java pixelweb version${white}"
        sed -e '/java/ s/^#*/#/' -i /opt/retropie/configs/all/autostart.sh #comment out the line
        echo "${yellow}Adding pixelweb to startup${white}"
        sudo sed -i '/^emulationstation.*/i cd /home/pi/pixelcade && ./pixelweb -image "system/retropie.png" -startup &\n' /opt/retropie/configs/all/autostart.sh 
        #echo -e "cd /home/pi/pixelcade && ./pixelweb -image "system/retropie.png" -startup &\n" >> autostart.sh #we'll just need to assume startup flag is needed now even though  may not have been in the past
    fi

    # let's check if autostart.sh already has pixelcade added and if so, we don't want to add it twice
    if cat /opt/retropie/configs/all/autostart.sh | grep -q 'pixelweb -image'; then
      echo "${yellow}Pixelcade already added to autostart.sh, skipping...${white}"
    else
      echo "${yellow}Adding Pixelcade /opt/retropie/configs/all/autostart.sh...${white}"
      sudo sed -i '/^emulationstation.*/i cd /home/pi/pixelcade && ./pixelweb -image "system/retropie.png" -startup &\n' /opt/retropie/configs/all/autostart.sh #insert this line before emulationstation #auto
      if [ "$attractmode" = true ] ; then
          echo "${yellow}Adding Pixelcade for Attract Mode to /opt/retropie/configs/all/autostart.sh...${white}"
          sudo sed -i '/^attract.*/i cd /home/pi/pixelcade && ./pixelweb -image "system/retropie.png" -startup &\n' /opt/retropie/configs/all/autostart.sh #insert this line before attract #auto
      fi
    fi
    echo "${yellow}Installing Fonts...${white}"
    cd /home/pi/pixelcade
    mkdir /home/pi/.fonts
    sudo cp /home/pi/pixelcade/fonts/*.ttf /home/pi/.fonts
    sudo apt -y install font-manager
    sudo fc-cache -v -f
else #there is no retropie so we need to add pixelcade using .service instead
  echo "${yellow}Installing Fonts...${white}"
  cd /home/pi/pixelcade
  mkdir /home/pi/.fonts
  sudo cp /home/pi/pixelcade/fonts/*.ttf /home/pi/.fonts
  sudo apt -y install font-manager
  sudo fc-cache -v -f
  echo "${yellow}Adding Pixelcade to Startup...${white}"
  cd /home/pi/pixelcade/system
  sudo chmod +x /home/pi/pixelcade/system/autostart.sh # TO DO need to replace this
  sudo cp pixelcade.service /etc/systemd/system/pixelcade.service
  #to do add check if the service is already running
  sudo systemctl start pixelcade.service
  sudo systemctl enable pixelcade.service
fi

sudo chown -R pi: /home/pi/pixelcade #this is our fail safe in case the user did a sudo ./setup.sh which seems to be needed on some pre-made Pi images

cd ~/pixelcade && ./pixelweb -image "system/retropie.png" -startup &

echo "Cleaning Up..."
cd ${INSTALLPATH}

if [[ -f master.zip ]]; then
    rm master.zip
fi

rm ${SCRIPTPATH}/setup-retropie.sh

if [[ -d ${INSTALLPATH}ptemp ]]; then
    rm -r ${INSTALLPATH}ptemp
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