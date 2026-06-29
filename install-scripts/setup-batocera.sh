#!/bin/bash
install_succesful=false
auto_update=false
pizero=false
pi4=false
pi3=false
pi5=false
install_doflinx=true
odroidn2=false
machine_arch=default
version=31  #increment this as the script is updated
batocera_version=default
batocera_recommended_minimum_version=33
batocera_self_contained_version=38
batocera_self_contained=false
batocera_40_plus_version=40
batocera_39_version=39
batocera_40_plus=false
pixelcade_version=default
beta=false
pixelcade_lcd_usb=false
pixelcade_lcd_usb_already_set=false
pixelcade_led_detected=false
led_has_marquee="unset"
NEWLINE=$'\n'

# Color definitions
cyan='\033[0;36m'
red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'
magenta='\033[0;35m'
orange='\033[0;33m' 

# Additional useful colors
blue='\033[0;34m'
purple='\033[0;35m'  # Same as magenta in basic ANSI
white='\033[1;37m'
black='\033[0;30m'
gray='\033[1;30m'
light_blue='\033[1;34m'
light_green='\033[1;32m'
light_cyan='\033[1;36m'

# Bold versions
bold='\033[1m'
bold_red='\033[1;31m'
bold_green='\033[1;32m'
bold_yellow='\033[1;33m'

# Background colors
bg_black='\033[40m'
bg_red='\033[41m'
bg_green='\033[42m'
bg_yellow='\033[43m'
bg_blue='\033[44m'
bg_magenta='\033[45m'
bg_cyan='\033[46m'
bg_white='\033[47m'

# Reset color after use
nc='\033[0m' # No Color

# Run this script with this command
# wget https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/main/install-scripts/setup-batocera.sh && chmod +x setup-batocera.sh && ./setup-batocera.sh

configure_usb_lcd() {
    echo "Configuring USB LCD ethernet connection..."
    echo "for i in \$(seq 1 10); do
        if ip link show eth1 > /dev/null 2>&1; then
            # Configure static IP for eth1 (USB gadget)
            ifconfig eth1 down
            ifconfig eth1 169.254.100.2 netmask 255.255.0.0 up
            echo 1 > /proc/sys/net/ipv6/conf/eth1/disable_ipv6
            break
        fi
        sleep 1
    done"
}

function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

commandLineArg=$1 #using this for skip

# Check for command line arguments
for arg in "$@"; do
  if [[ "$arg" == "beta" ]]; then
    echo -e "${cyan}[INFO] Installing Beta Version of Pixelcade${nc}"
    beta=true
  elif [[ "$arg" == "lcdusb" ]]; then
    echo -e "${cyan}[INFO] Setting up for Pixelcade LCD Marquee over USB${nc}"
    pixelcade_lcd_usb_already_set=true
    pixelcade_lcd_usb=true
  fi
done

cat << "EOF"
       _          _               _
 _ __ (_)_  _____| | ___ __ _  __| | ___
| '_ \| \ \/ / _ \ |/ __/ _` |/ _` |/ _ \
| |_) | |>  <  __/ | (_| (_| | (_| |  __/
| .__/|_/_/\_\___|_|\___\__,_|\__,_|\___|
|_|
EOF

echo -e "${magenta}       Pixelcade LED & LCD for Batocera : Installer Version $version    ${nc}"
echo ""
echo -e "${cyan}This script will install the Pixelcade software in $HOME/pixelcade${nc}"
echo -e "${cyan}Plese ensure you have at least 800 MB of free disk space in $HOME${nc}"
echo -e "${cyan}Now connect your Pixelcade marquee(s) to free USB port(s) on your device${nc}"
echo -e "${cyan}Grab a coffee or tea as this installer will take around 10 minutes depending on your Internet connection speed${nc}"
echo ""

install_doflinx=true

#let's see if Pixelcade LCD is there using lsusb and if not, ask the user a question as not all Pixelcade LCDs have the USB ID set, that is only with firmware 6.3 and above
if [[ "$pixelcade_lcd_usb_already_set" != "true" ]]; then
  if lsusb | grep -q '1d6b:3232'; then
      echo "${magenta}[INFO] Pixelcade LCD Marquee Detected over USB${nc}"
      pixelcade_lcd_usb="true"
      #this disables local link addressing conflicts
      mkdir -p /etc/connman
      echo "[General]" > /etc/connman/main.conf
      echo "NetworkInterfaceBlacklist=eth1" >> /etc/connman/main.conf
      batocera-save-overlay
  fi
else
  echo -e "${cyan}[INFO] Using pre-configured Pixelcade LCD Marquee over USB setup${nc}"
fi

INSTALLPATH="${HOME}/"
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

batocera_version="$(batocera-es-swissknife --version | cut -c1-2)" #get the version of Batocera

# let's make sure we have Baticera installation
if batocera-info | grep -q 'System'; then
    echo -e "${cyan}[INFO] Batocera Version ${batocera_version} Detected${nc}"
else
   echo "Sorry, Batocera was not detected, exiting..."
   echo -e "${red}[ERROR] Sorry, Batocera was not detected, exiting...${nc}"
   exit 1
fi

if [[ $batocera_version -ge $batocera_self_contained_version ]]; then #we couldn't get the Batocera version so just warn the user
    batocera-services disable dmd_real #disable DMD server in case you user turned it on
    batocera-settings-set dmd.pixelcade.dmdserver 0
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
    echo -e "${cyan}[INFO] Pixelcade added to Batocera services for auto-start${nc}"

    #adding the services file for Pixelcade LCD over USB
    if [[ "$pixelcade_lcd_usb" == "true" ]]; then
        echo -e "${cyan}[INFO] Setting up your Pixelcade LCD marquee with USB configuration${nc}"
        wget -O ${INSTALLPATH}services/pixelcade_lcd https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/main/batocera/pixelcade_lcd
        chmod +x ${INSTALLPATH}services/pixelcade_lcd
        sleep 1
        batocera-services enable pixelcade_lcd 
        batocera-services start pixelcade_lcd 
        echo -e "${cyan}[INFO] Pixelcade LCD added to Batocera services for auto-start${nc}"
    else
        echo -e "${cyan}[INFO] Skipping Pixelcade LCD marquee configuration${nc}"
    fi
fi

