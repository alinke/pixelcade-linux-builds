#!/bin/bash
# DOFLinx disable for R-Cade
# Stops DOFLinx and removes it from the startup script (files are preserved).
# Called by the Pixelcade Companion from Settings -> In Game Effects.
#
# Usage: ./setup-rcade-doflinx-disable.sh

version=2

cyan='\033[0;36m'
red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'
nc='\033[0m'

INSTALLPATH="/rcade/share/"
RCADE_STARTUP="/etc/init.d/S10animationscreens"
RCADE_COMMANDS="/rcade/scripts/rcade-commands.sh"

echo -e ""
echo -e "       ${cyan}Pixelcade DOFLinx Disable for R-Cade : Version $version${nc}"
echo -e ""

# RCade version detection
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
# Disable DOFLinx startup
# ============================================================================

if [[ "$rcade_new_version" == "true" ]]; then
    # 2.0.8+: system controls startup — rename doflinx.sh so the system can't find it
    doflinx_sh="${INSTALLPATH}doflinx/doflinx.sh"
    doflinx_sh_disabled="${INSTALLPATH}doflinx/doflinx-disabled.sh"
    if [[ -f "$doflinx_sh" ]]; then
        mv "$doflinx_sh" "$doflinx_sh_disabled"
        echo -e "${green}[SUCCESS]${nc} DOFLinx disabled (doflinx.sh renamed to doflinx-disabled.sh)"
    else
        echo -e "${green}[INFO]${nc} doflinx.sh not found — DOFLinx already disabled"
    fi
else
    # Pre-2.0.8: remove DOFLinx block from startup scripts
    startup_needs_overlay=false
    removed=false

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
        echo -e "${green}[INFO]${nc} Removing DOFLinx startup from rcade-commands.sh..."
        mkdir -p ${INSTALLPATH}pixelcade/backups
        cp "$RCADE_COMMANDS" "${INSTALLPATH}pixelcade/backups/rcade-commands.sh.backup.$(date +%Y%m%d_%H%M%S)"
        if _remove_doflinx_block "$RCADE_COMMANDS"; then
            echo -e "${green}[SUCCESS]${nc} DOFLinx removed from rcade-commands.sh"
            removed=true
        else
            echo -e "${yellow}[WARNING]${nc} Could not remove DOFLinx from rcade-commands.sh"
        fi
    fi

    if [[ -f "$RCADE_STARTUP" ]] && grep -q "doflinx\|DOFLinx" "$RCADE_STARTUP" 2>/dev/null; then
        echo -e "${green}[INFO]${nc} Removing DOFLinx startup from S10animationscreens..."
        mkdir -p ${INSTALLPATH}pixelcade/backups
        cp "$RCADE_STARTUP" "${INSTALLPATH}pixelcade/backups/S10animationscreens.backup.$(date +%Y%m%d_%H%M%S)"
        if _remove_doflinx_block "$RCADE_STARTUP"; then
            echo -e "${green}[SUCCESS]${nc} DOFLinx removed from S10animationscreens"
            startup_needs_overlay=true
            removed=true
        else
            echo -e "${yellow}[WARNING]${nc} Could not remove DOFLinx from S10animationscreens"
        fi
    fi

    if [[ "$removed" == "false" ]]; then
        echo -e "${green}[INFO]${nc} DOFLinx startup entry not found in startup scripts"
    fi

    if [[ "$startup_needs_overlay" == "true" ]]; then
        echo -e "${green}[INFO]${nc} Saving system changes to overlay..."
        /rcade/scripts/rcade-save.sh
    fi
fi

echo -e ""
echo -e "${green}[SUCCESS]${nc} DOFLinx disabled. Files are preserved at ${INSTALLPATH}doflinx/"
echo -e "${cyan}[NOTE]${nc} DOFLinx will not start on next reboot. Run the installer to re-enable."
