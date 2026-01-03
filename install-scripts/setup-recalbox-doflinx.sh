#!/bin/bash
# DOFLinx installer for RecalBox
# Supports both arm64 and x64 architectures
# Note: Pixelcade (pixelweb) must be installed and running before DOFLinx
# Usage: ./setup-recalbox-doflinx.sh [beta]

version=10
install_successful=true
RECALBOX_STARTUP="/etc/init.d/S99MyScript.py"

# Check for beta flag
beta=false
if [[ "$1" == "beta" ]]; then
    beta=true
fi

NEWLINE=$'\n'
cyan='\033[0;36m'
red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'
white='\033[0;37m'
nc='\033[0m'

function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

cat << "EOF"
       _          _               _
 _ __ (_)_  _____| | ___ __ _  __| | ___
| '_ \| \ \/ / _ \ |/ __/ _` |/ _` |/ _ \
| |_) | |>  <  __/ | (_| (_| | (_| |  __/
| .__/|_/_/\_\___|_|\___\__,_|\__,_|\___|
|_|
EOF

echo -e ""
if [[ "$beta" == "true" ]]; then
    echo -e "       ${cyan}DOFLinx for RecalBox : Installer Version $version ${yellow}[BETA]${nc}    "
else
    echo -e "       ${cyan}DOFLinx for RecalBox : Installer Version $version${nc}    "
fi
echo -e ""
echo -e "This script will install and configure DOFLinx for in-game effects on RecalBox"
echo -e "DOFLinx will be installed in /recalbox/share/bootvideos/doflinx"
echo -e ""
echo -e "${yellow}Prerequisites:${nc}"
echo -e "  - Pixelcade must already be installed (run setup-recalbox.sh first)"
echo -e "  - Pixelcade Pulse hardware for LED effects"
echo -e ""
echo -e "${yellow}Important:${nc}"
echo -e "  - Pixelweb must be running before DOFLinx starts"
echo -e "  - This script will configure DOFLinx to start after pixelweb with a delay"
echo -e ""
pause

# Paths for RecalBox
# DOFLinx installs to /recalbox/share/bootvideos/doflinx (writable, persistent, allows exec)
DOFLINX_PATH="/recalbox/share/bootvideos/doflinx"
PIXELCADE_PATH="/etc/init.d/pixelcade"
ARTPATH="/recalbox/share/pixelcade-art/"

# Check if Pixelcade is installed
if [[ ! -f "${PIXELCADE_PATH}/pixelweb" ]]; then
    echo -e "${red}[ERROR]${nc} Pixelcade is not installed. Please run setup-recalbox.sh first."
    exit 1
fi

# Check if we have write permissions (check parent directory since target may not exist yet)
if [[ ! -w "/recalbox/share/bootvideos" ]]; then
    echo -e "${red}[ERROR]${nc} No write permission to /recalbox/share/bootvideos"
    exit 1
fi

# If this is an existing installation then DOFLinx could already be running
if test -f ${DOFLINX_PATH}/DOFLinx; then
   echo -e "${yellow}[INFO]${nc} Existing DOFLinx installation found - will overwrite and reinstall"
   if pgrep -x "DOFLinx" > /dev/null; then
     echo -e "${green}[INFO]${nc} Stopping running DOFLinx process"
     ${DOFLINX_PATH}/DOFLinxMsg QUIT 2>/dev/null
     sleep 2  # Give it time to stop
     # Force kill if still running
     if pgrep -x "DOFLinx" > /dev/null; then
         killall -9 DOFLinx 2>/dev/null
     fi
   fi
   echo -e "${green}[INFO]${nc} Proceeding with overwrite installation..."
   reinstall=true
else
   echo -e "${green}[INFO]${nc} Fresh DOFLinx installation"
   reinstall=false
fi

# Architecture detection
machine_arch="default"

if uname -m | grep -q 'armv6'; then
   echo -e "${yellow}[WARNING]${nc} arm_v6 Detected - not supported by DOFLinx"
   machine_arch=arm_v6
fi

if uname -m | grep -q 'armv7'; then
   echo -e "${yellow}[WARNING]${nc} arm_v7 Detected - not supported by DOFLinx"
   machine_arch=arm_v7
