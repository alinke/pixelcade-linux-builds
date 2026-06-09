#!/bin/bash
# DOFLinx-only installer for R-Cade
# Called by the Pixelcade Companion when DOFLinx is not installed.
#
# Usage: ./setup-rcade-doflinx.sh [options]
#
# Options:
#   beta, --beta, -beta    Install beta version of DOFLinx
#   force, --force, -force Overwrite existing DOFLinx.ini and colours.ini config files

version=3
install_successful=true
RCADE_STARTUP="/etc/init.d/S10animationscreens"
RCADE_COMMANDS="/rcade/scripts/rcade-commands.sh"
INSTALLPATH="/rcade/share/"

cyan='\033[0;36m'
red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'
nc='\033[0m'

beta=false
force=false
while [[ $# -gt 0 ]]; do
    case $1 in
        beta|--beta|-beta) beta=true; shift ;;
        force|--force|-force) force=true; shift ;;
        *) shift ;;
    esac
done

echo -e ""
echo -e "       ${cyan}Pixelcade DOFLinx for R-Cade : Installer Version $version${nc}"
if [[ "$beta" == "true" ]]; then
    echo -e "       ${cyan}*** BETA MODE ENABLED ***${nc}"
fi
echo -e ""

# Write permission check
if [[ ! -w "/rcade/share" ]]; then
    echo -e "${red}[ERROR]${nc} No write permission to /rcade/share"
    exit 1
fi

# Stop running DOFLinx if present (reinstall path)
reinstall=false
if test -f ${INSTALLPATH}doflinx/DOFLinx; then
    echo -e "${yellow}[INFO]${nc} Existing DOFLinx installation found - will overwrite and reinstall"
    reinstall=true
    doflinx_pids=$(pidof DOFLinx 2>/dev/null)
    if [[ -n "$doflinx_pids" ]]; then
        echo -e "${green}[INFO]${nc} Stopping running DOFLinx process(es): $doflinx_pids"
        DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 ${INSTALLPATH}doflinx/DOFLinxMsg QUIT 2>/dev/null
        sleep 2
        doflinx_pids=$(pidof DOFLinx 2>/dev/null)
        if [[ -n "$doflinx_pids" ]]; then
            echo -e "${yellow}[INFO]${nc} DOFLinx still running - force killing..."
            kill -9 $doflinx_pids 2>/dev/null
            sleep 1
        fi
        doflinx_pids=$(pidof DOFLinx 2>/dev/null)
        if [[ -n "$doflinx_pids" ]]; then
            echo -e "${red}[WARNING]${nc} Could not stop DOFLinx (PIDs: $doflinx_pids) - installation may fail"
        else
            echo -e "${green}[INFO]${nc} DOFLinx stopped successfully"
        fi
    else
        echo -e "${green}[INFO]${nc} DOFLinx is not currently running"
    fi
else
    echo -e "${green}[INFO]${nc} Fresh DOFLinx installation"
fi

# Architecture detection
machine_arch="default"
if uname -m | grep -q 'aarch64'; then
    echo -e "${green}[INFO]${nc} aarch64 Detected..."
    machine_arch=arm64
elif uname -m | grep -q 'armv7\|aarch32'; then
    echo -e "${yellow}[INFO]${nc} arm_v7 Detected..."
    machine_arch=arm_v7
elif uname -m | grep -q 'armv6'; then
    echo -e "${yellow}[INFO]${nc} arm_v6 Detected..."
    machine_arch=arm_v6
elif uname -m | grep -q 'x86_64\|amd64'; then
    echo -e "${green}[INFO]${nc} x86_64 Detected..."
    machine_arch=x64
elif uname -m | grep -q 'x86'; then
    echo -e "${red}[ERROR]${nc} x86 32-bit not supported"
    machine_arch=386
fi

if [[ $machine_arch == "default" ]]; then
    echo -e "${yellow}[WARNING]${nc} Architecture not detected - guessing x64"
    machine_arch=x64
fi

