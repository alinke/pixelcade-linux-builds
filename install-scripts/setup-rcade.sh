#!/bin/bash
# DOFLinx installer for R-Cade
#
# Usage: ./setup-rcade.sh [options]
#
# Options:
#   beta, --beta, -beta    Install beta version of DOFLinx
#   force, --force, -force Overwrite existing DOFLinx.ini and colours.ini config files
#                          (by default, existing config files are preserved)
#
# This script is organized to minimize overlay usage:
# 1. System space changes (/usr/bin, /etc) happen first
# 2. Overlay is saved with rcade-save.sh
# 3. User space changes (/rcade/share/) happen after overlay save

version=16
install_successful=true
RCADE_STARTUP="/etc/init.d/S10animationscreens"

NEWLINE=$'\n'
cyan='\033[0;36m'
red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'
nc='\033[0m'

# Parse command line arguments
beta=false
force=false
while [[ $# -gt 0 ]]; do
    case $1 in
        beta|--beta|-beta)
            beta=true
            shift
            ;;
        force|--force|-force)
            force=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

echo -e ""
echo -e "       ${cyan}Pixelcade & DOFLinx for R-Cade : Installer Version $version${nc}    "
if [[ "$beta" == "true" ]]; then
    echo -e "       ${cyan}*** BETA MODE ENABLED ***${nc}"
fi
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
   # Use pidof instead of pgrep (more reliable on R-Cade)
   doflinx_pids=$(pidof DOFLinx 2>/dev/null)
   if [[ -n "$doflinx_pids" ]]; then
     echo -e "${green}[INFO]${nc} Stopping running DOFLinx process(es): $doflinx_pids"
     DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 ${INSTALLPATH}doflinx/DOFLinxMsg QUIT 2>/dev/null
     sleep 2  # Give it time to stop gracefully
     # Force kill if still running
     doflinx_pids=$(pidof DOFLinx 2>/dev/null)
     if [[ -n "$doflinx_pids" ]]; then
         echo -e "${yellow}[INFO]${nc} DOFLinx still running - force killing..."
         kill -9 $doflinx_pids 2>/dev/null
         sleep 1  # Give system time to release the file
     fi
     # Final check
     doflinx_pids=$(pidof DOFLinx 2>/dev/null)
     if [[ -n "$doflinx_pids" ]]; then
         echo -e "${red}[WARNING]${nc} Could not stop DOFLinx (PIDs: $doflinx_pids) - installation may fail"
     else
         echo -e "${green}[INFO]${nc} DOFLinx stopped successfully"
     fi
   else
     echo -e "${green}[INFO]${nc} DOFLinx is not currently running"
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

# ============================================================================
# PHASE 1: SYSTEM SPACE CHANGES (saved to overlay)
# These changes go to /usr/bin and /etc which are in the overlay filesystem
# ============================================================================
echo -e ""
echo -e "${cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
echo -e "${cyan}[PHASE 1]${nc} System space changes (will be saved to overlay)"
echo -e "${cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"

# Stop Pixelcade before updating
echo -e "${green}[INFO]${nc} Stopping Pixelcade service..."
curl -s localhost:8080/quit >/dev/null 2>&1
sleep 2

# Update pixelweb binary in /usr/bin (SYSTEM SPACE)
echo -e "${green}[INFO]${nc} Updating Pixelcade binary to the latest version..."
cd /usr/bin