fi

if uname -m | grep -q 'aarch32'; then
   echo -e "${yellow}[WARNING]${nc} aarch32 Detected - not supported by DOFLinx"
   machine_arch=arm_v7
fi

if uname -m | grep -q 'aarch64'; then
   echo -e "${green}[INFO]${nc} aarch64 Detected..."
   machine_arch=arm64
fi

if uname -m | grep -q 'x86_64'; then
   echo -e "${green}[INFO]${nc} x86 64-bit Detected..."
   machine_arch=x64
fi

if uname -m | grep -q 'amd64'; then
   echo -e "${green}[INFO]${nc} x86 64-bit Detected..."
   machine_arch=x64
fi

# Hardware detection for logging
if test -f /proc/device-tree/model; then
   if cat /proc/device-tree/model | grep -q 'Raspberry Pi 3'; then
      echo -e "${yellow}[INFO]${nc} Raspberry Pi 3 detected..."
   fi
   if cat /proc/device-tree/model | grep -q 'Pi 4'; then
      echo -e "${yellow}[INFO]${nc} Raspberry Pi 4 detected..."
   fi
   if cat /proc/device-tree/model | grep -q 'Pi 5'; then
      echo -e "${yellow}[INFO]${nc} Raspberry Pi 5 detected..."
   fi
   if cat /proc/device-tree/model | grep -q 'Pi Zero'; then
      echo -e "${yellow}[INFO]${nc} Raspberry Pi Zero detected..."
   fi
   if cat /proc/device-tree/model | grep -q 'ODROID-N2'; then
      echo -e "${yellow}[INFO]${nc} ODroid N2 or N2+ detected..."
   fi
fi

# Check for supported architecture
if [[ $machine_arch == "default" ]]; then
  echo -e "${red}[ERROR]${nc} Your device platform WAS NOT detected"
  echo -e "${yellow}[WARNING]${nc} Guessing that you are on arm64 but be aware DOFLinx may not work"
  machine_arch=arm64
fi

if [[ $machine_arch == "arm_v6" ]] || [[ $machine_arch == "arm_v7" ]]; then
  echo -e "${red}[ERROR]${nc} DOFLinx only supports arm64 and x64 architectures"
  echo -e "${red}[ERROR]${nc} Your architecture ($machine_arch) is not supported"
  exit 1
fi

# Create necessary directories
if [[ ! -d "${DOFLINX_PATH}" ]]; then
   echo -e "${green}[INFO]${nc} Creating DOFLinx directory..."
   mkdir -p ${DOFLINX_PATH}
fi

# Create config directory
if [[ ! -d "${DOFLINX_PATH}/config" ]]; then
   mkdir -p ${DOFLINX_PATH}/config
fi

echo -e "${cyan}[INFO]${nc} Installing DOFLinx Software..."

# Determine folders based on architecture
# Repository: https://github.com/DOFLinx/CurrentExecutable
# Beta folder only contains DOFLinx and DOFLinx.pdb - all other files come from stable
if [[ $machine_arch == "arm64" ]]; then
    stable_folder="Linux_arm64"
    beta_folder="Linux_arm64_beta"
elif [[ $machine_arch == "x64" ]]; then
    stable_folder="Linux_x64"
    beta_folder="Linux_x64_beta"
fi

# Base URLs for downloads
stable_url="https://github.com/DOFLinx/CurrentExecutable/raw/main/${stable_folder}"
beta_url="https://github.com/DOFLinx/CurrentExecutable/raw/main/${beta_folder}"

# Beta folder only contains DOFLinx and DOFLinx.pdb
# All other supporting files come from stable folder
# If beta mode is requested but beta folder doesn't exist, fall back to stable
using_beta=false
if [[ "$beta" == "true" ]]; then
    echo -e "${yellow}[BETA]${nc} Checking for beta version..."
    # Try to download from beta folder first
    wget -q --spider "${beta_url}/DOFLinx"
    if [ $? -eq 0 ]; then
        main_url="$beta_url"
        using_beta=true
        echo -e "${green}[INFO]${nc} Beta version found - downloading DOFLinx from ${beta_folder}..."
    else
        main_url="$stable_url"
        echo -e "${yellow}[INFO]${nc} Beta version not available - falling back to stable ${stable_folder}..."
    fi
