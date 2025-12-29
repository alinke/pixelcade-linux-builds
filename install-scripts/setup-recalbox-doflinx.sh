#!/bin/bash
# DOFLinx installer for RecalBox
# Supports both arm64 and x64 architectures
# Note: Pixelcade (pixelweb) must be installed and running before DOFLinx

version=1
install_successful=true
RECALBOX_STARTUP="/etc/init.d/S99MyScript.py"

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
echo -e "       ${cyan}DOFLinx for RecalBox : Installer Version $version${nc}    "
echo -e ""
echo -e "This script will install and configure DOFLinx for in-game effects on RecalBox"
echo -e "DOFLinx will be installed in /etc/init.d/doflinx"
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

# Paths for RecalBox (matching setup-recalbox.sh pattern)
# pixelweb installs to /etc/init.d/pixelcade, so DOFLinx goes to /etc/init.d/doflinx
INSTALLPATH="/etc/init.d/"
DOFLINX_PATH="${INSTALLPATH}doflinx"
PIXELCADE_PATH="/etc/init.d/pixelcade"
ARTPATH="/recalbox/share/pixelcade-art/"

# Check if Pixelcade is installed
if [[ ! -f "${PIXELCADE_PATH}/pixelweb" ]]; then
    echo -e "${red}[ERROR]${nc} Pixelcade is not installed. Please run setup-recalbox.sh first."
    exit 1
fi

# Check if we have write permissions to the install path
if [[ ! -w "/etc/init.d" ]]; then
    echo -e "${red}[ERROR]${nc} No write permission to /etc/init.d."
    echo -e "${yellow}[INFO]${nc} Try running: mount -o remount,rw /"
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

if [[ ! -d "${DOFLINX_PATH}/temp" ]]; then
   mkdir -p ${DOFLINX_PATH}/temp
fi

echo -e "${cyan}[INFO]${nc} Installing DOFLinx Software..."

cd ${DOFLINX_PATH}/temp

# Download Base DOFLinx
doflinx_url="https://github.com/DOFLinx/DOFLinx-for-Linux/releases/download/doflinx/doflinx.zip"
echo -e "${green}[INFO]${nc} Downloading DOFLinx..."
wget -O "${DOFLINX_PATH}/temp/doflinx.zip" "$doflinx_url"

if [ $? -ne 0 ]; then
   echo -e "${red}[ERROR]${nc} Failed to download DOFLinx"
   install_successful=false
