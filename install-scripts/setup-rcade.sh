#!/bin/bash
# DOFLinx installer for R-Cade

version=3
install_successful=true
RCADE_STARTUP="/etc/init.d/S10animationscreens"

NEWLINE=$'\n'
cyan='\033[0;36m'
red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'
nc='\033[0m'

function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

echo -e ""
echo -e "       ${cyan}Pixelcade & DOFLinx for R-Cade : Installer Version $version${nc}    "
echo -e ""
echo -e "This script will install and configure Pixelcade & DOFLinx in game effects"
echo -e "Pixelcade artwork will be installed in /rcade/share/pixelcade"
echo -e "DOFLinx will be installed in /rcade/share/doflinx"
echo -e ""
pause

INSTALLPATH="/rcade/share/"

# Check if we have write permissions to the install path
if [[ ! -w "/rcade/share" ]]; then
    echo -e "${red}[ERROR]${nc} No write permission to /rcade/share."
    exit 1
fi

# If this is an existing installation then DOFLinx could already be running
if test -f ${INSTALLPATH}doflinx/DOFLinx; then
   echo -e "${yellow}[INFO]${nc} Existing DOFLinx installation found - will overwrite and reinstall"
   if pgrep -x "DOFLinx" > /dev/null; then
     echo -e "${green}[INFO]${nc} Stopping running DOFLinx process"
     ${INSTALLPATH}doflinx/DOFLinxMsg QUIT
     sleep 2  # Give it time to stop
   fi
   echo -e "${green}[INFO]${nc} Proceeding with overwrite installation..."
   reinstall=true
else
   echo -e "${green}[INFO]${nc} Fresh DOFLinx installation"
   reinstall=false
fi

# Architecture detection for R-Cade
machine_arch="default"

if uname -m | grep -q 'armv6'; then
   echo -e "${yellow}arm_v6 Detected...${nc}"
   machine_arch=arm_v6
fi

if uname -m | grep -q 'armv7'; then
   echo -e "${yellow}arm_v7 Detected...${nc}"
   machine_arch=arm_v7
fi

if uname -m | grep -q 'aarch32'; then
   echo -e "${yellow}aarch32 Detected...${nc}"
   machine_arch=arm_v7
fi

if uname -m | grep -q 'aarch64'; then
   echo -e "${green}[INFO]${nc} aarch64 Detected..."
   machine_arch=arm64
fi

if uname -m | grep -q 'x86'; then
   if uname -m | grep -q 'x86_64'; then
      echo -e "${green}[INFO]${nc} x86 64-bit Detected..."
      machine_arch=x64
   else
      echo -e "${red}[ERROR]${nc} x86 32-bit Detected...not supported"
      machine_arch=386
   fi
fi

if uname -m | grep -q 'amd64'; then
   echo -e "${green}[INFO]${nc} x86 64-bit Detected..."
   machine_arch=x64
fi

# Hardware detection for optimization
if test -f /proc/device-tree/model; then
   if cat /proc/device-tree/model | grep -q 'Raspberry Pi 3'; then
      echo -e "${yellow}Raspberry Pi 3 detected...${nc}"
      pi3=true
   fi
   if cat /proc/device-tree/model | grep -q 'Pi 4'; then
      echo -e "${yellow}Raspberry Pi 4 detected...${nc}"
      pi4=true
   fi
   if cat /proc/device-tree/model | grep -q 'Pi Zero W'; then
      echo -e "${yellow}Raspberry Pi Zero detected...${nc}"
      pizero=true
   fi
   if cat /proc/device-tree/model | grep -q 'ODROID-N2'; then
      echo -e "${yellow}ODroid N2 or N2+ detected...${nc}"
      odroidn2=true
   fi
fi

if [[ $machine_arch == "default" ]]; then
  echo -e "${red}[ERROR]${nc} Your device platform WAS NOT detected"
  echo -e "${yellow}[WARNING]${nc} Guessing that you are on x64 but be aware DOFLinx may not work"
  machine_arch=x64