# Early WiFi setup for LCD USB — ask now while user is present for interactive questions
if [[ "$pixelcade_lcd_usb" == "true" ]]; then
    # For pre-40 Batocera, manually bring up the USB interface since there's no service
    if [[ "$batocera_40_plus" != "true" ]]; then
        for iface in eth1 usb0 usb1; do
            if ip link show "$iface" &>/dev/null; then
                ifconfig "$iface" 169.254.100.2 netmask 255.255.0.0 up 2>/dev/null
                break
            fi
        done
    fi
    sleep 2

    wifi_status_json=$(curl -s --connect-timeout 5 --max-time 10 \
        "http://169.254.100.1:8080/v2/wifi/status" 2>/dev/null)
    wifi_currently_connected=$(echo "$wifi_status_json" | grep -o '"connected":true' 2>/dev/null)
    wifi_current_ssid=$(echo "$wifi_status_json" | grep -o '"ssid":"[^"]*"' | sed 's/"ssid":"//;s/"//' 2>/dev/null)

    if [[ -n "$wifi_currently_connected" && -n "$wifi_current_ssid" ]]; then
        echo -e "${green}[INFO]${nc} Pixelcade LCD is already connected to WiFi: ${cyan}${wifi_current_ssid}${nc}"
        read -p "Do you want to switch to a different WiFi? [y/N]: " wifi_choice
    else
        echo -e "Would you like to configure WiFi for your Pixelcade LCD now?"
        read -p "Configure WiFi? [y/N]: " wifi_choice
    fi
    wifi_choice="${wifi_choice%$'\r'}"

    if [[ "$wifi_choice" =~ ^[Yy]$ ]]; then
        read -p "WiFi SSID: " wifi_ssid
        wifi_ssid="${wifi_ssid%$'\r'}"
        if [[ -z "$wifi_ssid" ]]; then
            echo -e "${yellow}[WARNING]${nc} No SSID entered, skipping WiFi setup"
        else
            read -p "WiFi Password (leave blank for open network): " wifi_password
            wifi_password="${wifi_password%$'\r'}"

            wifi_ssid_json="${wifi_ssid//\\/\\\\}"
            wifi_ssid_json="${wifi_ssid_json//\"/\\\"}"
            wifi_pass_json="${wifi_password//\\/\\\\}"
            wifi_pass_json="${wifi_pass_json//\"/\\\"}"

            echo -e "${green}[INFO]${nc} Connecting Pixelcade LCD to: ${wifi_ssid}"
            echo -e "${yellow}[NOTE]${nc} This may take up to 30 seconds..."

            http_code=$(curl -s -o /tmp/pixelcade_wifi_resp.json -w "%{http_code}" \
                -X POST \
                -H "Content-Type: application/json" \
                -d "{\"ssid\":\"${wifi_ssid_json}\",\"password\":\"${wifi_pass_json}\"}" \
                --connect-timeout 10 \
                --max-time 60 \
                "http://169.254.100.1:8080/v2/wifi/connect" 2>/dev/null)

            if [[ "$http_code" == "200" ]]; then
                if grep -q '"success":true' /tmp/pixelcade_wifi_resp.json 2>/dev/null; then
                    message=$(sed 's/.*"message":"\([^"]*\)".*/\1/' /tmp/pixelcade_wifi_resp.json 2>/dev/null)
                    echo -e "${green}[SUCCESS]${nc} WiFi configured successfully! (${message})"
                else
                    message=$(sed 's/.*"message":"\([^"]*\)".*/\1/' /tmp/pixelcade_wifi_resp.json 2>/dev/null)
                    echo -e "${red}[ERROR]${nc} WiFi connection failed: ${message}"
                    echo -e "${yellow}[INFO]${nc} You can configure WiFi later via the Pixelcade app"
                fi
            else
                echo -e "${red}[ERROR]${nc} Could not reach Pixelcade LCD (response: ${http_code})"
                echo -e "${yellow}[INFO]${nc} After rebooting, you can configure WiFi via the Pixelcade app"
            fi
            rm -f /tmp/pixelcade_wifi_resp.json
        fi
    else
        echo -e "${green}[INFO]${nc} Skipping WiFi setup - configure it later via the Pixelcade app"
    fi
fi

if [[ $batocera_version -eq $batocera_39_version ]]; then #if a user was on V40 and then went back to V39, we have to disable pixelcade service
    batocera-services disable dmd_real #disable DMD server in case you user turned it on
    batocera-settings-set dmd.pixelcade.dmdserver 0
    batocera-services disable pixelcade #disable the pixelcade service
    batocera-services disable pixelcade_lcd #disable the pixelcade service
    echo -e "${cyan}[INFO] Pixelcade service(s) disabled for Batocera V39${nc}"
fi

if [[ $batocera_version == "default" ]]; then #we couldn't get the Batocera version so just warn the user
  echo "[INFO] Could not detect your Batocra version"
  echo "[INFO] Please note that Batocera V33 or higher is required"
  echo "[INFO] for Pixelcade to update while scrolling through games"
  pause
else
  if [[ $batocera_version -lt $batocera_recommended_minimum_version ]]; then
        echo -e "${cyan}[INFO] Your Batocera version $batocera_version does not support Pixelcade updates during game scrolling${nc}"
        echo -e "${cyan}[INFO] On Batocera version $batocera_version, Pixelcade will update only when a game is launched${nc}"
        echo -e "${cyan}[INFO] Pixelcade updates during scrolling requires Batocera version $batocera_recommended_minimum_version or higher${nc}"
        while true; do
            read -p "Would you like to upgrade your Batocera version now (y/n) " yn
            case $yn in
                [Yy]* ) batocera-upgrade; break;;
                [Nn]* ) echo "Continuing Pixelcade Installation on your existing Batocera Version $batocera_version..."; break;;
                * ) echo "Please answer y or n";;
            esac
        done
    else
      echo -e "${cyan}[INFO] Your Batocera version $batocera_version supports dynamic Pixelcade updates during front end scrolling${nc}"
  fi
fi

echo "Stopping Pixelcade (if running...)"
# let's make sure pixelweb is not already running
killall java #in the case user has java pixelweb running

if [[ $batocera_self_contained == "false" ]]; then #meaning below V38
    if pgrep pixelweb > /dev/null; then #this locks up on V38 
        echo -e "${cyan}[INFO] Pixelcade is running, we'll stop it now before proceeding with installation${nc}"
        curl 127.0.0.1:8080/quit
    else
        echo -e "${cyan}[INFO] Pixelcade was not already running, all good to proceed with installation${nc}"
    fi
else #V38 and above kill like this TODO
     pkill -9 pixelweb    
fi

if [[ $batocera_version -ge $batocera_40_plus_version ]]; then 
    pkill -9 pixelweb
fi

#let's see if Pixelcade is there using lsusb
if [[ "$1" == "-skip" || "$2" == "-skip" ]]; then
  echo -e "${red}[INFO] Skipping Pixelcade USB detection check...${nc}"
elif ! command -v lsusb  &> /dev/null; then
    echo "${red}lsusb command not be found so cannot check if Pixelcade is USB connected${white}"
else
   if lsusb | grep -q '1b4f:0008'; then
      echo -e "${magenta}Pixelcade LED Marquee V1 Detected${white}"
      pixelcade_led_detected=true
   elif lsusb | grep -q '2e8a:1050'; then
      echo -e "${magenta}[INFO] Pixelcade LED Marquee V2 Detected${white}"
      pixelcade_led_detected=true
   elif [[ "$pixelcade_lcd_usb" == "true" ]]; then
      echo -e "${yellow}[INFO] Pixelcade LCD Marquee Detected${white}"
   else
      echo -e "${yellow}[WARNING] No Pixelcade LED or USB-connected LCD Marquee was detected${white}"
      echo ""
      while true; do
         read -p "Do you have a Pixelcade LCD connected over the network (not USB)? (y/n) " yn
         case $yn in
            [Yy]* )
               echo -e "${cyan}[INFO] Continuing installation for network-connected LCD...${nc}"
               break
               ;;
            [Nn]* )
               echo -e "${red}[ERROR] Please ensure your Pixelcade LED or LCD is connected and run the installer again${nc}"
               exit 1
               ;;
            * ) echo "Please answer y or n";;
         esac
      done
   fi
fi