else
   echo -e "${green}[INFO]${nc} Extracting DOFLinx (overwriting existing files)..."
   unzip -o doflinx.zip -d ${DOFLINX_PATH}

   if [ $? -ne 0 ]; then
      echo -e "${red}[ERROR]${nc} Failed to unzip DOFLinx"
      install_successful=false
   else
      echo -e "${green}[INFO]${nc} Copying architecture-specific files (${machine_arch})..."
      cp -rf ${DOFLINX_PATH}/${machine_arch}/* ${DOFLINX_PATH}/

      if [ $? -ne 0 ]; then
         echo -e "${red}[ERROR]${nc} Failed to copy DOFLinx files"
         install_successful=false
      fi
   fi
fi

# Set execute permissions
echo -e "${green}[INFO]${nc} Setting permissions..."
chmod a+x ${DOFLINX_PATH}/DOFLinx
chmod a+x ${DOFLINX_PATH}/DOFLinxMsg

# Update DOFLinx.ini with correct paths for RecalBox
echo -e "${green}[INFO]${nc} Configuring DOFLinx.ini for RecalBox..."
if [[ -f "${DOFLINX_PATH}/config/DOFLinx.ini" ]]; then
    # Replace default paths with RecalBox paths
    sed -i -e "s|/home/arcade/doflinx|${DOFLINX_PATH}|g" ${DOFLINX_PATH}/config/DOFLinx.ini
    sed -i -e "s|/home/arcade/pixelcade|${ARTPATH}|g" ${DOFLINX_PATH}/config/DOFLinx.ini
    if [ $? -ne 0 ]; then
       echo -e "${red}[ERROR]${nc} Failed to edit DOFLinx.ini"
       install_successful=false
    fi
else
    echo -e "${yellow}[WARNING]${nc} DOFLinx.ini not found"
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
cd /etc/init.d/doflinx && ./DOFLinx PATH_INI=/etc/init.d/doflinx/config/ &
EOFSCRIPT
chmod +x ${DOFLINX_PATH}/doflinx.sh

# Add DOFLinx to RecalBox startup (S99MyScript.py)
# DOFLinx must start AFTER pixelweb
if [[ -f "$RECALBOX_STARTUP" ]]; then
    # Check if DOFLinx code is already present
    if grep -q "doflinx" "$RECALBOX_STARTUP"; then
        echo -e "${green}[INFO]${nc} DOFLinx startup code already present in $RECALBOX_STARTUP"
    else
        echo -e "${green}[INFO]${nc} Adding DOFLinx startup code to $RECALBOX_STARTUP..."

        # Create a backup first
        cp "$RECALBOX_STARTUP" "${RECALBOX_STARTUP}.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${green}[INFO]${nc} Backup created"

        # Check if pixelweb is in the startup script
        if grep -q "pixelweb" "$RECALBOX_STARTUP"; then
            # Add DOFLinx startup after pixelweb line
            # The doflinx.sh script itself waits for pixelweb, so we just need to call it after
            sed -i '/pixelweb.*&$/a\    # Start DOFLinx for in-game effects (waits for pixelweb internally)\n    /etc/init.d/doflinx/doflinx.sh \&' "$RECALBOX_STARTUP"

            if [ $? -eq 0 ]; then
                echo -e "${green}[SUCCESS]${nc} DOFLinx startup code added to $RECALBOX_STARTUP"
                echo -e "${green}[INFO]${nc} DOFLinx will start after pixelweb is running"
            else
                echo -e "${yellow}[WARNING]${nc} Failed to modify $RECALBOX_STARTUP automatically"
                echo -e "${yellow}[INFO]${nc} Please add the following line manually to $RECALBOX_STARTUP after the pixelweb line:"
                echo -e "    /etc/init.d/doflinx/doflinx.sh &"
            fi
        else
            echo -e "${yellow}[WARNING]${nc} pixelweb not found in $RECALBOX_STARTUP"
            echo -e "${yellow}[INFO]${nc} Please add the following line manually to $RECALBOX_STARTUP after pixelweb starts:"
            echo -e "    /etc/init.d/doflinx/doflinx.sh &"
        fi
    fi
else
    echo -e "${yellow}[WARNING]${nc} $RECALBOX_STARTUP not found"
    echo -e "${yellow}[INFO]${nc} DOFLinx will need to be started manually or added to your startup script"
    echo -e "${yellow}[INFO]${nc} To start manually (after pixelweb is running): /etc/init.d/doflinx/doflinx.sh"
fi

# Download RecalBox-specific DOFLinx.ini if available
echo -e "${green}[INFO]${nc} Checking for RecalBox-specific DOFLinx configuration..."
doflinx_ini_url="https://github.com/alinke/pixelcade-linux-builds/raw/main/recalbox/DOFLinx.ini"
if wget --spider "$doflinx_ini_url" 2>/dev/null; then
    echo -e "${green}[INFO]${nc} Downloading RecalBox-specific DOFLinx.ini..."
    wget -O "${DOFLINX_PATH}/config/DOFLinx.ini" "$doflinx_ini_url"
    if [ $? -eq 0 ]; then
        echo -e "${green}[SUCCESS]${nc} DOFLinx.ini configured for RecalBox"
    else
        echo -e "${yellow}[WARNING]${nc} Failed to download DOFLinx.ini - using default configuration"
    fi
else
    echo -e "${yellow}[INFO]${nc} No RecalBox-specific DOFLinx.ini available - using default with path substitutions"
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

# Cleanup
echo -e "${green}[INFO]${nc} Cleaning up temporary files..."
rm -rf ${DOFLINX_PATH}/temp
# Clean up architecture folders that are no longer needed
rm -rf ${DOFLINX_PATH}/arm64
rm -rf ${DOFLINX_PATH}/x64
rm -rf ${DOFLINX_PATH}/arm

if [[ $install_successful == "true" ]]; then
   echo -e ""
   if [[ $reinstall == "true" ]]; then
       echo -e "${green}[SUCCESS]${nc} DOFLinx reinstalled successfully for RecalBox!"
   else
       echo -e "${green}[SUCCESS]${nc} DOFLinx installed successfully for RecalBox!"
   fi
   echo -e ""
   echo -e "Installation Details:"
   echo -e "  Location: ${DOFLINX_PATH}/"
   echo -e "  Executable: ${DOFLINX_PATH}/DOFLinx"
   echo -e "  Config: ${DOFLINX_PATH}/config/DOFLinx.ini"
   echo -e "  Startup Script: ${DOFLINX_PATH}/doflinx.sh"
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
