#!/bin/bash
# DOFLinx uninstall for R-Cade
# Stops DOFLinx, removes it from startup scripts, and deletes all DOFLinx files.
# Called by the Pixelcade Companion from Settings -> In Game Effects.
#
# Usage: ./setup-rcade-doflinx-uninstall.sh

version=1

cyan='\033[0;36m'
red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'
nc='\033[0m'

INSTALLPATH="/rcade/share/"
RCADE_STARTUP="/etc/init.d/S10animationscreens"
RCADE_COMMANDS="/rcade/scripts/rcade-commands.sh"

echo -e ""
echo -e "       ${cyan}Pixelcade DOFLinx Uninstall for R-Cade : Version $version${nc}"
echo -e ""

# Stop running DOFLinx
doflinx_pids=$(pidof DOFLinx 2>/dev/null)
if [[ -n "$doflinx_pids" ]]; then
    echo -e "${green}[INFO]${nc} Stopping DOFLinx (PIDs: $doflinx_pids)..."
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 ${INSTALLPATH}doflinx/DOFLinxMsg QUIT 2>/dev/null
    sleep 2
    doflinx_pids=$(pidof DOFLinx 2>/dev/null)
    if [[ -n "$doflinx_pids" ]]; then
        echo -e "${yellow}[INFO]${nc} Force killing DOFLinx..."
        kill -9 $doflinx_pids 2>/dev/null
        sleep 1
    fi
    echo -e "${green}[SUCCESS]${nc} DOFLinx stopped"
else
    echo -e "${green}[INFO]${nc} DOFLinx is not currently running"
fi

# ============================================================================
# Remove DOFLinx from startup scripts
# ============================================================================
startup_needs_overlay=false

_remove_doflinx_block() {
    local file="$1"
    if ! grep -q "doflinx\|DOFLinx" "$file" 2>/dev/null; then
        return 0
    fi
    awk '
    /# Launch DOFLinx/ { skip=1; next }
    skip && /^[[:space:]]*fi[[:space:]]*$/ { skip=0; next }
    skip { next }
    { print }
    ' "$file" > "${file}.tmp"
    if [[ -s "${file}.tmp" ]]; then
        mv "${file}.tmp" "$file"
        chmod +x "$file"
        return 0
    else
        rm -f "${file}.tmp"
        return 1
    fi
}

if [[ -f "$RCADE_COMMANDS" ]] && grep -q "doflinx\|DOFLinx" "$RCADE_COMMANDS" 2>/dev/null; then
    echo -e "${green}[INFO]${nc} Removing DOFLinx from rcade-commands.sh..."
    mkdir -p ${INSTALLPATH}pixelcade/backups
    cp "$RCADE_COMMANDS" "${INSTALLPATH}pixelcade/backups/rcade-commands.sh.backup.$(date +%Y%m%d_%H%M%S)"
    if _remove_doflinx_block "$RCADE_COMMANDS"; then
        echo -e "${green}[SUCCESS]${nc} DOFLinx removed from rcade-commands.sh"
    else
        echo -e "${yellow}[WARNING]${nc} Could not remove DOFLinx from rcade-commands.sh"
    fi
fi

if [[ -f "$RCADE_STARTUP" ]] && grep -q "doflinx\|DOFLinx" "$RCADE_STARTUP" 2>/dev/null; then
    echo -e "${green}[INFO]${nc} Removing DOFLinx from S10animationscreens..."
    mkdir -p ${INSTALLPATH}pixelcade/backups
    cp "$RCADE_STARTUP" "${INSTALLPATH}pixelcade/backups/S10animationscreens.backup.$(date +%Y%m%d_%H%M%S)"
    if _remove_doflinx_block "$RCADE_STARTUP"; then
        echo -e "${green}[SUCCESS]${nc} DOFLinx removed from S10animationscreens"
        startup_needs_overlay=true
    else
        echo -e "${yellow}[WARNING]${nc} Could not remove DOFLinx from S10animationscreens"
    fi
fi

if [[ "$startup_needs_overlay" == "true" ]]; then
    echo -e "${green}[INFO]${nc} Saving system changes to overlay..."
    /rcade/scripts/rcade-save.sh
fi

# ============================================================================
# Delete DOFLinx files
# ============================================================================
doflinx_dir="${INSTALLPATH}doflinx"
if [[ -d "$doflinx_dir" ]]; then
    echo -e "${green}[INFO]${nc} Removing DOFLinx files at $doflinx_dir..."
    rm -rf "$doflinx_dir"
    echo -e "${green}[SUCCESS]${nc} DOFLinx files removed"
else
    echo -e "${green}[INFO]${nc} DOFLinx directory not found — nothing to remove"
fi

echo -e ""
echo -e "${green}[SUCCESS]${nc} DOFLinx uninstalled from R-Cade"
echo -e "${cyan}[NOTE]${nc} Run the DOFLinx installer from the Pixelcade Companion to reinstall."