if [[ "$beta" == "true" ]]; then
    pixelweb_url="https://github.com/alinke/pixelcade-linux-builds/raw/main/beta/linux_${machine_arch}/pixelweb"
    if wget --spider "$pixelweb_url" 2>/dev/null; then
        echo -e "${cyan}[BETA]${nc} Downloading beta pixelweb for ${machine_arch}..."
        wget -O /usr/bin/pixelweb "$pixelweb_url"
        if [ $? -eq 0 ]; then
            chmod a+x /usr/bin/pixelweb
            echo -e "${green}[SUCCESS]${nc} Beta pixelweb binary updated successfully"
        else
            echo -e "${yellow}[WARNING]${nc} Failed to download beta pixelweb binary"
        fi
    else
        echo -e "${yellow}[WARNING]${nc} Beta pixelweb not available for ${machine_arch}, falling back to production version..."
        pixelweb_url="https://github.com/alinke/pixelcade-linux-builds/raw/main/linux_${machine_arch}/pixelweb"
        if wget --spider "$pixelweb_url" 2>/dev/null; then
            wget -O /usr/bin/pixelweb "$pixelweb_url"
            if [ $? -eq 0 ]; then
                chmod a+x /usr/bin/pixelweb
                echo -e "${green}[SUCCESS]${nc} pixelweb binary updated successfully"
            else
                echo -e "${yellow}[WARNING]${nc} Failed to download pixelweb binary"
            fi
        fi
    fi
else
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
fi

# Update startup scripts (SYSTEM SPACE)
# R-Cade has two different versions:
#   OLD: S10animationscreens contains pixelweb startup block directly (has "grep pixelweb")
#   NEW: S10animationscreens delegates to rcade-commands.sh start_screens (has "start_screens")
#        In NEW version, we modify rcade-commands.sh directly where pixelweb is launched
# We detect based on content, not filename

RCADE_COMMANDS="/rcade/scripts/rcade-commands.sh"