else
    main_url="$stable_url"
    echo -e "${green}[INFO]${nc} Downloading DOFLinx from ${stable_folder}..."
fi

# Download main DOFLinx executable (from beta or stable based on availability)
echo -e "${green}[INFO]${nc} Downloading DOFLinx executable..."
wget -O "${DOFLINX_PATH}/DOFLinx" "${main_url}/DOFLinx"
if [ $? -ne 0 ]; then
   echo -e "${red}[ERROR]${nc} Failed to download DOFLinx executable"
   install_successful=false
fi

echo -e "${green}[INFO]${nc} Downloading DOFLinx.pdb..."
wget -O "${DOFLINX_PATH}/DOFLinx.pdb" "${main_url}/DOFLinx.pdb"
if [ $? -ne 0 ]; then
   echo -e "${yellow}[WARNING]${nc} Failed to download DOFLinx.pdb"
fi

# Download supporting files from stable folder (these don't exist in beta folder)
echo -e "${green}[INFO]${nc} Downloading supporting files from ${stable_folder}..."

echo -e "${green}[INFO]${nc} Downloading DOFLinxMsg executable..."
wget -O "${DOFLINX_PATH}/DOFLinxMsg" "${stable_url}/DOFLinxMsg"
if [ $? -ne 0 ]; then
   echo -e "${red}[ERROR]${nc} Failed to download DOFLinxMsg executable"
   install_successful=false
fi

echo -e "${green}[INFO]${nc} Downloading DOFLinxMsg.pdb..."
wget -O "${DOFLINX_PATH}/DOFLinxMsg.pdb" "${stable_url}/DOFLinxMsg.pdb"
if [ $? -ne 0 ]; then
   echo -e "${yellow}[WARNING]${nc} Failed to download DOFLinxMsg.pdb"
fi

echo -e "${green}[INFO]${nc} Downloading keycodes..."
wget -O "${DOFLINX_PATH}/keycodes" "${stable_url}/keycodes"
if [ $? -ne 0 ]; then
   echo -e "${yellow}[WARNING]${nc} Failed to download keycodes"
fi

echo -e "${green}[INFO]${nc} Downloading HELP.txt..."
wget -O "${DOFLINX_PATH}/HELP.txt" "${stable_url}/HELP.txt"
if [ $? -ne 0 ]; then
   echo -e "${yellow}[WARNING]${nc} Failed to download HELP.txt"
fi

echo -e "${green}[INFO]${nc} Downloading DONATE.txt..."
wget -O "${DOFLINX_PATH}/DONATE.txt" "${stable_url}/DONATE.txt"
if [ $? -ne 0 ]; then
   echo -e "${yellow}[WARNING]${nc} Failed to download DONATE.txt"
fi

echo -e "${green}[INFO]${nc} Downloading DOFLinx Update Notes.txt..."
wget -O "${DOFLINX_PATH}/DOFLinx Update Notes.txt" "${stable_url}/DOFLinx%20Update%20Notes.txt"
if [ $? -ne 0 ]; then
   echo -e "${yellow}[WARNING]${nc} Failed to download DOFLinx Update Notes.txt"
fi

# Set execute permissions
echo -e "${green}[INFO]${nc} Setting permissions..."
chmod a+x ${DOFLINX_PATH}/DOFLinx
chmod a+x ${DOFLINX_PATH}/DOFLinxMsg
chmod a+x ${DOFLINX_PATH}/keycodes 2>/dev/null

# Download configuration files from pixelcade-linux-builds
echo -e "${green}[INFO]${nc} Downloading configuration files..."

# Download DOFLinx.ini
doflinx_ini_url="https://github.com/alinke/pixelcade-linux-builds/raw/main/recalbox/DOFLinx.ini"
echo -e "${green}[INFO]${nc} Downloading DOFLinx.ini..."
wget -O "${DOFLINX_PATH}/config/DOFLinx.ini" "$doflinx_ini_url"