# RCade version detection — determines pixelweb path and whether startup injection is needed.
# RCade 2.0.8+ handles DOFLinx startup via the system; no injection needed.
rcade_new_version=false
es_ver=$(emulationstation --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [[ -n "$es_ver" ]]; then
    IFS='.' read -r _es_major _es_minor _es_patch <<< "$es_ver"
    if [[ "$_es_major" -gt 2 ]] || \
       [[ "$_es_major" -eq 2 && "$_es_minor" -gt 0 ]] || \
       [[ "$_es_major" -eq 2 && "$_es_minor" -eq 0 && "$_es_patch" -ge 8 ]]; then
        rcade_new_version=true
    elif [[ "$_es_major" -eq 2 && "$_es_minor" -eq 0 && "$_es_patch" -eq 7 ]]; then
        # Beta: 2.0.7 with kernel 6.19.0 behaves like 2.0.8+
        _kernel_ver=$(uname -a | awk '{print $3}')
        if [[ "$_kernel_ver" == "6.19.0" ]]; then
            rcade_new_version=true
        fi
    fi
fi

if [[ "$rcade_new_version" == "true" ]]; then
    pixelweb_path="/rcade/share/pixelcade/pixelweb"
else
    pixelweb_path="/usr/bin/pixelweb"
fi

# ============================================================================
# PHASE 1: Wire DOFLinx into the startup script (system space if old-style)
# ============================================================================
echo -e ""
echo -e "${cyan}[PHASE 1]${nc} Configuring startup scripts..."

startup_needs_overlay=false

if [[ "$rcade_new_version" == "true" ]]; then
    echo -e "${green}[INFO]${nc} Skipping startup script modification (RCade 2.0.8+: Pixelcade and DOFLinx startup are already handled by the system)"
elif [[ -f "$RCADE_STARTUP" ]]; then
    if grep -q "start_screens" "$RCADE_STARTUP"; then
        startup_version="new"
        echo -e "${green}[INFO]${nc} Detected NEW R-Cade startup (delegates to rcade-commands.sh)"
    elif grep -q "grep pixelweb" "$RCADE_STARTUP"; then
        startup_version="old"
        echo -e "${green}[INFO]${nc} Detected OLD R-Cade startup (direct pixelweb block)"
    else
        startup_version="unknown"
        echo -e "${yellow}[WARNING]${nc} Unknown startup script format"
    fi

    # If DOFLinx is in both scripts, remove it from S10animationscreens
    if grep -q "doflinx" "$RCADE_STARTUP" && [[ -f "$RCADE_COMMANDS" ]] && grep -q "doflinx" "$RCADE_COMMANDS"; then
        echo -e "${yellow}[INFO]${nc} DOFLinx found in both startup files - removing from S10animationscreens..."
        awk '/# Launch DOFLinx/{skip=1; next} skip && /^[[:space:]]*;;/{skip=0; print; next} !skip{print}' \
            "$RCADE_STARTUP" > "${RCADE_STARTUP}.tmp"
        if [[ -s "${RCADE_STARTUP}.tmp" ]]; then
            mv "${RCADE_STARTUP}.tmp" "$RCADE_STARTUP"
            chmod +x "$RCADE_STARTUP"
            startup_needs_overlay=true
            echo -e "${green}[SUCCESS]${nc} DOFLinx removed from S10animationscreens"
        else
            rm -f "${RCADE_STARTUP}.tmp"
        fi
    fi

    if [[ "$startup_version" == "new" ]]; then
        if [[ -f "$RCADE_COMMANDS" ]]; then
            if grep -q "Launch DOFLinx\|doflinx.sh" "$RCADE_COMMANDS"; then
                echo -e "${green}[INFO]${nc} DOFLinx startup already present in rcade-commands.sh"
            else
                echo -e "${green}[INFO]${nc} Adding DOFLinx startup to rcade-commands.sh..."
                mkdir -p ${INSTALLPATH}pixelcade/backups
                cp "$RCADE_COMMANDS" "${INSTALLPATH}pixelcade/backups/rcade-commands.sh.backup.$(date +%Y%m%d_%H%M%S)"
                awk '
                /if \[\[ "\$pixelcade" == "true" && -z \$\(ps \| grep pixelweb \| grep -v .grep.\) \]\]; then/ {
                    in_pixelweb_block=1
                }
                in_pixelweb_block && /^[[:space:]]*fi[[:space:]]*$/ {
                    print
                    print ""
                    print "\t# Launch DOFLinx after pixelweb starts"
                    print "\tif [[ \"$pixelcade\" == \"true\" && -f \"/rcade/share/doflinx/doflinx.sh\" ]]; then"
                    print "\t\techo \"Starting DOFLinx with 30 second delay...\" >> /tmp/pixelweb.log"
                    print "\t\tsleep 30"
                    print "\t\t/rcade/share/doflinx/doflinx.sh &"
                    print "\tfi"
                    in_pixelweb_block=0
                    next
                }
                { print }
                ' "$RCADE_COMMANDS" > "${RCADE_COMMANDS}.tmp"
                if [[ -s "${RCADE_COMMANDS}.tmp" ]]; then
                    mv "${RCADE_COMMANDS}.tmp" "$RCADE_COMMANDS"
                    chmod +x "$RCADE_COMMANDS"
                    echo -e "${green}[SUCCESS]${nc} DOFLinx startup added to rcade-commands.sh"
                else
                    rm -f "${RCADE_COMMANDS}.tmp"
                    echo -e "${yellow}[WARNING]${nc} Failed to modify rcade-commands.sh - DOFLinx will need to be started manually"
                fi
            fi
        else
            echo -e "${yellow}[WARNING]${nc} rcade-commands.sh not found - DOFLinx will need to be started manually"
        fi
    elif [[ "$startup_version" == "old" ]]; then
        if grep -q "Launch DOFLinx\|doflinx.sh" "$RCADE_STARTUP"; then
            echo -e "${green}[INFO]${nc} DOFLinx startup already present in S10animationscreens"
        else
            echo -e "${green}[INFO]${nc} Adding DOFLinx startup to S10animationscreens..."
            mkdir -p ${INSTALLPATH}pixelcade/backups
            cp "$RCADE_STARTUP" "${INSTALLPATH}pixelcade/backups/S10animationscreens.backup.$(date +%Y%m%d_%H%M%S)"
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
            if [[ -s "${RCADE_STARTUP}.tmp" ]]; then
                mv "${RCADE_STARTUP}.tmp" "$RCADE_STARTUP"
                chmod +x "$RCADE_STARTUP"
                startup_needs_overlay=true
                echo -e "${green}[SUCCESS]${nc} DOFLinx startup added to S10animationscreens"
            else
                rm -f "${RCADE_STARTUP}.tmp"
                echo -e "${yellow}[WARNING]${nc} Failed to modify S10animationscreens - DOFLinx will need to be started manually"
            fi
        fi
    fi
else
    echo -e "${yellow}[WARNING]${nc} $RCADE_STARTUP not found - DOFLinx will need to be started manually"
fi

# Save overlay if system space was modified
if [[ "$startup_needs_overlay" == "true" ]]; then
    echo -e "${green}[INFO]${nc} Saving system changes to overlay..."
    /rcade/scripts/rcade-save.sh
fi

# ============================================================================
# PHASE 2: Install DOFLinx binaries and config into /rcade/share/doflinx/
# ============================================================================
echo -e ""
echo -e "${cyan}[PHASE 2]${nc} Installing DOFLinx..."

mkdir -p ${INSTALLPATH}doflinx
mkdir -p ${INSTALLPATH}doflinx/config

# Determine arch folder
if [[ $machine_arch == "arm64" ]]; then
    stable_folder="Linux_arm64"
    beta_folder="Linux_arm64_beta"
elif [[ $machine_arch == "x64" ]]; then
    stable_folder="Linux_x64"
    beta_folder="Linux_x64_beta"
else
    echo -e "${red}[ERROR]${nc} Unsupported architecture: $machine_arch"
    exit 1
fi

stable_url="https://github.com/DOFLinx/CurrentExecutable/raw/main/${stable_folder}"
beta_url="https://github.com/DOFLinx/CurrentExecutable/raw/main/${beta_folder}"

using_beta=false
if [[ "$beta" == "true" ]]; then
    echo -e "${yellow}[BETA]${nc} Checking for beta version..."
    wget -q --spider "${beta_url}/DOFLinx"
    if [ $? -eq 0 ]; then
        main_url="$beta_url"
        using_beta=true
        echo -e "${green}[INFO]${nc} Beta version found - downloading from ${beta_folder}..."
    else
        main_url="$stable_url"
        echo -e "${yellow}[INFO]${nc} Beta not available - falling back to stable..."
    fi
else
    main_url="$stable_url"
    echo -e "${green}[INFO]${nc} Downloading DOFLinx from ${stable_folder}..."
fi

# DOFLinx executable
echo -e "${green}[INFO]${nc} Downloading DOFLinx executable..."
wget -q -O "${INSTALLPATH}doflinx/DOFLinx" "${main_url}/DOFLinx"
if [ $? -ne 0 ]; then
    echo -e "${red}[ERROR]${nc} Failed to download DOFLinx executable"
    install_successful=false
fi

wget -q -O "${INSTALLPATH}doflinx/DOFLinx.pdb" "${main_url}/DOFLinx.pdb" || true

# Supporting files (always from stable)
echo -e "${green}[INFO]${nc} Downloading DOFLinxMsg..."
wget -q -O "${INSTALLPATH}doflinx/DOFLinxMsg" "${stable_url}/DOFLinxMsg"
if [ $? -ne 0 ]; then
    echo -e "${red}[ERROR]${nc} Failed to download DOFLinxMsg"
    install_successful=false
fi

wget -q -O "${INSTALLPATH}doflinx/DOFLinxMsg.pdb" "${stable_url}/DOFLinxMsg.pdb" || true
wget -q -O "${INSTALLPATH}doflinx/keycodes" "${stable_url}/keycodes" || true
wget -q -O "${INSTALLPATH}doflinx/HELP.txt" "${stable_url}/HELP.txt" || true
wget -q -O "${INSTALLPATH}doflinx/DONATE.txt" "${stable_url}/DONATE.txt" || true
wget -q -O "${INSTALLPATH}doflinx/DOFLinx Update Notes.txt" "${stable_url}/DOFLinx%20Update%20Notes.txt" || true

# Permissions
chmod a+x ${INSTALLPATH}doflinx/DOFLinx
chmod a+x ${INSTALLPATH}doflinx/DOFLinxMsg
chmod a+x ${INSTALLPATH}doflinx/keycodes 2>/dev/null || true

# Startup wrapper script
if [[ -f "${INSTALLPATH}doflinx/doflinx-disabled.sh" && ! -f "${INSTALLPATH}doflinx/doflinx.sh" ]]; then
    echo -e "${green}[INFO]${nc} Re-enabling DOFLinx (renaming doflinx-disabled.sh back to doflinx.sh)..."
    mv "${INSTALLPATH}doflinx/doflinx-disabled.sh" "${INSTALLPATH}doflinx/doflinx.sh"
    chmod +x ${INSTALLPATH}doflinx/doflinx.sh
elif [[ ! -f "${INSTALLPATH}doflinx/doflinx.sh" ]]; then
    echo -e "${green}[INFO]${nc} Creating DOFLinx startup script..."
    cat > ${INSTALLPATH}doflinx/doflinx.sh << 'EOF'
#!/bin/bash
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
cd /rcade/share/doflinx && ./DOFLinx
EOF
    chmod +x ${INSTALLPATH}doflinx/doflinx.sh
else
    echo -e "${green}[INFO]${nc} doflinx.sh already exists, skipping..."
fi

# ============================================================================
# Config files (smart update - preserve user customizations)
# ============================================================================
config_dir="${INSTALLPATH}doflinx/config"

_smart_update_ini() {
    local url="$1"
    local dest="$2"
    local hash_file="${dest%.*}.$(basename "$dest" | sed 's/\.[^.]*$//').original.md5"
    hash_file="${config_dir}/.$(basename "$dest").original.md5"
    local tmp="${dest}.tmp"

    wget -q -O "$tmp" "$url"
    if [ $? -ne 0 ]; then
        echo -e "${yellow}[WARNING]${nc} Failed to download $(basename $dest)"
        rm -f "$tmp"
        return
    fi

    local new_hash current_hash original_hash
    new_hash=$(md5sum "$tmp" 2>/dev/null | cut -d' ' -f1)
    current_hash=$(md5sum "$dest" 2>/dev/null | cut -d' ' -f1)
    original_hash=$(cat "$hash_file" 2>/dev/null)

    if [[ "$force" == "true" ]]; then
        mv "$tmp" "$dest"
        echo "$new_hash" > "$hash_file"
        rm -f "${dest}.latest"
        echo -e "${yellow}[FORCE]${nc} $(basename $dest) overwritten"
    elif [[ ! -f "$dest" ]]; then
        mv "$tmp" "$dest"
        echo "$new_hash" > "$hash_file"
        echo -e "${green}[SUCCESS]${nc} $(basename $dest) installed"
    elif [[ "$new_hash" == "$current_hash" ]]; then
        rm -f "$tmp"
        echo -e "${green}[INFO]${nc} $(basename $dest) already up to date"
    elif [[ "$current_hash" == "$original_hash" ]]; then
        mv "$tmp" "$dest"
        echo "$new_hash" > "$hash_file"
        rm -f "${dest}.latest"
        echo -e "${green}[SUCCESS]${nc} $(basename $dest) updated"
    else
        mv "$tmp" "${dest}.latest"
        echo -e "${yellow}[NOTICE]${nc} $(basename $dest) has user customizations - preserved. New version at: ${dest}.latest"
    fi
}

echo -e "${green}[INFO]${nc} Checking DOFLinx.ini..."
_smart_update_ini \
    "https://github.com/alinke/pixelcade-linux-builds/raw/main/rcade/DOFLinx.ini" \
    "${config_dir}/DOFLinx.ini"

echo -e "${green}[INFO]${nc} Checking colours.ini..."
_smart_update_ini \
    "https://github.com/alinke/pixelcade-linux-builds/raw/main/rcade/colours.ini" \
    "${config_dir}/colours.ini"

# ALU board detection — configure DOFLinx.ini button mappings if needed
# TO DO update this later for the FU Cab
board_model=$(/rcade/scripts/rcade-commands.sh boardmodel 2>/dev/null)
if [[ "$board_model" == "rk3328-ha8801" || "$board_model" == "rk3399-legends" ]]; then
    echo -e "${green}[INFO]${nc} AtGames Legends cabinet detected (${board_model})"
    doflinx_ini="${config_dir}/DOFLinx.ini"
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

# Update DOFLinx MAME files via pixelweb
echo -e "${green}[INFO]${nc} Updating DOFLinx MAME files..."
"$pixelweb_path" -p /rcade/share/pixelcade -update-doflinx
if [ $? -eq 0 ]; then
    echo -e "${green}[SUCCESS]${nc} DOFLinx MAME files updated"
else
    echo -e "${yellow}[WARNING]${nc} Failed to update MAME files - run manually: $pixelweb_path -p /rcade/share/pixelcade -update-doflinx"
fi

# ============================================================================
# Result
# ============================================================================
echo -e ""
if [[ $install_successful == "true" ]]; then
    if [[ $reinstall == "true" ]]; then
        echo -e "${green}[SUCCESS]${nc} DOFLinx reinstalled successfully for R-Cade!"
    else
        echo -e "${green}[SUCCESS]${nc} DOFLinx installed successfully for R-Cade!"
    fi
    if [[ "$using_beta" == "true" ]]; then
        echo -e "  DOFLinx Version: ${yellow}BETA${nc} (${beta_folder})"
    else
        echo -e "  DOFLinx Version: Stable (${stable_folder})"
    fi
    echo -e "  Location:        ${INSTALLPATH}doflinx/"
    echo -e "  Config:          ${config_dir}/DOFLinx.ini"
    echo -e "  Architecture:    $machine_arch"
    echo -e ""
    echo -e "${cyan}[IMPORTANT]${nc} Please reboot your R-Cade system to start DOFLinx automatically"
else
    echo -e "${red}[ERROR]${nc} DOFLinx installation failed"
    exit 1
fi