# If both LED and LCD are connected, ask about the LED marquee setup
if [[ "$pixelcade_led_detected" == "true" && ("$pixelcade_lcd_usb" == "true" || "$pixelcade_lcd_usb_already_set" == "true") ]]; then
    echo ""
    echo -e "${magenta}═══════════════════════════════════════════════════════════${nc}"
    echo -e "${cyan}LED + LCD Marquee Configuration${nc}"
    echo -e "${magenta}═══════════════════════════════════════════════════════════${nc}"
    echo ""
    echo -e "${cyan}You have both a Pixelcade LED board and LCD connected.${nc}"
    echo -e "${cyan}Does your LED board have a marquee display attached?${nc}"
    echo -e "${cyan}  (y) = LED board has a marquee (LED + LCD marquees)${nc}"
    echo -e "${cyan}  (n) = LED board is for Pixelcade Pulse lighting effects only (LCD-only marquee)${nc}"
    echo ""
    while true; do
        read -p "Does your Pixelcade LED board have an LED marquee connected? (y/n) " yn
        case $yn in
            [Yy]* )
                led_has_marquee=true
                echo -e "${green}[INFO] Configured for LED + LCD marquees${nc}"
                break
                ;;
            [Nn]* )
                led_has_marquee=false
                echo -e "${green}[INFO] Configured for LCD-only marquee with Pulse lighting${nc}"
                break
                ;;
            * ) echo "Please answer y or n";;
        esac
    done
    echo ""
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
   echo -e "${yellow}arm_v6 Detected..."
   machine_arch=arm_v6
fi

if uname -m | grep -q 'armv7'; then
   echo -e "${yellow}arm_v7 Detected..."
   machine_arch=arm_v7
fi

if uname -m | grep -q 'aarch32'; then
   echo -e "${yellow}aarch32 Detected..."
   aarch32=arm_v7
fi

if uname -m | grep -q 'aarch64'; then
   echo -e "${yellow}aarch64 Detected..."
   machine_arch=arm64
fi

if uname -m | grep -q 'x86'; then
   echo -e "${yellow}x86 32-bit Detected..."
   machine_arch=386
fi

if uname -m | grep -q 'amd64'; then
   echo -e "${yellow}x86 64-bit Detected..."
   machine_arch=amd64
fi

if uname -m | grep -q 'x86_64'; then
   echo -e "${yellow}x86 64-bit Detected..."
   machine_arch=amd64
fi

if cat /proc/device-tree/model | grep -q 'Raspberry Pi 3'; then
   echo -e "${yellow}Raspberry Pi 3 detected..."
   pi3=true
fi

if cat /proc/device-tree/model | grep -q 'Raspberry Pi 4'; then
   printf "${yellow}Raspberry Pi 4 detected...\n"
   pi4=true
fi

if cat /proc/device-tree/model | grep -q 'Raspberry Pi 5'; then
   printf "${yellow}Raspberry Pi 5 detected...\n"
   pi5=true
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

# ============================================================================
# VPinball Installation for Batocera V41-V43 on AMD64 only (V44+ ships VPinball natively)
# ============================================================================

if [[ $batocera_version -ge 41 && $batocera_version -lt 44 && "$machine_arch" == "amd64" ]]; then
    echo ""
    echo -e "${magenta}═══════════════════════════════════════════════════════════${nc}"
    echo -e "${cyan}[INFO] Batocera V${batocera_version} on linux_amd64 detected${nc}"
    echo -e "${cyan}[INFO] Checking VPinball installation...${nc}"
    echo -e "${magenta}═══════════════════════════════════════════════════════════${nc}"
    echo ""

    # Check if VPinball is already installed
    VPINBALL_DIR="/userdata/system/configs/vpinball/VPinballX_GL-10.8.0-2077-afc7c38-Release-linux-x64"
    VPINBALL_BINARY="${VPINBALL_DIR}/VPinballX_GL"

    if [[ -f "$VPINBALL_BINARY" ]]; then
        echo -e "${green}[INFO] VPinball 10.8.0-2077 Patch is already installed${nc}"
        # Ensure symlink exists
        if [[ ! -L /usr/bin/vpinball ]]; then
            ln -s "$VPINBALL_DIR" /usr/bin/vpinball
            echo -e "${green}[INFO] Restored /usr/bin/vpinball symlink${nc}"
        fi
    else
        echo -e "${cyan}[INFO] Installing VPinball...${nc}"

    VPINBALL_INSTALL_SUCCESS=false

    download_vpinball_release()
    {
        # VPinball 10.8.0-2077 hosted on pixelcade-linux-builds (known-good version for Batocera + Pixelcade)
        # Official vpinball releases 10.8.1+ have compatibility issues
        local ASSET_NAME="VPinballX_GL-10.8.0-2077-afc7c38-Release-linux-x64.zip"
        local ASSET_URL="https://github.com/alinke/pixelcade-linux-builds/releases/download/vpinball-10.8.0-2077/${ASSET_NAME}"
        ARTIFACT_NAME="${ASSET_NAME%.zip}"

        echo -e "${cyan}[INFO] Downloading VPinball 10.8.0-2077 for Batocera...${nc}"

        # Extract to parent directory - the ZIP already contains the ARTIFACT_NAME folder
        mkdir -p /userdata/system/configs/vpinball
        cd /userdata/system/configs/vpinball

        # Clean up any previous installation
        rm -rf "$ARTIFACT_NAME"

        echo "Downloading ${ASSET_NAME}..."
        curl -L -o "${ASSET_NAME}" "$ASSET_URL"

        # Verify the download was successful (check file size > 1MB for a real binary)
        local FILE_SIZE=$(stat -c%s "${ASSET_NAME}" 2>/dev/null || echo "0")
        if [[ "$FILE_SIZE" -lt 1048576 ]]; then
            echo -e "${yellow}[WARN] VPinball download failed (received ${FILE_SIZE} bytes, expected >1MB).${nc}"
            echo -e "${cyan}[INFO] Skipping VPinball installation - this does not affect Pixelcade.${nc}"
            rm -f "${ASSET_NAME}"
            cd /userdata/system
            return 1
        fi

        echo "Uncompressing ${ASSET_NAME}..."
        if ! unzip -q "${ASSET_NAME}"; then
            echo -e "${yellow}[WARN] Failed to unzip VPinball. Skipping VPinball installation.${nc}"
            rm -f "${ASSET_NAME}"
            return 1
        fi

        # Check if there's a tar.gz inside (GitHub Actions artifact format)
        local TAR_FILE="${ARTIFACT_NAME}.tar.gz"
        if [[ -f "$TAR_FILE" ]]; then
            echo "Extracting ${TAR_FILE}..."
            if ! tar xzf "$TAR_FILE"; then
                echo -e "${yellow}[WARN] Failed to extract tar.gz. Skipping VPinball installation.${nc}"
                rm -f "${ASSET_NAME}" "$TAR_FILE"
                return 1
            fi
            rm -f "$TAR_FILE"
        fi

        rm -f "${ASSET_NAME}"
        VPINBALL_INSTALL_SUCCESS=true
        return 0
    }

    #
    # Download from GitHub Releases (more reliable than workflow artifacts)
    # Pinned to v10.8.0 stable release for Batocera compatibility
    #

    if download_vpinball_release; then
        #
        # Install symlink
        #

        rm -rf /usr/bin/vpinball
        ln -s "/userdata/system/configs/vpinball/${ARTIFACT_NAME}" /usr/bin/vpinball
        rm -f /userdata/system/configs/vpinball/${ARTIFACT_NAME}/libSDL2-* 2>/dev/null
        rm -f /userdata/system/configs/vpinball/${ARTIFACT_NAME}/libSDL2.so 2>/dev/null

        #
        # Save overlay
        #

        batocera-save-overlay 200

        echo -e "${green}[SUCCESS] VPinball installation complete for Batocera V${batocera_version}${nc}"
    else
        echo -e "${cyan}[INFO] Continuing with Pixelcade installation without VPinball...${nc}"
    fi

    # Cleanup
    unset ARTIFACT_NAME VPINBALL_INSTALL_SUCCESS

    fi  # end of "else" block for VPinball not already installed