if [ $? -ne 0 ]; then
   echo -e "${yellow}[WARNING]${nc} Failed to download DOFLinx.ini"
else
   echo -e "${green}[SUCCESS]${nc} DOFLinx.ini downloaded"
fi

# Download colours.ini
colours_ini_url="https://github.com/alinke/pixelcade-linux-builds/raw/main/recalbox/colours.ini"
echo -e "${green}[INFO]${nc} Downloading colours.ini..."
wget -O "${DOFLINX_PATH}/config/colours.ini" "$colours_ini_url"

if [ $? -ne 0 ]; then
   echo -e "${yellow}[WARNING]${nc} Failed to download colours.ini"
else
   echo -e "${green}[SUCCESS]${nc} colours.ini downloaded"
fi

# Create DOFLinx startup script
# This script waits for pixelweb to be running before starting DOFLinx
echo -e "${green}[INFO]${nc} Creating DOFLinx startup script..."
cat > ${DOFLINX_PATH}/doflinx.sh << 'EOFSCRIPT'
#!/bin/bash
# DOFLinx startup script for RecalBox
# Waits for pixelweb to be running before starting DOFLinx

export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

# Wait for pixelweb to be running (max 30 seconds)
MAX_WAIT=30
WAIT_COUNT=0
echo "Waiting for pixelweb to start..."
while ! pgrep -x "pixelweb" > /dev/null 2>&1; do
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo "Timeout waiting for pixelweb - starting DOFLinx anyway"
        break
    fi
done

# Additional delay to ensure pixelweb is fully initialized
sleep 2

echo "Starting DOFLinx..."
cd /recalbox/share/bootvideos/doflinx && ./DOFLinx PATH_INI=/recalbox/share/bootvideos/doflinx/config/ &
EOFSCRIPT
chmod +x ${DOFLINX_PATH}/doflinx.sh

# Determine if we need to modify system files (requires read-write mount)
need_startup_modification=false
need_beta_retroarch=false

if [[ -f "$RECALBOX_STARTUP" ]] && ! grep -q "doflinx" "$RECALBOX_STARTUP"; then
    need_startup_modification=true
fi

if [[ "$beta" == "true" ]]; then
    need_beta_retroarch=true
fi

# If we need to modify system files, do it all in one read-write session
if [[ "$need_startup_modification" == "true" ]] || [[ "$need_beta_retroarch" == "true" ]]; then
    echo -e "${green}[INFO]${nc} Remounting filesystem as read-write for system modifications..."
    mount -o remount,rw /

    # Beta mode: Download and install custom RetroArch binary
    if [[ "$need_beta_retroarch" == "true" ]]; then
        echo -e "${yellow}[BETA]${nc} Downloading custom RetroArch binary..."
        wget -O /usr/bin/retroarch "https://github.com/alinke/pixelcade-linux-builds/raw/main/recalbox/retroarch"
        if [ $? -eq 0 ]; then
            chmod 755 /usr/bin/retroarch
            echo -e "${green}[SUCCESS]${nc} Custom RetroArch binary installed"
        else
            echo -e "${red}[ERROR]${nc} Failed to download custom RetroArch binary"
        fi
    fi

    # Add DOFLinx to RecalBox startup (S99MyScript.py)
    if [[ "$need_startup_modification" == "true" ]]; then
        echo -e "${green}[INFO]${nc} Adding DOFLinx startup code to $RECALBOX_STARTUP..."

        # Check if pixelweb is in the startup script
        if grep -q "pixelweb" "$RECALBOX_STARTUP"; then
            # Add DOFLinx startup after pixelweb line
            # The doflinx.sh script itself waits for pixelweb, so we just need to call it after
            sed -i '/pixelweb.*&$/a\    # Start DOFLinx for in-game effects (waits for pixelweb internally)\n    /recalbox/share/bootvideos/doflinx/doflinx.sh \&' "$RECALBOX_STARTUP"

            if [ $? -eq 0 ]; then
                echo -e "${green}[SUCCESS]${nc} DOFLinx startup code added to $RECALBOX_STARTUP"
                echo -e "${green}[INFO]${nc} DOFLinx will start after pixelweb is running"
            else
                echo -e "${yellow}[WARNING]${nc} Failed to modify $RECALBOX_STARTUP automatically"
                echo -e "${yellow}[INFO]${nc} Please add the following line manually to $RECALBOX_STARTUP after the pixelweb line:"
                echo -e "    /recalbox/share/bootvideos/doflinx/doflinx.sh &"
            fi
        else
            echo -e "${yellow}[WARNING]${nc} pixelweb not found in $RECALBOX_STARTUP"
            echo -e "${yellow}[INFO]${nc} Please add the following line manually to $RECALBOX_STARTUP after pixelweb starts:"
            echo -e "    /recalbox/share/bootvideos/doflinx/doflinx.sh &"
        fi
    fi

    # Sync and remount filesystem as read-only for protection
    sync
    echo -e "${green}[INFO]${nc} Remounting filesystem as read-only..."
    mount -o remount,ro /