if [[ -f "$RCADE_STARTUP" ]]; then
    # Detect which version based on content
    if grep -q "start_screens" "$RCADE_STARTUP"; then
        startup_version="new"
        echo -e "${green}[INFO]${nc} Detected NEW R-Cade startup script (delegates to rcade-commands.sh)"
    elif grep -q "grep pixelweb" "$RCADE_STARTUP"; then
        startup_version="old"
        echo -e "${green}[INFO]${nc} Detected OLD R-Cade startup script (contains pixelweb block)"
    else
        startup_version="unknown"
        echo -e "${yellow}[WARNING]${nc} Unknown R-Cade startup script format"
    fi

    # Clean up any old backups in /etc/init.d (they waste overlay space)
    for backup in /etc/init.d/S10animationscreens.backup.*; do
        if [[ -f "$backup" ]]; then
            echo -e "${green}[INFO]${nc} Removing old backup from overlay: $backup"
            rm -f "$backup"
        fi
    done

    if [[ "$startup_version" == "new" ]]; then
        # NEW VERSION: Modify rcade-commands.sh where pixelweb is actually launched
        if [[ -f "$RCADE_COMMANDS" ]]; then
            # Check if DOFLinx code is already present in rcade-commands.sh
            if grep -q "Launch DOFLinx" "$RCADE_COMMANDS" || grep -q "doflinx.sh" "$RCADE_COMMANDS"; then
                echo -e "${green}[INFO]${nc} DOFLinx startup code already present in $RCADE_COMMANDS"
            else
                echo -e "${green}[INFO]${nc} Adding DOFLinx startup code to $RCADE_COMMANDS..."

                # Create a backup in user space (not overlay) to save overlay space
                mkdir -p ${INSTALLPATH}pixelcade/backups
                BACKUP_FILE="${INSTALLPATH}pixelcade/backups/rcade-commands.sh.backup.$(date +%Y%m%d_%H%M%S)"
                cp "$RCADE_COMMANDS" "$BACKUP_FILE"
                echo -e "${green}[INFO]${nc} Backup created: $BACKUP_FILE"

                # Insert DOFLinx startup after the pixelweb startup block
                # Match the fi that closes the pixelweb block and add DOFLinx after it
                awk '
                /if \[\[ "\$pixelcade" == "true" && -z \$\(ps \| grep pixelweb \| grep -v .grep.\) \]\]; then/ {
                    in_pixelweb_block=1
                }
                in_pixelweb_block && /^[[:space:]]*fi[[:space:]]*$/ {
                    print
                    print ""
                    print "\t# Launch DOFLinx after pixelweb starts"
                    print "\tif [[ \"$pixelcade\" == \"true\" && -f \"/rcade/share/doflinx/doflinx.sh\" ]]; then"
                    print "\t\techo \"Starting DOFLinx with 2 second delay...\" >> /tmp/pixelweb.log"
                    print "\t\tsleep 2"
                    print "\t\t/rcade/share/doflinx/doflinx.sh &"
                    print "\tfi"
                    in_pixelweb_block=0
                    next
                }
                { print }
                ' "$RCADE_COMMANDS" > "${RCADE_COMMANDS}.tmp"

                # Check if the awk command succeeded and the output file is not empty
                if [[ -s "${RCADE_COMMANDS}.tmp" ]]; then
                    mv "${RCADE_COMMANDS}.tmp" "$RCADE_COMMANDS"
                    chmod +x "$RCADE_COMMANDS"
                    echo -e "${green}[SUCCESS]${nc} DOFLinx startup code added to $RCADE_COMMANDS"
                else
                    echo -e "${yellow}[WARNING]${nc} Failed to modify $RCADE_COMMANDS - DOFLinx will need to be started manually"
                    rm -f "${RCADE_COMMANDS}.tmp"
                fi
            fi
        else
            echo -e "${yellow}[WARNING]${nc} $RCADE_COMMANDS not found - DOFLinx will need to be started manually"
        fi
    elif [[ "$startup_version" == "old" ]]; then
        # OLD VERSION: Modify S10animationscreens directly
        # Check if DOFLinx code is already present
        if grep -q "Launch DOFLinx" "$RCADE_STARTUP" || grep -q "doflinx.sh" "$RCADE_STARTUP"; then
            echo -e "${green}[INFO]${nc} DOFLinx startup code already present in $RCADE_STARTUP"
        else
            echo -e "${green}[INFO]${nc} Adding DOFLinx startup code to $RCADE_STARTUP..."

            # Create a backup in user space (not overlay) to save overlay space
            mkdir -p ${INSTALLPATH}pixelcade/backups
            BACKUP_FILE="${INSTALLPATH}pixelcade/backups/S10animationscreens.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$RCADE_STARTUP" "$BACKUP_FILE"
            echo -e "${green}[INFO]${nc} Backup created: $BACKUP_FILE"

            # Insert after pixelweb startup block
            awk '
            /if \[\[ "\$pixelcade" == "true" && -z \$\(ps \| grep pixelweb \| grep -v .grep.\) \]\]; then/ {
                in_pixelweb_block=1
            }
            in_pixelweb_block && /^[[:space:]]*fi[[:space:]]*$/ {
                print
                print ""
                print "\t# Launch DOFLinx after pixelweb starts"
                print "\tif [[ \"$pixelcade\" == \"true\" && -f \"/rcade/share/doflinx/doflinx.sh\" ]]; then"
                print "\t\techo \"Starting DOFLinx with 2 second delay...\" >> /tmp/pixelweb.log"
                print "\t\tsleep 2"
                print "\t\t/rcade/share/doflinx/doflinx.sh &"
                print "\tfi"
                in_pixelweb_block=0
                next
            }
            { print }
            ' "$RCADE_STARTUP" > "${RCADE_STARTUP}.tmp"

            # Check if the awk command succeeded and the output file is not empty
            if [[ -s "${RCADE_STARTUP}.tmp" ]]; then
                mv "${RCADE_STARTUP}.tmp" "$RCADE_STARTUP"
                chmod +x "$RCADE_STARTUP"
                echo -e "${green}[SUCCESS]${nc} DOFLinx startup code added to $RCADE_STARTUP"
            else
                echo -e "${yellow}[WARNING]${nc} Failed to modify $RCADE_STARTUP - DOFLinx will need to be started manually"
                rm -f "${RCADE_STARTUP}.tmp"
            fi
        fi
    else
        echo -e "${yellow}[WARNING]${nc} Could not determine startup script format - DOFLinx will need to be started manually"
    fi
else
    echo -e "${yellow}[WARNING]${nc} $RCADE_STARTUP not found - DOFLinx will need to be started manually"
fi

# ============================================================================
# SAVE OVERLAY - Commit system space changes
# ============================================================================
echo -e ""
echo -e "${cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
echo -e "${cyan}[OVERLAY]${nc} Saving system changes to overlay..."
echo -e "${cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
/rcade/scripts/rcade-save.sh