elif [[ $batocera_version -ge 41 && $batocera_version -lt 44 && "$machine_arch" != "amd64" ]]; then
    echo -e "${yellow}[WARN] VPinball is only available for linux_amd64 (detected: linux_${machine_arch})${nc}"
    echo -e "${cyan}[INFO] Skipping VPinball installation${nc}"
fi
# ============================================================================
# End VPinball Installation
# ============================================================================

# ============================================================================
# udev Rule for Pixelcade - Creates stable /dev/pixelcade symlink
# ============================================================================
echo ""
echo -e "${cyan}[INFO] Setting up udev rule for Pixelcade...${nc}"

UDEV_RULE_FILE="/etc/udev/rules.d/99-pixelcade.rules"

# Check if udev rule needs to be created or updated
# Old format used %n for enumeration (pixelcade0, pixelcade1) - we need simple /dev/pixelcade for VPinball
NEED_UDEV_UPDATE="no"

if [[ ! -f "$UDEV_RULE_FILE" ]]; then
    NEED_UDEV_UPDATE="yes"
    echo -e "${cyan}[INFO] Creating udev rule for Pixelcade...${nc}"
elif grep -q '%n' "$UDEV_RULE_FILE" || grep -q '%N' "$UDEV_RULE_FILE"; then
    # Old format with enumeration - need to replace
    NEED_UDEV_UPDATE="yes"
    echo -e "${cyan}[INFO] Updating udev rule to use simple /dev/pixelcade symlink...${nc}"
elif ! grep -q 'SYMLINK+="pixelcade"' "$UDEV_RULE_FILE"; then
    # Rule exists but doesn't have correct symlink format
    NEED_UDEV_UPDATE="yes"
    echo -e "${cyan}[INFO] Updating udev rule with correct symlink format...${nc}"
else
    echo -e "${green}[INFO] udev rule for /dev/pixelcade already configured correctly${nc}"
fi

if [[ "$NEED_UDEV_UPDATE" == "yes" ]]; then
    # Create udev rule for Pixelcade V2 (RP2040-based) and V1
    # This creates a stable /dev/pixelcade symlink regardless of which ttyACM port is assigned
    cat > "$UDEV_RULE_FILE" << 'UDEVRULE'
# Pixelcade V2 (RP2040) - create stable symlink
SUBSYSTEM=="tty", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="1050", SYMLINK+="pixelcade", MODE="0666"
# Pixelcade V1 (Arduino/SparkFun) - create stable symlink
SUBSYSTEM=="tty", ATTRS{idVendor}=="1b4f", ATTRS{idProduct}=="0008", SYMLINK+="pixelcade", MODE="0666"
UDEVRULE

    # Reload udev rules
    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger 2>/dev/null || true

    echo -e "${green}[SUCCESS] udev rule installed - Pixelcade will be available at /dev/pixelcade${nc}"
fi

# ============================================================================
# Configure VPinballX.ini for Pixelcade (if it exists)
# ============================================================================
VPINBALL_INI="/userdata/system/configs/vpinball/VPinballX.ini"

# Only configure if VPinballX.ini exists
if [[ -f "$VPINBALL_INI" ]]; then
    echo -e "${cyan}[INFO] Configuring VPinballX.ini for Pixelcade...${nc}"

    # Update Pixelcade enabled setting (use specific pattern that won't match PixelcadeDevice)
    sed -i 's|^Pixelcade =.*|Pixelcade = 1|' "$VPINBALL_INI"

    # Update PixelcadeDevice setting
    sed -i 's|^PixelcadeDevice.*|PixelcadeDevice = /dev/pixelcade|' "$VPINBALL_INI"

    echo -e "${green}[SUCCESS] VPinballX.ini configured to use /dev/pixelcade${nc}"
fi

# Save overlay to persist udev rule and ini changes
batocera-save-overlay 2>/dev/null || true

# ============================================================================
# End udev and VPinball Configuration
# ============================================================================

if [[ ! -d "${INSTALLPATH}pixelcade" ]]; then #create the pixelcade folder if it's not there
   mkdir ${INSTALLPATH}pixelcade
fi

#java needed for high scores, hi2txt
cd ${INSTALLPATH}pixelcade
JDKDEST="${INSTALLPATH}pixelcade/jdk"

if [[ ! -d $JDKDEST ]]; then #does Java exist already
    if [[ $machine_arch == "arm64" ]]; then
          echo -e "${yellow}Installing Java JRE 11 64-Bit for aarch64...${white}" #these will unzip and create the jdk folder
          curl -kLO https://github.com/alinke/pixelcade-jre/raw/main/jdk-aarch64.zip #this is a 64-bit small JRE , same one used on the ALU
          unzip jdk-aarch64.zip
          chmod +x ${INSTALLPATH}pixelcade/jdk/bin/java
    elif [ $machine_arch == "arm_v7" ]; then
          echo -e "${yellow}Installing Java JRE 11 32-Bit for aarch32...${white}"
          curl -kLO https://github.com/alinke/pixelcade-jre/raw/main/jdk-aarch32.zip
          unzip jdk-aarch32.zip
          chmod +x ${INSTALLPATH}pixelcade/jdk/bin/java
    elif [ $machine_arch == "386" ]; then #pi zero is arm6 and cannot run the normal java :-( so have to get this special one
          echo -e "${yellow}Installing Java JRE 11 32-Bit for X86...${white}"
          curl -kLO https://github.com/alinke/pixelcade-jre/raw/main/jdk-x86-32.zip
          unzip jdk-x86-32.zip
          chmod +x ${INSTALLPATH}pixelcade/jdk/bin/java
    elif [ $machine_arch == "amd64" ]; then #pi zero is arm6 and cannot run the normal java :-( so have to get this special one
          echo -e "${yellow}Installing Java JRE 11 64-Bit for X86...${white}"
          curl -kLO https://github.com/alinke/pixelcade-jre/raw/main/jdk-x86-64.zip
          unzip jdk-x86-64.zip
          chmod +x ${INSTALLPATH}pixelcade/jdk/bin/java
    else
      echo -e "${red}Sorry, do not have a Java JDK for your platform.${NEWLINE}You'll need to install a Java JDK or JRE manually under ${INSTALLPATH}pixelcade/jdk/bin/java${NEWLINE}Note Java is only needed for high score functionality so you can also skip it"
    fi
fi

if [[ -f master.zip ]]; then
    rm master.zip
fi

cd ${INSTALLPATH}pixelcade
echo -e "${cyan}[INFO] Installing Pixelcade Software...${nc}"

if [[ $beta == "true" ]]; then
    url="https://github.com/alinke/pixelcade-linux-builds/raw/main/beta/linux_${machine_arch}/pixelweb"
    if wget --spider "$url" 2>/dev/null; then
        echo -e "${cyan}[BETA] A Pixelcade LED beta version is available so let's get it...${nc}"
        wget -O "${INSTALLPATH}pixelcade/pixelweb" "$url"
    else
        echo -e "${cyan}There is no beta available at this time so we'll go with the production version${nc}"
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
echo -e "${yellow}Removing Legacy Pixelcade Scripts called 01-pixelcade.sh (if they exist)...${white}"
find ${INSTALLPATH}configs/emulationstation/scripts -type f -name "01-pixelcade.sh" -ls
find ${INSTALLPATH}configs/emulationstation/scripts -type f -name "01-pixelcade.sh" -exec rm {} \;
echo -e "${yellow}Installing Pixelcade EmulationStation Scripts for Batocera...${white}"
#copy over the custom scripts
cp -r -f ${INSTALLPATH}ptemp/pixelcade-linux-main/batocera/scripts ${INSTALLPATH}configs/emulationstation #note this will overwrite existing scripts
find ${INSTALLPATH}configs/emulationstation/scripts -type f -iname "*.sh" -exec chmod +x {} \; #make all the scripts executble
#remove the attract mode scripts so they are not there by default
rm -f ${INSTALLPATH}configs/emulationstation/scripts/screensaver-start/pixelcade.sh
rm -f ${INSTALLPATH}configs/emulationstation/scripts/screensaver-stop/pixelcade.sh