else
    # Check if startup file exists but already has doflinx
    if [[ -f "$RECALBOX_STARTUP" ]]; then
        echo -e "${green}[INFO]${nc} DOFLinx startup code already present in $RECALBOX_STARTUP"
    else
        echo -e "${yellow}[WARNING]${nc} $RECALBOX_STARTUP not found"
        echo -e "${yellow}[INFO]${nc} DOFLinx will need to be started manually or added to your startup script"
        echo -e "${yellow}[INFO]${nc} To start manually (after pixelweb is running): /recalbox/share/bootvideos/doflinx/doflinx.sh"
    fi
fi

# Configure RetroArch for DOFLinx network commands
RETROARCH_CFG="/recalbox/share/system/configs/retroarch/retroarchcustom.cfg"

# Function to update or add a setting in a config file
update_setting() {
    local key="$1"
    local value="$2"
    local file="$3"

    if grep -q "^${key}" "$file" 2>/dev/null; then
        # Key exists, update it
        sed -i "s|^${key}.*|${key} = ${value}|" "$file"
    else
        # Key doesn't exist, add it
        echo "${key} = ${value}" >> "$file"
    fi
}

if [[ -f "$RETROARCH_CFG" ]]; then
    echo -e "${green}[INFO]${nc} Configuring RetroArch for DOFLinx network commands..."

    # Update RetroArch settings for DOFLinx
    update_setting "network_cmd_enable" "true" "$RETROARCH_CFG"
    update_setting "network_cmd_port" "55355" "$RETROARCH_CFG"
    update_setting "cheevos_enable" "true" "$RETROARCH_CFG"
    update_setting "cheevos_hardcore_mode_enable" "true" "$RETROARCH_CFG"
    update_setting "cheevos_start_active" "true" "$RETROARCH_CFG"

    echo -e "${green}[SUCCESS]${nc} RetroArch configured for DOFLinx"
else
    echo -e "${yellow}[WARNING]${nc} RetroArch config not found at $RETROARCH_CFG"
    echo -e "${yellow}[INFO]${nc} You may need to manually add the following settings to your retroarchcustom.cfg:"
    echo -e "    network_cmd_enable = true"
    echo -e "    network_cmd_port = 55355"
    echo -e "    cheevos_enable = true"
    echo -e "    cheevos_hardcore_mode_enable = true"
    echo -e "    cheevos_start_active = true"
fi

# Update DOFLinx .MAME files via pixelweb
echo -e "${green}[INFO]${nc} Updating DOFLinx .MAME files..."
cd ${PIXELCADE_PATH}
./pixelweb -p ${ARTPATH} -update-doflinx

if [ $? -eq 0 ]; then
    echo -e "${green}[SUCCESS]${nc} DOFLinx .MAME files updated"
else
    echo -e "${yellow}[WARNING]${nc} Failed to update DOFLinx .MAME files"
    echo -e "${yellow}[INFO]${nc} You can manually run: cd ${PIXELCADE_PATH} && ./pixelweb -p ${ARTPATH} -update-doflinx"
fi

# No cleanup needed - we downloaded files directly without temp folders

