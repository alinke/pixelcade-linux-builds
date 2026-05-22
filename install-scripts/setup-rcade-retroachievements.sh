#!/bin/bash
# RetroAchievements enabler/disabler for R-Cade
# Called by the Pixelcade Companion from the Settings -> In Game Effects tab.
# Enables or disables RetroAchievements in RetroArch by updating retroarch.cfg.
#
# Usage: ./setup-rcade-retroachievements.sh [--disable]

version=1

cyan='\033[0;36m'
red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'
nc='\033[0m'

disable=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --disable|-disable|disable) disable=true; shift ;;
        *) shift ;;
    esac
done

RETROARCH_CFG="/rcade/share/configs/retroarch/retroarch.cfg"

echo -e ""
echo -e "       ${cyan}Pixelcade RetroAchievements for R-Cade : Version $version${nc}"
echo -e ""

if [[ ! -f "$RETROARCH_CFG" ]]; then
    echo -e "${red}[ERROR]${nc} RetroArch config not found at $RETROARCH_CFG"
    exit 1
fi

update_setting() {
    local setting="$1"
    local value="$2"
    local file="$3"

    if grep -q "^${setting} =" "$file"; then
        sed -i "s|^${setting} =.*|${setting} = ${value}|" "$file"
    else
        echo "${setting} = ${value}" >> "$file"
    fi
}

echo -e "${green}[INFO]${nc} Backing up retroarch.cfg..."
cp "$RETROARCH_CFG" "${RETROARCH_CFG}.backup.$(date +%Y%m%d_%H%M%S)"

if [[ "$disable" == "true" ]]; then
    echo -e "${green}[INFO]${nc} Disabling RetroAchievements..."
    update_setting "cheevos_enable" '"false"' "$RETROARCH_CFG"
    update_setting "cheevos_hardcore_mode_enable" '"false"' "$RETROARCH_CFG"
    update_setting "cheevos_start_active" '"false"' "$RETROARCH_CFG"
    echo -e "${green}[SUCCESS]${nc} RetroAchievements disabled in RetroArch"
    echo -e "${green}[INFO]${nc} Settings applied:"
    echo -e "  cheevos_enable = \"false\""
    echo -e "  cheevos_hardcore_mode_enable = \"false\""
    echo -e "  cheevos_start_active = \"false\""
else
    echo -e "${green}[INFO]${nc} Enabling RetroAchievements..."
    update_setting "cheevos_enable" '"true"' "$RETROARCH_CFG"
    update_setting "cheevos_hardcore_mode_enable" '"false"' "$RETROARCH_CFG"
    update_setting "cheevos_start_active" '"true"' "$RETROARCH_CFG"
    echo -e "${green}[SUCCESS]${nc} RetroAchievements enabled in RetroArch"
    echo -e "${green}[INFO]${nc} Settings applied:"
    echo -e "  cheevos_enable = \"true\""
    echo -e "  cheevos_hardcore_mode_enable = \"false\""
    echo -e "  cheevos_start_active = \"true\""
    echo -e ""
    echo -e "${cyan}[NOTE]${nc} You will need to set your RetroAchievements username and password"
    echo -e "       via RCade Main Menu -> Game Settings -> RetroArch Settings."
fi