# Ask user if they want Pixelcade Attract Mode
echo ""
echo -e "${magenta}═══════════════════════════════════════════════════════════${nc}"
echo -e "${cyan}Pixelcade Attract Mode (Optional)${nc}"
echo -e "${magenta}═══════════════════════════════════════════════════════════${nc}"
echo ""
echo -e "${cyan}When the Batocera screensaver kicks in, Pixelcade can cycle${nc}"
echo -e "${cyan}through a list of favorite widgets (weather, scores, clock, etc.)${nc}"
echo -e "${cyan}that you can configure from the Pixelcade Companion Web UI${nc}"
echo -e "${cyan}or the Pixelcade mobile app.${nc}"
echo -e "${cyan}This feature can also be turned off later from Pixelcade Companion.${nc}"
echo ""
while true; do
    read -p "Would you like to enable Pixelcade Attract Mode? (y/n) " yn
    case $yn in
        [Yy]* )
            echo -e "${green}[INFO] Enabling Pixelcade Attract Mode...${nc}"
            mkdir -p ${INSTALLPATH}configs/emulationstation/scripts/screensaver-start
            mkdir -p ${INSTALLPATH}configs/emulationstation/scripts/screensaver-stop
            cat > ${INSTALLPATH}configs/emulationstation/scripts/screensaver-start/pixelcade.sh << 'SSSTART'
#!/bin/bash

#
# Screensaver Start Event
# This script is called when the Batocera screensaver starts
#

# BASE URL for RESTful calls to Pixelcade
PIXELCADEBASEURL="http://127.0.0.1:8080/"

# Start attract mode with no interrupt (won't stop on button press)
PIXELCADEURL="attract?nointerrupt"
curl -s "$PIXELCADEBASEURL$PIXELCADEURL" >> /dev/null 2>/dev/null &
SSSTART
            cat > ${INSTALLPATH}configs/emulationstation/scripts/screensaver-stop/pixelcade.sh << 'SSSTOP'
#!/bin/bash

#
# Screensaver Stop Event
# This script is called when the Batocera screensaver stops
#

# BASE URL for RESTful calls to Pixelcade
PIXELCADEBASEURL="http://127.0.0.1:8080/"

# Stop attract mode
PIXELCADEURL="attract/stop"
curl -s "$PIXELCADEBASEURL$PIXELCADEURL" >> /dev/null 2>/dev/null
SSSTOP
            chmod +x ${INSTALLPATH}configs/emulationstation/scripts/screensaver-start/pixelcade.sh
            chmod +x ${INSTALLPATH}configs/emulationstation/scripts/screensaver-stop/pixelcade.sh
            echo -e "${green}[SUCCESS] Pixelcade Attract Mode enabled${nc}"
            break
            ;;
        [Nn]* )
            echo -e "${cyan}[INFO] Skipping Pixelcade Attract Mode${nc}"
            break
            ;;
        * ) echo "Please answer y or n";;
    esac
done
echo ""

#hi2txt for high score scrolling

echo -e "${yellow}Installing hi2txt for High Scores...${white}" #note this requires java
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
          if [ "$pixelcade_lcd_usb" = "true" ]; then
            usb_lcd_config=$(configure_usb_lcd)
            echo -e "${usb_lcd_config}\ncd /userdata/system/pixelcade && ./pixelweb -image \"system/batocera.png\" -startup &\n" >> custom.sh
          else
            echo -e "cd /userdata/system/pixelcade && ./pixelweb -image \"system/batocera.png\" -startup &\n" >> custom.sh
          fi
      fi

      if cat ${INSTALLPATH}custom.sh | grep "^[^#;]" | grep -q 'java'; then  #ignore any comment line, user has the old java pixelweb, we need to comment out this line and replace
          echo "Backing up custom.sh to custom.bak"
          cp custom.sh custom.bak
          echo "Commenting out old java pixelweb version"
          sed -e '/java/ s/^#*/#/' -i custom.sh #comment out the line
          echo "Adding pixelweb to startup"
          if [ "$pixelcade_lcd_usb" = "true" ]; then
            usb_lcd_config=$(configure_usb_lcd)
            echo -e "${usb_lcd_config}\ncd /userdata/system/pixelcade && ./pixelweb -image \"system/batocera.png\" -startup &\n" >> custom.sh
          else
            echo -e "cd /userdata/system/pixelcade && ./pixelweb -image \"system/batocera.png\" -startup &\n" >> custom.sh
          fi
      fi

    if cat ${INSTALLPATH}custom.sh | grep "^[^#;]" | grep -q 'pixelweb -image'; then
        echo "Pixelcade already added to custom.sh, skipping..."
    else
        if cat ${INSTALLPATH}custom.sh | grep -q 'start)'; then
            echo "custom.sh start is here..."
            if [ "$pixelcade_lcd_usb" = "true" ]; then
                usb_lcd_config=$(configure_usb_lcd)
                sed -i "/start)/a\\\\t${usb_lcd_config}\n\\\\tcd ${INSTALLPATH}pixelcade && ./pixelweb -image \"system/batocera.png\" -startup &" ${INSTALLPATH}custom.sh
            else
                sed -i "/start)/a\\\\tcd ${INSTALLPATH}pixelcade && ./pixelweb -image \"system/batocera.png\" -startup &" ${INSTALLPATH}custom.sh
            fi
        else
            echo "Adding Pixelcade Listener auto start to your existing custom.sh for non-vanilla Batocera image..."
            if [ "$pixelcade_lcd_usb" = "true" ]; then
                usb_lcd_config=$(configure_usb_lcd)
                echo -e "${usb_lcd_config}\ncd ${INSTALLPATH}pixelcade && ./pixelweb -image \"system/batocera.png\" -startup &" >> ${INSTALLPATH}custom.sh
            else
                echo -e "cd ${INSTALLPATH}pixelcade && ./pixelweb -image \"system/batocera.png\" -startup &" >> ${INSTALLPATH}custom.sh
            fi
        fi
    fi
    chmod +x ${INSTALLPATH}custom.sh
    # because we are not on self contained, pixelweb won't be running so let's start it now
    cd ${INSTALLPATH}pixelcade && ./pixelweb -image "system/batocera.png" -startup & #note we dont' want to start pixelweb if we are on V38 or above as it's already running
fi
else #we have self contained V38 or above so let's make sure custom.sh has pixelweb removed
    if cat ${INSTALLPATH}custom.sh | grep "^[^#;]" | grep -q 'pixelcade'; then  #ignore any comment line, user has the old java pixelweb, we need to comment out this line and replace
        echo "Backing up custom.sh to custom.bak"
        cp custom.sh custom.bak
        echo "Commenting out pixelweb in custom.sh as we no longer need it here"
        sed -e '/pixelcade/ s/^#*/#/' -i ${INSTALLPATH}custom.sh #comment out the line
    fi
fi

chmod a+x ${INSTALLPATH}pixelcade/pixelweb

# If the mame artwork folder is missing but a version file exists, remove the version file
# so pixelweb performs a full re-download instead of skipping it as already up-to-date.
_artwork_version_file="${INSTALLPATH}pixelcade/.alinke_pixelcade-master-version"
if [[ ! -d "${INSTALLPATH}pixelcade/mame" && -f "$_artwork_version_file" ]]; then
    rm -f "$_artwork_version_file"
    echo -e "${green}[INFO]${nc} Artwork folder missing — cleared version file to force full artwork download"