if [[ $install_successful == "true" ]]; then
   echo -e ""
   if [[ $reinstall == "true" ]]; then
       if [[ "$using_beta" == "true" ]]; then
           echo -e "${green}[SUCCESS]${nc} DOFLinx ${yellow}BETA${nc} reinstalled successfully for RecalBox!"
       else
           echo -e "${green}[SUCCESS]${nc} DOFLinx reinstalled successfully for RecalBox!"
       fi
   else
       if [[ "$using_beta" == "true" ]]; then
           echo -e "${green}[SUCCESS]${nc} DOFLinx ${yellow}BETA${nc} installed successfully for RecalBox!"
       else
           echo -e "${green}[SUCCESS]${nc} DOFLinx installed successfully for RecalBox!"
       fi
   fi
   echo -e ""
   echo -e "Installation Details:"
   echo -e "  Location: ${DOFLINX_PATH}/"
   echo -e "  Executable: ${DOFLINX_PATH}/DOFLinx"
   echo -e "  Config: ${DOFLINX_PATH}/config/DOFLinx.ini"
   echo -e "  Startup Script: ${DOFLINX_PATH}/doflinx.sh"
   if [[ "$using_beta" == "true" ]]; then
       echo -e "  Version: ${yellow}BETA${nc} (${beta_folder})"
   else
       echo -e "  Version: Stable (${stable_folder})"
   fi
   echo -e ""
   echo -e "${green}[INFO]${nc} Architecture: $machine_arch"
   echo -e "${green}[INFO]${nc} DOFLinx will start automatically after pixelweb is running"
   echo -e "${green}[INFO]${nc} You may need to customize settings in config/DOFLinx.ini for your setup"
   echo -e ""
   echo -e "Resources:"
   echo -e "  Documentation: https://doflinx.github.io/docs/"
   echo -e "  Support: http://www.vpforums.org/index.php?showforum=104"
   echo -e ""
   echo -e "${cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
   echo -e "${green}[IMPORTANT]${nc} Please reboot your RecalBox system now to complete the installation"
   echo -e "${cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
   echo -e ""
   echo -e "After rebooting, access the Pixelcade Companion Web UI at:"
   echo -e "  ${cyan}http://recalbox.local:7070${nc}"
   echo -e "  or"
   echo -e "  ${cyan}http://<Your RecalBox IP Address>:7070${nc}"
   echo -e ""

   # Remount filesystem as read-only for protection
   echo -e "${green}[INFO]${nc} Remounting filesystem as read-only..."
   mount -o remount,ro /
   echo -e "${green}[SUCCESS]${nc} Filesystem remounted as read-only"
   echo -e ""

   # Ask user if they want to start DOFLinx now (only if pixelweb is already running)
   if pgrep -x "pixelweb" > /dev/null 2>&1; then
       while true; do
           read -p "Pixelweb is running. Start DOFLinx now for testing? (y/n) " yn
           case $yn in
               [Yy]* )
                   echo -e "${green}[INFO]${nc} Starting DOFLinx..."
                   ${DOFLINX_PATH}/doflinx.sh &
                   sleep 3
                   if pgrep -x "DOFLinx" > /dev/null; then
                       echo -e "${green}[SUCCESS]${nc} DOFLinx is running!"
                   else
                       echo -e "${yellow}[WARNING]${nc} DOFLinx may not have started - check logs"
                   fi
                   break
                   ;;
               [Nn]* )
                   echo -e "${green}[INFO]${nc} DOFLinx will start on next reboot (after pixelweb)"
                   break
                   ;;
               * ) echo "Please answer yes or no.";;
           esac
       done
   else
       echo -e "${yellow}[INFO]${nc} Pixelweb is not currently running"
       echo -e "${yellow}[INFO]${nc} DOFLinx will start automatically on next reboot after pixelweb starts"
   fi

   while true; do
       read -p "Reboot Now? (y/n) " yn
       case $yn in
           [Yy]* ) reboot; break;;
           [Nn]* ) echo -e "${green}[INFO]${nc} Please reboot when you get a chance" && exit 0;;
           * ) echo "Please answer yes or no.";;
       esac
   done
else
   echo -e "${red}[ERROR]${nc} DOFLinx installation failed"
   exit 1
fi