# ============================================================================
# PHASE 2: USER SPACE CHANGES (in /rcade/share/ - not saved to overlay)
# These changes go to /rcade/share which is user space and persists separately
# ============================================================================
echo -e ""
echo -e "${cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
echo -e "${cyan}[PHASE 2]${nc} User space changes (/rcade/share/ - persists separately)"
echo -e "${cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"

# Create necessary directories in user space
if [[ ! -d "${INSTALLPATH}doflinx" ]]; then
   echo -e "${green}[INFO]${nc} Creating DOFLinx directory..."
   mkdir -p ${INSTALLPATH}doflinx
fi

echo -e "${cyan}[INFO]${nc} Installing DOFLinx Software..."

# Create config directory
if [[ ! -d "${INSTALLPATH}doflinx/config" ]]; then
   mkdir -p ${INSTALLPATH}doflinx/config
fi

# Determine folders based on architecture
# Repository: https://github.com/DOFLinx/CurrentExecutable
# Beta folder only contains DOFLinx and DOFLinx.pdb - all other files come from stable
if [[ $machine_arch == "arm64" ]]; then
    stable_folder="Linux_arm64"
    beta_folder="Linux_arm64_beta"
elif [[ $machine_arch == "x64" ]]; then
    stable_folder="Linux_x64"
    beta_folder="Linux_x64_beta"
else
    echo -e "${red}[ERROR]${nc} Unsupported architecture: $machine_arch"
    install_successful=false
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
wget -O "${INSTALLPATH}doflinx/DOFLinx" "${main_url}/DOFLinx"
if [ $? -ne 0 ]; then
   echo -e "${red}[ERROR]${nc} Failed to download DOFLinx executable"
   install_successful=false
fi

echo -e "${green}[INFO]${nc} Downloading DOFLinx.pdb..."
wget -O "${INSTALLPATH}doflinx/DOFLinx.pdb" "${main_url}/DOFLinx.pdb"
if [ $? -ne 0 ]; then
   echo -e "${yellow}[WARNING]${nc} Failed to download DOFLinx.pdb"
fi

# Download supporting files from stable folder (these don't exist in beta folder)
echo -e "${green}[INFO]${nc} Downloading supporting files from ${stable_folder}..."

echo -e "${green}[INFO]${nc} Downloading DOFLinxMsg executable..."
wget -O "${INSTALLPATH}doflinx/DOFLinxMsg" "${stable_url}/DOFLinxMsg"
if [ $? -ne 0 ]; then
   echo -e "${red}[ERROR]${nc} Failed to download DOFLinxMsg executable"
   install_successful=false
fi

echo -e "${green}[INFO]${nc} Downloading DOFLinxMsg.pdb..."
wget -O "${INSTALLPATH}doflinx/DOFLinxMsg.pdb" "${stable_url}/DOFLinxMsg.pdb"
if [ $? -ne 0 ]; then
   echo -e "${yellow}[WARNING]${nc} Failed to download DOFLinxMsg.pdb"
fi

echo -e "${green}[INFO]${nc} Downloading keycodes..."
wget -O "${INSTALLPATH}doflinx/keycodes" "${stable_url}/keycodes"
if [ $? -ne 0 ]; then
   echo -e "${yellow}[WARNING]${nc} Failed to download keycodes"
fi

echo -e "${green}[INFO]${nc} Downloading HELP.txt..."
wget -O "${INSTALLPATH}doflinx/HELP.txt" "${stable_url}/HELP.txt"
if [ $? -ne 0 ]; then
   echo -e "${yellow}[WARNING]${nc} Failed to download HELP.txt"
fi

echo -e "${green}[INFO]${nc} Downloading DONATE.txt..."
wget -O "${INSTALLPATH}doflinx/DONATE.txt" "${stable_url}/DONATE.txt"
if [ $? -ne 0 ]; then
   echo -e "${yellow}[WARNING]${nc} Failed to download DONATE.txt"
fi