fi

cd ${INSTALLPATH}pixelcade && ./pixelweb -install-artwork #install the artwork

if [[ $? == 2 ]]; then #this means artwork is already installed so let's check for updates and get if so
    echo -e "${green}[INFO]${nc} Updating Pixelcade artwork — this downloads thousands of files and may take several minutes..."
    cd ${INSTALLPATH}pixelcade && ./pixelweb -update-artwork &
    _artwork_pid=$!
    _artwork_elapsed=0
    while kill -0 "$_artwork_pid" 2>/dev/null; do
        sleep 15
        _artwork_elapsed=$(( _artwork_elapsed + 15 ))
        echo -e "${green}[INFO]${nc} Still downloading artwork... (${_artwork_elapsed}s elapsed)"
    done
    wait "$_artwork_pid"
    _artwork_exit=$?

    if [ $_artwork_exit -eq 0 ]; then
        echo -e "${green}[SUCCESS]${nc} Pixelcade artwork updated"
    else
        echo -e "${yellow}[WARNING]${nc} Artwork update exited with code $_artwork_exit - you can retry later from the Update tab"
    fi
fi

# Force-update DOFLinx .MAME files (artwork update may skip these if artwork is already up to date)
echo -e "${green}[INFO]${nc} Updating DOFLinx .MAME files..."
cd ${INSTALLPATH}pixelcade && ./pixelweb -update-doflinx &
_doflinx_pid=$!
_doflinx_elapsed=0
while kill -0 "$_doflinx_pid" 2>/dev/null; do
    sleep 10
    _doflinx_elapsed=$(( _doflinx_elapsed + 10 ))
    echo -e "${green}[INFO]${nc} Still downloading DOFLinx MAME files... (${_doflinx_elapsed}s elapsed)"
done
wait "$_doflinx_pid"

if [ $? -eq 0 ]; then
    echo -e "${green}[SUCCESS]${nc} DOFLinx .MAME files updated"
else
    echo -e "${yellow}[WARNING]${nc} DOFLinx MAME update failed - you can retry later from the Update tab"
fi

cd ${INSTALLPATH}pixelcade

wget -O ${INSTALLPATH}pixelcade/pixelcadelcdfinder https://github.com/alinke/pixelcade-linux-builds/raw/main/lcdfinder/linux_${machine_arch}/pixelcadelcdfinder
chmod +x ${INSTALLPATH}pixelcade/pixelcadelcdfinder

echo "Checking for Pixelcade LCDs on your network..."
${INSTALLPATH}pixelcade/pixelcadelcdfinder -nogui #check for Pixelcade LCDs


#if pixelcade lcd is usb connected, then update pixelcade.ini accordingly
if [[ "$pixelcade_lcd_usb" == "true" ]]; then
    echo "Updating pixelcade.ini for LCD USB connection..."
    if [[ -f ${INSTALLPATH}pixelcade/pixelcade.ini ]]; then
        sed -i 's/lcdMarquee[ ]*=[ ]*false/lcdMarquee = true/g' ${INSTALLPATH}pixelcade/pixelcade.ini
        sed -i 's/lcdUsbConnected[ ]*=[ ]*false/lcdUsbConnected = true/g' ${INSTALLPATH}pixelcade/pixelcade.ini

        # Fetch the LCD hostname from the USB local-link address and write it to pixelcade.ini
        lcd_info_json=$(curl -s --connect-timeout 5 --max-time 10 \
            "http://169.254.100.1:8080/v2/info" 2>/dev/null)
        lcd_hostname=$(echo "$lcd_info_json" | grep -o '"hostname":"[^"]*"' | sed 's/"hostname":"//;s/"//')
        if [[ -n "$lcd_hostname" ]]; then
            sed -i "s|lcdMarqueeHostName[ ]*=.*|lcdMarqueeHostName            = ${lcd_hostname}|" ${INSTALLPATH}pixelcade/pixelcade.ini
            echo -e "${green}[SUCCESS]${nc} pixelcade.ini updated for LCD USB (hostname: ${lcd_hostname})"
        else
            echo -e "${green}[SUCCESS]${nc} pixelcade.ini updated for LCD USB"
            echo -e "${yellow}[WARNING]${nc} Could not retrieve LCD hostname — set lcdMarqueeHostName manually if needed"
        fi
        # If LED board has no marquee (Pulse-only), set noLedMatrix = true
        if [[ "$led_has_marquee" == "false" ]]; then
            if grep -q '^noLedMatrix' ${INSTALLPATH}pixelcade/pixelcade.ini; then
                sed -i 's/^noLedMatrix.*/noLedMatrix                   = true/' ${INSTALLPATH}pixelcade/pixelcade.ini
            else
                echo 'noLedMatrix                   = true' >> ${INSTALLPATH}pixelcade/pixelcade.ini
            fi
            echo -e "${green}[INFO]${nc} Set noLedMatrix = true (LCD-only marquee with Pulse lighting)"
        fi
    else
        echo -e "${cyan}pixelcade.ini not found, skipping update...${nc}"
    fi

    # AtGames Legends Ultimate detection - configure BitLCD and DOFLinx automatically
    # rk3328-ha8801 = Legends 1.1, rk3399-legends = Legends 1.0
    board_compatible=$(cat /proc/device-tree/compatible 2>/dev/null | tr '\0' '\n')
    if echo "$board_compatible" | grep -qE 'ha8801|rk3399-legends'; then
        echo -e "${green}[INFO]${nc} AtGames Legends cabinet detected"

        # Set BitLCD screen mode on the LCD
        echo -e "${green}[INFO]${nc} Setting BitLCD screen mode..."
        alu_response=$(curl -s --connect-timeout 5 --max-time 15 \
            "http://169.254.100.1:8080/settings?key=screenMode&value=bitlcd" 2>/dev/null)
        if [[ -n "$alu_response" ]]; then
            echo -e "${green}[SUCCESS]${nc} BitLCD screen mode configured"
        else
            echo -e "${yellow}[WARNING]${nc} Could not set BitLCD screen mode - configure it later in the Pixelcade app"
        fi

        # Configure DOFLinx.ini button mappings for ALU
        doflinx_ini="${INSTALLPATH}doflinx/config/DOFLinx.ini"
        if [[ -f "$doflinx_ini" ]]; then
            echo -e "${green}[INFO]${nc} Configuring DOFLinx.ini for AtGames Legends Ultimate..."
            for entry in \
                "LINK_BUT_CN=0000,Orange,J0106,0000,MONO,J0306" \
                "LINK_BUT_P1=0000,Cyan,J0109,0000,MONO,J0309" \
                "LINK_BUT_P2=0000,Orchid,J0209,0000,MONO,J0409"; do
                key="${entry%%=*}"
                value="${entry#*=}"
                if grep -q "^${key}[[:space:]]*=" "$doflinx_ini"; then
                    sed -i "s|^${key}[[:space:]]*=.*|${key}=${value}|" "$doflinx_ini"
                else
                    echo "${key}=${value}" >> "$doflinx_ini"
                fi
            done
            echo -e "${green}[SUCCESS]${nc} DOFLinx.ini configured for AtGames Legends Ultimate"
        else
            echo -e "${yellow}[WARNING]${nc} DOFLinx.ini not found, skipping ALU button configuration"
        fi
    fi

fi

