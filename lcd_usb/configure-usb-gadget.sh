#!/bin/bash
#set -x  # Enable debugging

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

# Check if configfs is mounted, if not mount it
if ! mountpoint -q /sys/kernel/config; then
    mount -t configfs none /sys/kernel/config
fi

# Remove any existing configuration
if [ -d "/sys/kernel/config/usb_gadget/orangepi" ]; then
    # Disable any existing UDC
    if [ -f "/sys/kernel/config/usb_gadget/orangepi/UDC" ]; then
        echo "" > /sys/kernel/config/usb_gadget/orangepi/UDC
    fi
    # Remove existing configuration
    rm -rf /sys/kernel/config/usb_gadget/orangepi
fi

# Kill any previous dnsmasq instance for usb0
if [ -f /var/run/dnsmasq-usb.pid ]; then
    kill "$(cat /var/run/dnsmasq-usb.pid)" 2>/dev/null
    rm -f /var/run/dnsmasq-usb.pid
fi

# Wait a moment for cleanup
sleep 1

# Create gadget directory
mkdir -p /sys/kernel/config/usb_gadget/orangepi
cd /sys/kernel/config/usb_gadget/orangepi || exit 1

# Configure USB device with the new VID/PID
echo 0x1D6B > idVendor   # Linux Foundation
echo 0x3232 > idProduct  # Custom PID
echo 0x0100 > bcdDevice  # v1.0.0
echo 0x0200 > bcdUSB     # USB 2.0

# Windows extensions
mkdir -p os_desc
echo 1       > os_desc/use
echo 0xcd    > os_desc/b_vendor_code
echo MSFT100 > os_desc/qw_sign

# Create device strings directory
mkdir -p strings/0x409
echo "381729645"            > strings/0x409/serialnumber
echo "Open Gadgets"         > strings/0x409/manufacturer
echo "Pixelcade LCD Marquee" > strings/0x409/product

# Create configuration
mkdir -p configs/c.1/strings/0x409
echo "RNDIS Configuration" > configs/c.1/strings/0x409/configuration
echo 250                    > configs/c.1/MaxPower

# Create RNDIS function with specific class codes
mkdir -p functions/rndis.0
echo 0x02 > functions/rndis.0/class        # Communications
echo 0x02 > functions/rndis.0/subclass     # Abstract Control Model
echo 0x01 > functions/rndis.0/protocol     # AT Commands V.250
echo "00:22:82:ff:ff:11" > functions/rndis.0/dev_addr
echo "00:22:82:ff:ff:22" > functions/rndis.0/host_addr

# Make sure these directories exist
mkdir -p functions/rndis.0/os_desc/interface.rndis

# Set Windows-specific descriptors
echo "RNDIS"   > functions/rndis.0/os_desc/interface.rndis/compatible_id
echo "5162001" > functions/rndis.0/os_desc/interface.rndis/sub_compatible_id

# Set interface numbers
echo 0 > functions/rndis.0/ifnum_u
echo 1 > functions/rndis.0/ifnum_d

# Link the function to configuration
ln -s functions/rndis.0 configs/c.1/
ln -s configs/c.1 os_desc

# Find and enable UDC
UDC=$(ls /sys/class/udc | head -n 1)
if [ -z "$UDC" ]; then
    echo "No UDC driver found"
    exit 1
fi

# Enable the gadget
echo "$UDC" > UDC

# Wait for interface
for i in $(seq 1 10); do
    if ip link show usb0 > /dev/null 2>&1; then
        # Reset interface completely
        ip link set usb0 down
        ip addr flush dev usb0

        # Use /24 subnet — NOT /16. A /16 covers all of 169.254.0.0/16 (the entire
        # link-local range) which can create routing conflicts on the host side.
        # /24 scopes it to just 169.254.100.x.
        ip addr add 169.254.100.1/24 dev usb0 scope link

        # Disable IP forwarding and routing features for USB interface only.
        # This prevents the Pixelcade from acting as a router for USB traffic.
        echo 0 > /proc/sys/net/ipv4/conf/usb0/proxy_arp
        echo 0 > /proc/sys/net/ipv4/conf/usb0/forwarding
        echo 0 > /proc/sys/net/ipv4/conf/usb0/accept_redirects
        echo 0 > /proc/sys/net/ipv4/conf/usb0/send_redirects

        # Use a dedicated nft table for USB isolation instead of flushing ALL rules.
        # Flushing the entire ruleset can break WiFi/hotspot firewall rules.
        nft delete table ip usb_isolate 2>/dev/null
        nft add table ip usb_isolate
        nft add chain ip usb_isolate forward '{ type filter hook forward priority 0 ; }'
        nft add rule ip usb_isolate forward iifname "usb0" drop
        nft add rule ip usb_isolate forward oifname "usb0" drop

        # Disable multicast to prevent mDNS/SSDP leaking over USB
        ip link set usb0 multicast off
        ip link set usb0 up

        # Run a minimal DHCP server on usb0. This gives the host an IP address
        # immediately (no 30s DHCP timeout) but provides NO default gateway.
        # Without a gateway, the host won't try to route internet traffic through USB,
        # which is what causes WiFi disruption on Batocera/Rcade.
        if command -v dnsmasq > /dev/null 2>&1; then
            dnsmasq \
                --interface=usb0 \
                --bind-interfaces \
                --dhcp-range=169.254.100.100,169.254.100.199,255.255.255.0,infinite \
                --dhcp-option=3 \
                --dhcp-option=6 \
                --no-resolv \
                --no-hosts \
                --port=0 \
                --pid-file=/var/run/dnsmasq-usb.pid \
                --log-facility=/dev/null
            echo "  DHCP server started on usb0 (no gateway advertised)"
        else
            echo "  Warning: dnsmasq not found, host will use APIPA (may be slow)"
        fi

        # Show final config
        ip addr show usb0
        echo "USB Device successfully configured with:"
        echo "  VID: 0x1D6B"
        echo "  PID: 0x3232"
        echo "  Device Name: Pixelcade LCD Marquee"
        echo "  Manufacturer: Open Gadgets"
        echo "  Subnet: 169.254.100.0/24 (isolated, no gateway)"
        exit 0
    fi
    sleep 1
done

echo "Failed to create USB network interface"
exit 1