echo -e "${green}[INFO]${nc} Downloading DOFLinx Update Notes.txt..."
wget -O "${INSTALLPATH}doflinx/DOFLinx Update Notes.txt" "${stable_url}/DOFLinx%20Update%20Notes.txt"
if [ $? -ne 0 ]; then
   echo -e "${yellow}[WARNING]${nc} Failed to download DOFLinx Update Notes.txt"
fi

# Set execute permissions
echo -e "${green}[INFO]${nc} Setting permissions..."
chmod a+x ${INSTALLPATH}doflinx/DOFLinx
chmod a+x ${INSTALLPATH}doflinx/DOFLinxMsg
chmod a+x ${INSTALLPATH}doflinx/keycodes 2>/dev/null

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

# Download configuration files from pixelcade-linux-builds
echo -e "${green}[INFO]${nc} Downloading configuration files..."

# Smart update for DOFLinx.ini
# - If user never modified their config, update to latest version automatically
# - If user has customizations, preserve them and save new version as .latest
# - --force flag overrides and always overwrites
doflinx_ini_url="https://github.com/alinke/pixelcade-linux-builds/raw/main/rcade/DOFLinx.ini"
config_dir="${INSTALLPATH}doflinx/config"
doflinx_ini="${config_dir}/DOFLinx.ini"
doflinx_ini_hash="${config_dir}/.DOFLinx.ini.original.md5"
doflinx_ini_tmp="${config_dir}/DOFLinx.ini.tmp"

echo -e "${green}[INFO]${nc} Checking DOFLinx.ini..."
wget -q -O "$doflinx_ini_tmp" "$doflinx_ini_url"
if [ $? -ne 0 ]; then
   echo -e "${yellow}[WARNING]${nc} Failed to download DOFLinx.ini"
   rm -f "$doflinx_ini_tmp"
else
   new_hash=$(md5sum "$doflinx_ini_tmp" 2>/dev/null | cut -d' ' -f1)
   current_hash=$(md5sum "$doflinx_ini" 2>/dev/null | cut -d' ' -f1)
   original_hash=$(cat "$doflinx_ini_hash" 2>/dev/null)

   if [[ "$force" == "true" ]]; then
      # Force flag - always overwrite
      echo -e "${yellow}[FORCE]${nc} Overwriting DOFLinx.ini..."
      mv "$doflinx_ini_tmp" "$doflinx_ini"
      echo "$new_hash" > "$doflinx_ini_hash"
      rm -f "${config_dir}/DOFLinx.ini.latest"  # Clean up any old .latest file
      echo -e "${green}[SUCCESS]${nc} DOFLinx.ini updated"
   elif [[ ! -f "$doflinx_ini" ]]; then
      # Fresh install - no existing file
      echo -e "${green}[INFO]${nc} Installing DOFLinx.ini..."
      mv "$doflinx_ini_tmp" "$doflinx_ini"
      echo "$new_hash" > "$doflinx_ini_hash"
      echo -e "${green}[SUCCESS]${nc} DOFLinx.ini installed"
   elif [[ "$new_hash" == "$current_hash" ]]; then
      # Already up to date
      echo -e "${green}[INFO]${nc} DOFLinx.ini is already up to date"
      rm -f "$doflinx_ini_tmp"
   elif [[ "$current_hash" == "$original_hash" ]]; then
      # User never modified - safe to update
      echo -e "${green}[INFO]${nc} Updating DOFLinx.ini to latest version..."
      mv "$doflinx_ini_tmp" "$doflinx_ini"
      echo "$new_hash" > "$doflinx_ini_hash"
      rm -f "${config_dir}/DOFLinx.ini.latest"  # Clean up any old .latest file
      echo -e "${green}[SUCCESS]${nc} DOFLinx.ini updated"
   else
      # User has customizations - preserve them
      echo -e ""
      echo -e "${cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
      echo -e "${yellow}[NOTICE]${nc} You have customized DOFLinx.ini - ${green}preserving your changes${nc}"
      echo -e "${yellow}[NOTICE]${nc} New version saved as: ${cyan}${config_dir}/DOFLinx.ini.latest${nc}"
      echo -e "${yellow}[NOTICE]${nc} Compare and merge any new settings you need"
      echo -e "${cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${nc}"
      echo -e ""
      mv "$doflinx_ini_tmp" "${config_dir}/DOFLinx.ini.latest"
   fi
