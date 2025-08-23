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
version=12  #increment this as the script is updated
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
echo "If you have a Pixelcade LCD Marquee, ensure it is connected to your WiFi or Ethernet network and cannot be connected via USB to MiSTer"
echo "Grab some coffee or tea, this installer will take around 30 minutes to complete"

INSTALLPATH="/media/fat/"

function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

add_log_entry_if_needed() {
    echo "${yellow}Ensuring only one log_file_entry=1 exists in MiSTer.ini...${white}"
    
    # Create a temporary file
    temp_file=$(mktemp)
    
    # Remove all existing log_file_entry lines and copy the rest to temp file
    grep -v "^log_file_entry=" MiSTer.ini > "$temp_file"
    
    # Check if [MiSTer] section exists
    if grep -q "^\[MiSTer\]" "$temp_file"; then
        # Add log_file_entry=1 after [MiSTer] section
        sed -i '/^\[MiSTer\]/a\log_file_entry=1' "$temp_file"
        echo "${yellow}Added log_file_entry=1 after [MiSTer] section${white}"
    else
        # If no [MiSTer] section, add it at the beginning with log_file_entry=1
        echo -e "[MiSTer]\nlog_file_entry=1\n$(cat "$temp_file")" > "$temp_file"
        echo "${yellow}Added [MiSTer] section with log_file_entry=1${white}"
    fi
    
    # Replace the original file with the cleaned up version
    mv "$temp_file" MiSTer.ini
    
    echo "${yellow}Successfully ensured single log_file_entry=1 in MiSTer.ini${white}"
}

echo "Stopping Pixelcade (if running...)"
# let's make sure pixelweb is not already running
killall java #in the case user has java pixelweb running
curl localhost:8080/quit

#do we have enough disk space?
cd ${INSTALLPATH}
FREE=`df -k --output=avail "$PWD" | tail -n1`   # df -k not df -h
if [[ $FREE -lt 1048576 ]]; then               # 1G = 10*1024*1024k
  echo "${yellow}Sorry, you'll need at least 1 GB of free disk space on ${INSTALLPATH}${white}"
  exit 1
fi

#do we have an upgraded MiSTer?
if [ -f "${INSTALLPATH}linux/_user-startup.sh" ] || [ -f "${INSTALLPATH}linux/user-startup.sh" ]; then
      echo "${yellow}Updated MiSTer Detected, Good${white}"
else
      echo "${red}WARNING: Pixelcade may not be compatible with this version of MiSTer as no ${INSTALLPATH}linux/_user-startup.sh was found. You may need to upgrade to the latest MiSTer${white}"
fi

#is Pixelcade already installed?
if [[ -d "${INSTALLPATH}pixelcade" ]]; then
    echo "${yellow}Pixelcade is already installed, updating to the latest including artwork${white}"
fi

# let's detect if Pixelcade is connected
pixelcade_led_detected=false
if ls /dev/ttyACM0 | grep -q '/dev/ttyACM0'; then
   echo "${yellow}Pixelcade LED Marquee Detected on /dev/ttyACM0${white}"
   pixelcade_led_detected=true
elif ls /dev/ttyACM1 | grep -q '/dev/ttyACM1'; then
  echo "${yellow}Pixelcade LED Marquee Detected on /dev/ttyACM1${white}"
  pixelcade_led_detected=true
else
   echo "${red}Pixelcade LED Marquee was not detected, pleasse ensure Pixelcade is USB connected to your MiSTer if you have a Pixelcade LED Marquee. You can still use Pixelcade with just a Pixelcade LCD Marquee connected to your network${white}"
fi

# TO DO ask user if they want to install on SD card or USB
if [[ -d "${INSTALLPATH}" ]]; then
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

cd ${INSTALLPATH}

if [[ ! -d "${INSTALLPATH}pixelcade" ]]; then #create the pixelcade folder if it's not there
   mkdir ${INSTALLPATH}pixelcade
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

echo "${yellow}Downloading Additional Files Needed for Pixelcade MiSTer...${white}"
cd ${INSTALLPATH}pixelcade

wget -O ${INSTALLPATH}pixelcade/ip.txt https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/main/mister/ip.txt
wget -O ${INSTALLPATH}pixelcade/pixelcadeLink.sh https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/main/mister/pixelcadeLink.sh
wget -O ${INSTALLPATH}pixelcade/runpixelcade.sh https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/main/mister/runpixelcade.sh
chmod +x ${INSTALLPATH}pixelcade/runpixelcade.sh