# Install DOFLinx if user opted in
if [[ "$install_doflinx" == "true" ]]; then
    echo ""
    echo -e "${magenta}═══════════════════════════════════════════════════════════${nc}"
    echo -e "${cyan}Installing DOFLinx for In-Game Effects on the FBNEO wheel...${nc}"
    echo -e "${magenta}═══════════════════════════════════════════════════════════${nc}"
    echo ""

    # Stop running DOFLinx if this is a reinstall
    doflinx_pids=$(pidof DOFLinx 2>/dev/null)
    if [[ -n "$doflinx_pids" ]]; then
        echo -e "${green}[INFO]${nc} Stopping running DOFLinx process(es): $doflinx_pids"
        DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 ${INSTALLPATH}doflinx/DOFLinxMsg QUIT 2>/dev/null
        sleep 2
        doflinx_pids=$(pidof DOFLinx 2>/dev/null)
        if [[ -n "$doflinx_pids" ]]; then
            kill -9 $doflinx_pids 2>/dev/null
            sleep 1
        fi
    fi

    # Create directories
    mkdir -p ${INSTALLPATH}doflinx/config

    # Map architecture to DOFLinx folder names
    if [[ $machine_arch == "arm64" ]]; then
        doflinx_stable_folder="Linux_arm64"
        doflinx_beta_folder="Linux_arm64_beta"
    elif [[ $machine_arch == "amd64" ]]; then
        doflinx_stable_folder="Linux_x64"
        doflinx_beta_folder="Linux_x64_beta"
    else
        echo -e "${red}[ERROR]${nc} DOFLinx unsupported architecture: $machine_arch"
        doflinx_stable_folder=""
    fi

    if [[ -n "$doflinx_stable_folder" ]]; then
        doflinx_stable_url="https://github.com/DOFLinx/CurrentExecutable/raw/main/${doflinx_stable_folder}"
        doflinx_beta_url="https://github.com/DOFLinx/CurrentExecutable/raw/main/${doflinx_beta_folder}"

        # Beta: only DOFLinx and DOFLinx.pdb come from beta folder; everything else from stable
        doflinx_using_beta=false
        if [[ "$beta" == "true" ]]; then
            echo -e "${yellow}[BETA]${nc} Checking for beta DOFLinx version..."
            if wget -q --spider "${doflinx_beta_url}/DOFLinx"; then
                doflinx_main_url="$doflinx_beta_url"
                doflinx_using_beta=true
                echo -e "${green}[INFO]${nc} Beta DOFLinx found - downloading from ${doflinx_beta_folder}..."
            else
                doflinx_main_url="$doflinx_stable_url"
                echo -e "${yellow}[INFO]${nc} Beta DOFLinx not available - falling back to stable..."
            fi
        else
            doflinx_main_url="$doflinx_stable_url"
            echo -e "${green}[INFO]${nc} Downloading DOFLinx from ${doflinx_stable_folder}..."
        fi

        # Download DOFLinx executable (from beta or stable)
        echo -e "${green}[INFO]${nc} Downloading DOFLinx executable..."
        wget -q -O "${INSTALLPATH}doflinx/DOFLinx" "${doflinx_main_url}/DOFLinx"
        if [ $? -ne 0 ]; then
            echo -e "${red}[ERROR]${nc} Failed to download DOFLinx executable"
        fi

        wget -q -O "${INSTALLPATH}doflinx/DOFLinx.pdb" "${doflinx_main_url}/DOFLinx.pdb" 2>/dev/null

        # Download supporting files from stable folder
        echo -e "${green}[INFO]${nc} Downloading supporting files..."
        wget -q -O "${INSTALLPATH}doflinx/DOFLinxMsg" "${doflinx_stable_url}/DOFLinxMsg"
        if [ $? -ne 0 ]; then
            echo -e "${red}[ERROR]${nc} Failed to download DOFLinxMsg executable"
        fi
        wget -q -O "${INSTALLPATH}doflinx/DOFLinxMsg.pdb" "${doflinx_stable_url}/DOFLinxMsg.pdb" 2>/dev/null
        wget -q -O "${INSTALLPATH}doflinx/keycodes" "${doflinx_stable_url}/keycodes" 2>/dev/null
        wget -q -O "${INSTALLPATH}doflinx/HELP.txt" "${doflinx_stable_url}/HELP.txt" 2>/dev/null
        wget -q -O "${INSTALLPATH}doflinx/DONATE.txt" "${doflinx_stable_url}/DONATE.txt" 2>/dev/null
        wget -q -O "${INSTALLPATH}doflinx/DOFLinx Update Notes.txt" "${doflinx_stable_url}/DOFLinx%20Update%20Notes.txt" 2>/dev/null

        # Set execute permissions
        chmod a+x ${INSTALLPATH}doflinx/DOFLinx
        chmod a+x ${INSTALLPATH}doflinx/DOFLinxMsg
        chmod a+x ${INSTALLPATH}doflinx/keycodes 2>/dev/null

        # Create DOFLinx startup script
        if [[ ! -f "${INSTALLPATH}doflinx/doflinx.sh" ]]; then
            echo -e "${green}[INFO]${nc} Creating DOFLinx startup script..."
            cat > ${INSTALLPATH}doflinx/doflinx.sh << DOFEOF