fi

# Create necessary directories
if [[ ! -d "${INSTALLPATH}doflinx" ]]; then
   echo -e "${green}[INFO]${nc} Creating DOFLinx directory..."
   mkdir -p ${INSTALLPATH}doflinx
fi

if [[ ! -d "${INSTALLPATH}doflinx/temp" ]]; then
   mkdir -p ${INSTALLPATH}doflinx/temp
fi

echo -e "${cyan}[INFO]${nc} Installing DOFLinx Software..."

cd ${INSTALLPATH}doflinx/temp

# Download Base DOFLinx
doflinx_url=https://github.com/DOFLinx/DOFLinx-for-Linux/releases/download/doflinx/doflinx.zip
echo -e "${green}[INFO]${nc} Downloading DOFLinx..."
wget -O "${INSTALLPATH}doflinx/temp/doflinx.zip" "$doflinx_url"

if [ $? -ne 0 ]; then
   echo -e "${red}[ERROR]${nc} Failed to download DOFLinx"
   install_successful=false
else
   echo -e "${green}[INFO]${nc} Extracting DOFLinx (overwriting existing files)..."
   unzip -o doflinx.zip -d ${INSTALLPATH}doflinx
   
   if [ $? -ne 0 ]; then
      echo -e "${red}[ERROR]${nc} Failed to unzip DOFLinx"
      install_successful=false
   else
      echo -e "${green}[INFO]${nc} Copying architecture-specific files (${machine_arch})..."
      cp -rf ${INSTALLPATH}doflinx/${machine_arch}/* ${INSTALLPATH}doflinx/
      
      if [ $? -ne 0 ]; then
         echo -e "${red}[ERROR]${nc} Failed to copy DOFLinx files"
         install_successful=false
      fi
   fi
fi

# Set execute permissions
echo -e "${green}[INFO]${nc} Setting permissions..."
chmod a+x ${INSTALLPATH}doflinx/DOFLinx
chmod a+x ${INSTALLPATH}doflinx/DOFLinxMsg

# Update DOFLinx.ini with correct paths for R-Cade
echo -e "${green}[INFO]${nc} Configuring DOFLinx.ini for R-Cade..."
if [[ -f "${INSTALLPATH}doflinx/config/DOFLinx.ini" ]]; then
    sed -i -e "s|/home/arcade/|${INSTALLPATH}|g" ${INSTALLPATH}doflinx/config/DOFLinx.ini
    if [ $? -ne 0 ]; then
       echo -e "${red}[ERROR]${nc} Failed to edit DOFLinx.ini"
       install_successful=false
    fi
else
    echo -e "${yellow}[WARNING]${nc} DOFLinx.ini not found"
fi

# Create DOFLinx startup script only if it doesn't exist
if [[ ! -f "${INSTALLPATH}doflinx/doflinx.sh" ]]; then
    echo -e "${green}[INFO]${nc} Creating DOFLinx startup script..."
    cat > ${INSTALLPATH}doflinx/doflinx.sh << 'EOF'
#!/bin/bash
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
cd /rcade/share/doflinx && ./DOFLinx &
EOF
    chmod +x ${INSTALLPATH}doflinx/doflinx.sh
else
    echo -e "${green}[INFO]${nc} DOFLinx startup script already exists, skipping creation..."
fi

# Lastly add doflinx to RCade startup
# /etc/init.d/S10animationscreens

# Check if the S10animationscreens file exists
if [[ -f "$RCADE_STARTUP" ]]; then
    # Check if DOFLinx code is already present
    if grep -q "Launch DOFLinx if pixelcade was started" "$RCADE_STARTUP"; then
        echo -e "${green}[INFO]${nc} DOFLinx startup code already present in $RCADE_STARTUP"
    else
        echo -e "${green}[INFO]${nc} Adding DOFLinx startup code to $RCADE_STARTUP..."
        
        # Create a backup first
        cp "$RCADE_STARTUP" "${RCADE_STARTUP}.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${green}[INFO]${nc} Backup created: ${RCADE_STARTUP}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Use awk to insert the DOFLinx code after the pixelweb startup block
        awk '
        /if \[\[ "\$pixelcade" == "true" && -z \$\(ps \| grep pixelweb \| grep -v .grep.\) \]\]; then/ {
            in_pixelweb_block=1
        }
        {
            print
        }
        in_pixelweb_block && /^[ \t]*fi[ \t]*$/ {
            print ""
            print "\t# Launch DOFLinx if pixelcade was started"
            print "\tif [[ \"$pixelcade\" == \"true\" && -f \"/rcade/share/doflinx/doflinx.sh\" ]]; then"
            print "\t\techo \"Starting DOFLinx with 2 second delay...\" >> /tmp/pixelweb.log"
            print "\t\tsleep 2"
            print "\t\t/rcade/share/doflinx/doflinx.sh &"
            print "\tfi"
            in_pixelweb_block=0
        }
        ' "$RCADE_STARTUP" > "${RCADE_STARTUP}.tmp"
        
        # Check if the awk command succeeded and the output file is not empty
        if [[ -s "${RCADE_STARTUP}.tmp" ]]; then
            # Replace the original file with the modified version
            mv "${RCADE_STARTUP}.tmp" "$RCADE_STARTUP"
            
            # Make sure the file is executable
            chmod +x "$RCADE_STARTUP"
            
            echo -e "${green}[SUCCESS]${nc} DOFLinx startup code added to $RCADE_STARTUP"
        else
            echo -e "${yellow}[WARNING]${nc} Failed to modify $RCADE_STARTUP - DOFLinx will need to be started manually"
            rm -f "${RCADE_STARTUP}.tmp"
        fi
    fi
else
    echo -e "${yellow}[WARNING]${nc} $RCADE_STARTUP not found - DOFLinx will need to be started manually"
fi

# Stop Pixelcade before updating
echo -e "${green}[INFO]${nc} Stopping Pixelcade service..."
curl -s localhost:8080/quit >/dev/null 2>&1
sleep 2

# Update pixelweb binary
echo -e "${green}[INFO]${nc} Updating Pixelcade binary to the latest version..."
cd /usr/bin

pixelweb_url="https://github.com/alinke/pixelcade-linux-builds/raw/main/linux_${machine_arch}/pixelweb"

if wget --spider "$pixelweb_url" 2>/dev/null; then
    echo -e "${green}[INFO]${nc} Downloading pixelweb for ${machine_arch}..."
    wget -O /usr/bin/pixelweb "$pixelweb_url"
    
    if [ $? -eq 0 ]; then
        chmod a+x /usr/bin/pixelweb
        echo -e "${green}[SUCCESS]${nc} pixelweb binary updated successfully"
    else
        echo -e "${yellow}[WARNING]${nc} Failed to download pixelweb binary"
    fi
else
    echo -e "${yellow}[WARNING]${nc} pixelweb binary not available for architecture ${machine_arch}"
fi

#Download and replace DOFLinx.ini with an R-Cade specific version
echo -e "${green}[INFO]${nc} Downloading default DOFLinx.ini configuration for R-Cade..."
doflinx_ini_url="https://github.com/alinke/pixelcade-linux-builds/raw/main/rcade/DOFLinx.ini"

if wget -O "${INSTALLPATH}doflinx/config/DOFLinx.ini" "$doflinx_ini_url" 2>/dev/null; then
    echo -e "${green}[SUCCESS]${nc} DOFLinx.ini configured for R-Cade"
else
    echo -e "${yellow}[WARNING]${nc} Failed to download DOFLinx.ini - you may need to configure it manually"
fi

# Update Pixelcade artwork and DOFLinx .MAME files
echo -e "${green}[INFO]${nc} Updating Pixelcade artwork and DOFLinx .MAME files..."
cd /usr/bin
./pixelweb -p /rcade/share/pixelcade -update-artwork
# Let's also force and update the latest DOFLinx MAME files too because it'll skip if artwork is already up to date
./pixelweb -p /rcade/share/pixelcade -update-doflinx

if [ $? -eq 0 ]; then
    echo -e "${green}[SUCCESS]${nc} Pixelcade artwork and DOFLinx .MAME files updated"
else
    echo -e "${yellow}[WARNING]${nc} Failed to update artwork - you can manually run: ./pixelweb -p /rcade/share/pixelcade -update-artwork"
fi

# Update RetroArch configuration for RetroAchievements
echo -e "${green}[INFO]${nc} Configuring RetroArch for RetroAchievements..."
RETROARCH_CFG="/rcade/share/configs/retroarch/retroarch.cfg"

if [[ -f "$RETROARCH_CFG" ]]; then
    # Create a backup
    cp "$RETROARCH_CFG" "${RETROARCH_CFG}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Function to update or add a setting
    update_setting() {
        local setting="$1"
        local value="$2"
        local file="$3"
        
        if grep -q "^${setting} =" "$file"; then
            # Setting exists, update it
            sed -i "s|^${setting} =.*|${setting} = ${value}|" "$file"
        else
            # Setting doesn't exist, append it
            echo "${setting} = ${value}" >> "$file"
        fi
    }
    
    # Update the three RetroAchievements settings
    update_setting "cheevos_enable" '"true"' "$RETROARCH_CFG"
    update_setting "cheevos_hardcore_mode_enable" '"false"' "$RETROARCH_CFG"
    update_setting "cheevos_start_active" '"true"' "$RETROARCH_CFG"
    
    echo -e "${green}[SUCCESS]${nc} RetroArch configured for RetroAchievements"
else
    echo -e "${yellow}[WARNING]${nc} RetroArch config file not found at $RETROARCH_CFG"
fi

# Cleanup
echo -e "${green}[INFO]${nc} Cleaning up temporary files..."
cd ${INSTALLPATH}
rm -rf ${INSTALLPATH}doflinx/temp

# Update the overlay
echo -e "${green}[INFO]${nc} Updating R-Cade overlay..."
/rcade/scripts/rcade-save.sh

if [[ $install_successful == "true" ]]; then
   echo -e ""
   if [[ $reinstall == "true" ]]; then
       echo -e "${green}[SUCCESS]${nc} DOFLinx reinstalled successfully for R-Cade!"
   else
       echo -e "${green}[SUCCESS]${nc} DOFLinx installed successfully for R-Cade!"
   fi
   echo -e ""
   echo -e "Installation Details:"
   echo -e "  Location: ${INSTALLPATH}doflinx/"
   echo -e "  Executable: ${INSTALLPATH}doflinx/DOFLinx"
   echo -e "  Config: ${INSTALLPATH}doflinx/config/DOFLinx.ini"
   echo -e "  Startup Script: ${INSTALLPATH}doflinx/doflinx.sh"
   echo -e ""
   echo -e "${green}[INFO]${nc} Architecture: $machine_arch"
   echo -e "${green}[INFO]${nc} DOFLinx will be started automatically when Pixelcade is enabled"
   echo -e "${green}[INFO]${nc} You may need to customize settings in config/DOFLinx.ini for your setup"
   echo -e ""
   echo -e "Resources:"
   echo -e "  Documentation: https://doflinx.github.io/docs/"
   echo -e "  Support: http://www.vpforums.org/index.php?showforum=104"
   echo -e ""
   echo -e "${cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
   echo -e "${green}[IMPORTANT]${nc} Please reboot your R-Cade system now to complete the installation"
   echo -e "${cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
   echo -e ""
   echo -e "After rebooting, access the Pixelcade Companion Web UI at:"
   echo -e "  ${cyan}http://rcade.local:8080${nc}"
   echo -e "  or"
   echo -e "  ${cyan}http://<Your RCade IP Address>:8080${nc}"
   echo -e ""
else
   echo -e "${red}[ERROR]${nc} DOFLinx installation failed"
   exit 1
fi