echo "${yellow}Adding Pixelcade MiSTer to Startup...${white}"

if [[ ! -f "${INSTALLPATH}linux/user-startup.sh" ]]; then #is the user startup is NOT there
    if [[ -f "${INSTALLPATH}linux/_user-startup.sh" ]]; then #user the default user-startup.sh that comes with MiSTer
        mv ${INSTALLPATH}linux/_user-startup.sh ${INSTALLPATH}linux/user-startup.sh
        cd ${INSTALLPATH}linux
        grep -qxF "cd ${INSTALLPATH}pixelcade && ./runpixelcade.sh' user-startup.sh || echo 'cd ${INSTALLPATH}pixelcade && ./runpixelcade.sh" >> user-startup.sh
    else #the defaut is not there so let's make a new one from scratch
        echo -e "echo ***" \$\1 "***\n\ncd ${INSTALLPATH}pixelcade && ./runpixelcade.sh" >> ${INSTALLPATH}linux/user-startup.sh
    fi
else
    if cat ${INSTALLPATH}linux/user-startup.sh | grep -q 'runpixelcade'; then
        echo "Pixelcade was already added to user-startup.sh, skipping..."
    else
        echo "Adding Pixelcade Listener auto start to user-startup.sh ..."
        sed -i -e "$acd ${INSTALLPATH}pixelcade && ./runpixelcade.sh" ${INSTALLPATH}linux/user-startup.sh
    fi
fi
chmod +x ${INSTALLPATH}linux/user-startup.sh


echo "${yellow}Modifying MiSTer.ini to turn on current game logging which is needed for Pixelcade...${white}"
cd ${INSTALLPATH}
if [[ -f "${INSTALLPATH}MiSTer.ini" ]]; then
    echo "${yellow}Updating your existing MiSTer.ini${white}"
    add_log_entry_if_needed
elif [[ -f "${INSTALLPATH}MiSTer_example.ini" ]]; then
    echo "${yellow}Adding MiSTer.ini${white}"
    mv ${INSTALLPATH}MiSTer_example.ini ${INSTALLPATH}MiSTer.ini
    add_log_entry_if_needed
    exit 1
else
    echo "${yellow}Getting a vanilla MiSTer.ini${white}"
    wget -O ${INSTALLPATH}MiSTer.ini https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/main/mister/MiSTer.ini
    add_log_entry_if_needed
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
${INSTALLPATH}linux/user-startup.sh
echo "Pausing for 5 seconds..."
sleep 5

# Check if LED was not detected and prompt for LCD setup
if [ "$pixelcade_led_detected" = false ] ; then
    while true; do
        read -p "${yellow}Do you have a Pixelcade LCD Marquee and if so, is it connected to your WiFi or Ethernet? Note: MiSTer unfortunately does not support Pixelcade LCD over USB. (y/n)${white}" yn
        case $yn in
            [Yy]* ) 
                echo "${yellow}Setting up Pixelcade LCD Marquee...${white}"
                read -p "${yellow}Please enter your Pixelcade LCD's IP address: ${white}" lcd_ip_address
                
                # Update pixelcade.ini with LCD settings
                cd ${INSTALLPATH}pixelcade
                if [[ -f "pixelcade.ini" ]]; then
                    echo "${yellow}Updating pixelcade.ini for LCD Marquee...${white}"
                    # Update existing values only - using precise patterns to avoid duplicates
                    sed -i "s/^lcdMarquee[[:space:]]*=.*/lcdMarquee = true/" pixelcade.ini
                    sed -i "s/^lcdUsbConnected[[:space:]]*=.*/lcdUsbConnected = false/" pixelcade.ini
                    sed -i "s/^lcdMarqueeIPAddress[[:space:]]*=.*/lcdMarqueeIPAddress = ${lcd_ip_address}/" pixelcade.ini
                    sed -i "s/^lcdMarqueeHostName[[:space:]]*=.*/lcdMarqueeHostName = /" pixelcade.ini
                    sed -i "s/^lcdDisableUSBCheck[[:space:]]*=.*/lcdDisableUSBCheck = true/" pixelcade.ini
                    
                    echo "${yellow}LCD Marquee configured with IP address: ${lcd_ip_address}${white}"
                else
                    echo "${red}Warning: pixelcade.ini not found. LCD settings could not be configured.${white}"
                fi
                break;;
            [Nn]* ) 
                echo "${yellow}Continuing without LCD Marquee setup...${white}"
                break;;
            * ) 
                echo "Please answer yes or no.";;
        esac
    done
fi

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