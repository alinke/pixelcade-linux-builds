#!/bin/bash
# Pixelcade LCD USB setup for R-Cade
# Called by the Pixelcade Companion when a Pixelcade LCD USB device (1d6b:3232)
# is detected but the udev rule and network interface are not yet configured.
#
# Usage: ./setup-rcade-lcd.sh
#
# This script is idempotent — safe to run more than once.

version=1

cyan='\033[0;36m'
red='\033[0;31m'
yellow='\033[0;33m'
green='\033[0;32m'
nc='\033[0m'

INSTALLPATH="/rcade/share/"
UDEV_RULE="/etc/udev/rules.d/99-pixelcade-lcd.rules"

echo -e ""
echo -e "       ${cyan}Pixelcade LCD Setup for R-Cade : Version $version${nc}"
echo -e ""

# Verify the USB device is actually connected
if ! lsusb | grep -q '1d6b:3232'; then
    echo -e "${red}[ERROR]${nc} Pixelcade LCD USB device (1d6b:3232) not detected."
    echo -e "${yellow}[INFO]${nc} Make sure the Pixelcade LCD is connected via USB and try again."
    exit 1
fi

echo -e "${green}[INFO]${nc} Pixelcade LCD USB device detected."

# ============================================================================
# PHASE 1: Install udev rule (system space — will be saved to overlay)
# ============================================================================
echo -e ""
echo -e "${cyan}[PHASE 1]${nc} Installing udev rule..."

if [[ -f "$UDEV_RULE" ]]; then
    echo -e "${green}[INFO]${nc} udev rule already installed at $UDEV_RULE"
else
    echo -e "${green}[INFO]${nc} Installing udev rule..."
    cat > "$UDEV_RULE" << 'RULEEOF'
# Rename Pixelcade LCD USB RNDIS interface to pixelcade0 and bring it up with static IP.
# No DHCP (avoids default gateway leak), no gateway advertised.
ACTION=="add", SUBSYSTEM=="net", ATTRS{idVendor}=="1d6b", ATTRS{idProduct}=="3232", NAME="pixelcade0", RUN+="/bin/sh -c 'ip link set pixelcade0 up && ip addr add 169.254.100.2/24 dev pixelcade0 2>/dev/null && ip route add 169.254.100.1/32 dev pixelcade0 2>/dev/null'"
RULEEOF

    # Remove any old setup script from previous installs
    rm -f /usr/lib/udev/pixelcade-net-setup.sh

    echo -e "${green}[SUCCESS]${nc} udev rule installed"
fi

echo -e "${green}[INFO]${nc} Saving system changes to overlay..."
/rcade/scripts/rcade-save.sh

# ============================================================================
# PHASE 2: Bring up USB network interface now (udev won't fire until next boot)
# ============================================================================
echo -e ""
echo -e "${cyan}[PHASE 2]${nc} Configuring USB network interface..."

iface_configured=false
for iface in pixelcade0 usb0 usb1 usb2; do
    if ip link show "$iface" &>/dev/null 2>&1; then
        echo -e "${green}[INFO]${nc} Found interface: $iface — bringing up..."
        ip link set "$iface" up 2>/dev/null
        ip addr add 169.254.100.2/24 dev "$iface" 2>/dev/null
        ip route add 169.254.100.1/32 dev "$iface" 2>/dev/null
        echo -e "${green}[SUCCESS]${nc} Interface $iface configured with 169.254.100.2/24"
        iface_configured=true
        break
    fi
done

if [[ "$iface_configured" == "false" ]]; then
    echo -e "${yellow}[WARNING]${nc} No USB network interface found yet (pixelcade0/usb0/usb1/usb2)."
    echo -e "${yellow}[INFO]${nc} The interface will be configured automatically on next reboot via the udev rule."
fi

# ============================================================================
# PHASE 3: AtGames Legends Ultimate detection
# rk3328-ha8801 = Legends 1.1, rk3399-legends = Legends 1.0
# ============================================================================
echo -e ""
echo -e "${cyan}[PHASE 3]${nc} Detecting cabinet type..."

board_model=$(/rcade/scripts/rcade-commands.sh boardmodel 2>/dev/null)
if [[ "$board_model" == "rk3328-ha8801" || "$board_model" == "rk3399-legends" ]]; then
    echo -e "${green}[INFO]${nc} AtGames Legends Ultimate detected (${board_model})"

    # Give the interface a moment to come up before making HTTP requests
    sleep 2

    # Set BitLCD screen mode on the LCD
    echo -e "${green}[INFO]${nc} Setting BitLCD screen mode..."
    alu_response=$(curl -s --connect-timeout 5 --max-time 15 \
        "http://169.254.100.1:8080/settings?key=screenMode&value=bitlcd" 2>/dev/null)
    if [[ -n "$alu_response" ]]; then
        echo -e "${green}[SUCCESS]${nc} BitLCD screen mode configured"
    else
        echo -e "${yellow}[WARNING]${nc} Could not reach Pixelcade LCD to set BitLCD mode — configure it later in the Pixelcade app"
    fi

    # Configure DOFLinx.ini button mappings for ALU (if DOFLinx is installed)
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
        echo -e "${yellow}[INFO]${nc} DOFLinx not installed — skipping ALU button configuration"
    fi
else
    echo -e "${green}[INFO]${nc} Standard cabinet (board: ${board_model:-unknown})"
fi

# ============================================================================
# Result
# ============================================================================
echo -e ""
echo -e "${green}[SUCCESS]${nc} Pixelcade LCD setup complete!"
echo -e ""
echo -e "  udev rule:    $UDEV_RULE"
echo -e "  LCD address:  http://169.254.100.1:8080"
echo -e ""
if [[ "$iface_configured" == "false" ]]; then
    echo -e "${cyan}[NOTE]${nc} Reboot your R-Cade system to activate the USB network interface."
else
    echo -e "${cyan}[NOTE]${nc} Pixelcade LCD should now be reachable at http://169.254.100.1:8080"
fi