fi

# Smart update for colours.ini (same logic as DOFLinx.ini)
colours_ini_url="https://github.com/alinke/pixelcade-linux-builds/raw/main/rcade/colours.ini"
colours_ini="${config_dir}/colours.ini"
colours_ini_hash="${config_dir}/.colours.ini.original.md5"
colours_ini_tmp="${config_dir}/colours.ini.tmp"

echo -e "${green}[INFO]${nc} Checking colours.ini..."
wget -q -O "$colours_ini_tmp" "$colours_ini_url"
if [ $? -ne 0 ]; then
   echo -e "${yellow}[WARNING]${nc} Failed to download colours.ini"
   rm -f "$colours_ini_tmp"
else
   new_hash=$(md5sum "$colours_ini_tmp" 2>/dev/null | cut -d' ' -f1)
   current_hash=$(md5sum "$colours_ini" 2>/dev/null | cut -d' ' -f1)
   original_hash=$(cat "$colours_ini_hash" 2>/dev/null)

   if [[ "$force" == "true" ]]; then
      echo -e "${yellow}[FORCE]${nc} Overwriting colours.ini..."
      mv "$colours_ini_tmp" "$colours_ini"
      echo "$new_hash" > "$colours_ini_hash"
      rm -f "${config_dir}/colours.ini.latest"
      echo -e "${green}[SUCCESS]${nc} colours.ini updated"
   elif [[ ! -f "$colours_ini" ]]; then
      echo -e "${green}[INFO]${nc} Installing colours.ini..."
      mv "$colours_ini_tmp" "$colours_ini"
      echo "$new_hash" > "$colours_ini_hash"
      echo -e "${green}[SUCCESS]${nc} colours.ini installed"
   elif [[ "$new_hash" == "$current_hash" ]]; then
      echo -e "${green}[INFO]${nc} colours.ini is already up to date"
      rm -f "$colours_ini_tmp"
   elif [[ "$current_hash" == "$original_hash" ]]; then
      echo -e "${green}[INFO]${nc} Updating colours.ini to latest version..."
      mv "$colours_ini_tmp" "$colours_ini"
      echo "$new_hash" > "$colours_ini_hash"
      rm -f "${config_dir}/colours.ini.latest"
      echo -e "${green}[SUCCESS]${nc} colours.ini updated"
   else
      echo -e "${yellow}[NOTICE]${nc} You have customized colours.ini - ${green}preserving your changes${nc}"
      echo -e "${yellow}[NOTICE]${nc} New version saved as: ${cyan}${config_dir}/colours.ini.latest${nc}"
      mv "$colours_ini_tmp" "${config_dir}/colours.ini.latest"
   fi
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

# Update RetroArch configuration for RetroAchievements (in user space)
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

if [[ $install_successful == "true" ]]; then
   echo -e ""
   if [[ $reinstall == "true" ]]; then
       echo -e "${green}[SUCCESS]${nc} DOFLinx reinstalled successfully for R-Cade!"
   else
       echo -e "${green}[SUCCESS]${nc} DOFLinx installed successfully for R-Cade!"
   fi
   if [[ "$beta" == "true" ]]; then
       echo -e "${cyan}[INFO]${nc} Beta version of pixelweb was installed"
   fi
   echo -e ""
   echo -e "Installation Details:"
   echo -e "  Location: ${INSTALLPATH}doflinx/"
   echo -e "  Executable: ${INSTALLPATH}doflinx/DOFLinx"
   echo -e "  Config: ${INSTALLPATH}doflinx/config/DOFLinx.ini"
   echo -e "  Startup Script: ${INSTALLPATH}doflinx/doflinx.sh"
   if [[ "$using_beta" == "true" ]]; then
       echo -e "  DOFLinx Version: ${yellow}BETA${nc} (${beta_folder})"
   else
       echo -e "  DOFLinx Version: Stable (${stable_folder})"
   fi
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