#!/bin/bash
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
cd ${INSTALLPATH}doflinx && ./DOFLinx
DOFEOF
            chmod +x ${INSTALLPATH}doflinx/doflinx.sh
        fi

        # Download config files — use rcade config (FBNEO core) with Batocera paths
        doflinx_config_dir="${INSTALLPATH}doflinx/config"
        doflinx_ini_url="https://github.com/alinke/pixelcade-linux-builds/raw/main/rcade/DOFLinx.ini"
        doflinx_ini="${doflinx_config_dir}/DOFLinx.ini"
        doflinx_ini_hash="${doflinx_config_dir}/.DOFLinx.ini.original.md5"
        doflinx_ini_tmp="${doflinx_config_dir}/DOFLinx.ini.tmp"

        echo -e "${green}[INFO]${nc} Checking DOFLinx.ini..."
        wget -q -O "$doflinx_ini_tmp" "$doflinx_ini_url"
        if [ $? -ne 0 ]; then
            echo -e "${yellow}[WARNING]${nc} Failed to download DOFLinx.ini"
            rm -f "$doflinx_ini_tmp"
        else
            # Fix paths from rcade to Batocera
            sed -i "s|/rcade/share/pixelcade/|${INSTALLPATH}pixelcade/|g" "$doflinx_ini_tmp"
            sed -i "s|/rcade/share/roms/mame/|/userdata/roms/mame/|g" "$doflinx_ini_tmp"
            sed -i "s|Config file for DOFLinx Linux on RCade|Config file for DOFLinx Linux on Batocera|" "$doflinx_ini_tmp"

            new_hash=$(md5sum "$doflinx_ini_tmp" 2>/dev/null | cut -d' ' -f1)
            current_hash=$(md5sum "$doflinx_ini" 2>/dev/null | cut -d' ' -f1)
            original_hash=$(cat "$doflinx_ini_hash" 2>/dev/null)

            if [[ ! -f "$doflinx_ini" ]]; then
                echo -e "${green}[INFO]${nc} Installing DOFLinx.ini..."
                mv "$doflinx_ini_tmp" "$doflinx_ini"
                echo "$new_hash" > "$doflinx_ini_hash"
            elif [[ "$new_hash" == "$current_hash" ]]; then
                echo -e "${green}[INFO]${nc} DOFLinx.ini is already up to date"
                rm -f "$doflinx_ini_tmp"
            elif [[ "$current_hash" == "$original_hash" ]]; then
                echo -e "${green}[INFO]${nc} Updating DOFLinx.ini to latest version..."
                mv "$doflinx_ini_tmp" "$doflinx_ini"
                echo "$new_hash" > "$doflinx_ini_hash"
                rm -f "${doflinx_config_dir}/DOFLinx.ini.latest"
            else
                echo -e "${yellow}[NOTICE]${nc} You have customized DOFLinx.ini - ${green}preserving your changes${nc}"
                echo -e "${yellow}[NOTICE]${nc} New version saved as: ${cyan}${doflinx_config_dir}/DOFLinx.ini.latest${nc}"
                mv "$doflinx_ini_tmp" "${doflinx_config_dir}/DOFLinx.ini.latest"
            fi
        fi

        # Smart update for colours.ini
        colours_ini_url="https://github.com/alinke/pixelcade-linux-builds/raw/main/rcade/colours.ini"
        colours_ini="${doflinx_config_dir}/colours.ini"
        colours_ini_hash="${doflinx_config_dir}/.colours.ini.original.md5"
        colours_ini_tmp="${doflinx_config_dir}/colours.ini.tmp"

        echo -e "${green}[INFO]${nc} Checking colours.ini..."
        wget -q -O "$colours_ini_tmp" "$colours_ini_url"
        if [ $? -ne 0 ]; then
            echo -e "${yellow}[WARNING]${nc} Failed to download colours.ini"
            rm -f "$colours_ini_tmp"
        else
            new_hash=$(md5sum "$colours_ini_tmp" 2>/dev/null | cut -d' ' -f1)
            current_hash=$(md5sum "$colours_ini" 2>/dev/null | cut -d' ' -f1)
            original_hash=$(cat "$colours_ini_hash" 2>/dev/null)

            if [[ ! -f "$colours_ini" ]]; then
                echo -e "${green}[INFO]${nc} Installing colours.ini..."
                mv "$colours_ini_tmp" "$colours_ini"
                echo "$new_hash" > "$colours_ini_hash"
            elif [[ "$new_hash" == "$current_hash" ]]; then
                echo -e "${green}[INFO]${nc} colours.ini is already up to date"
                rm -f "$colours_ini_tmp"
            elif [[ "$current_hash" == "$original_hash" ]]; then
                echo -e "${green}[INFO]${nc} Updating colours.ini to latest version..."
                mv "$colours_ini_tmp" "$colours_ini"
                echo "$new_hash" > "$colours_ini_hash"
                rm -f "${doflinx_config_dir}/colours.ini.latest"
            else
                echo -e "${yellow}[NOTICE]${nc} You have customized colours.ini - ${green}preserving your changes${nc}"
                echo -e "${yellow}[NOTICE]${nc} New version saved as: ${cyan}${doflinx_config_dir}/colours.ini.latest${nc}"
                mv "$colours_ini_tmp" "${doflinx_config_dir}/colours.ini.latest"
            fi
        fi

        # Install DOFLinx service file for auto-start
        echo -e "${green}[INFO]${nc} Installing DOFLinx service file..."
        mkdir -p ${INSTALLPATH}services
        wget -q -O ${INSTALLPATH}services/doflinx https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/main/batocera/doflinx_fbneo/doflinx
        if [ $? -eq 0 ]; then
            chmod +x ${INSTALLPATH}services/doflinx
            batocera-services enable doflinx
            echo -e "${green}[SUCCESS]${nc} DOFLinx service installed and enabled for auto-start"
        else
            echo -e "${yellow}[WARNING]${nc} Failed to download DOFLinx service file - DOFLinx will need to be started manually"
        fi

        # Enable RetroArch Network Command Interface (required for DOFLinx to detect which game is running)
        RETROARCH_CFG="${INSTALLPATH}configs/retroarch/retroarchcustom.cfg"
        if [[ -f "$RETROARCH_CFG" ]]; then
            echo -e "${green}[INFO]${nc} Enabling RetroArch Network Command Interface for DOFLinx..."
            if grep -q '^network_cmd_enable' "$RETROARCH_CFG"; then
                sed -i 's/^network_cmd_enable.*/network_cmd_enable = "true"/' "$RETROARCH_CFG"
            else
                echo 'network_cmd_enable = "true"' >> "$RETROARCH_CFG"
            fi
            if grep -q '^network_cmd_port' "$RETROARCH_CFG"; then
                sed -i 's/^network_cmd_port.*/network_cmd_port = "55355"/' "$RETROARCH_CFG"
            else
                echo 'network_cmd_port = "55355"' >> "$RETROARCH_CFG"
            fi
            echo -e "${green}[SUCCESS]${nc} RetroArch NCI enabled (network_cmd_enable=true, port=55355)"
        else
            echo -e "${yellow}[WARNING]${nc} RetroArch config not found at $RETROARCH_CFG — you may need to enable Network Command Interface manually"
        fi

        # Configure PIXELCADE_EXPLOSIONS_DISPLAYS based on marquee setup
        doflinx_ini="${INSTALLPATH}doflinx/config/DOFLinx.ini"
        if [[ -f "$doflinx_ini" ]]; then
            if [[ "$pixelcade_led_detected" == "false" || "$led_has_marquee" == "false" ]]; then
                explosions_value="LCD"
            elif [[ "$led_has_marquee" == "true" ]]; then
                explosions_value="LED,LCD"
            else
                explosions_value=""
            fi
            if [[ -n "$explosions_value" ]]; then
                if grep -q '^PIXELCADE_EXPLOSIONS_DISPLAYS' "$doflinx_ini"; then
                    sed -i "s|^PIXELCADE_EXPLOSIONS_DISPLAYS.*|PIXELCADE_EXPLOSIONS_DISPLAYS=${explosions_value}|" "$doflinx_ini"
                else
                    echo "PIXELCADE_EXPLOSIONS_DISPLAYS=${explosions_value}" >> "$doflinx_ini"
                fi
                echo -e "${green}[INFO]${nc} Set PIXELCADE_EXPLOSIONS_DISPLAYS=${explosions_value}"
            fi
        fi

        echo -e "${green}[SUCCESS]${nc} DOFLinx installed to ${INSTALLPATH}doflinx"
        if [[ "$doflinx_using_beta" == "true" ]]; then
            echo -e "${cyan}[INFO]${nc} DOFLinx Version: ${yellow}BETA${nc}"
        fi
    fi
    echo ""
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
echo -e "${magenta}[INFO] Pixelcade $pixelcade_version Installed${nc}"

echo " "
echo -e "${cyan}[INFO] An LED art pack is available at https://pixelcade.org/artpack/${nc}"
echo -e "${cyan}[INFO] The LED art pack adds additional animated marquees for select games${nc}"
echo -e "${cyan}[INFO] After purchase, you'll receive a serial code and then install with this command:${nc}"
echo -e "${cyan}[INFO] cd ~/pixelcade && ./pixelweb --install-artpack <serial code>${nc}"

echo -e "\n${magenta}Please now reboot and Pixelcade will be loaded automatically on startup${nc}"
echo -e "${magenta}Would you like to reboot now? (y/n)${nc}"

read -r answer

case ${answer:0:1} in
    y|Y )
        echo -e "${magenta}System will reboot now...${nc}"
        sleep 2
        reboot || sudo reboot
        ;;
    * )
        echo -e "${red}Reboot skipped. Please remember to reboot your system later.${nc}"
        pause
        echo -e "${cyan}[INFO] Now Starting Pixlecade but may not work until a reboot...${nc}"
        if [[ $batocera_40_plus == "true" ]]; then 
          echo "[INFO] Starting Pixelcade..."
          batocera-services start pixelcade
        else 
          echo "[INFO] Please now Reboot"
        fi
        ;;
esac

echo ""