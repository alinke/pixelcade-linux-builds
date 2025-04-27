#!/bin/bash
#set -x  # Enable debugging

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

# Check if configfs is mounted, if not mount it
if ! mountpoint -q /sys/kernel/config; then
    sudo mount -t configfs none /sys/kernel/config
fi

# Remove any existing configuration
if [ -d "/sys/kernel/config/usb_gadget/orangepi" ]; then
    # Disable any existing UDC
    if [ -f "/sys/kernel/config/usb_gadget/orangepi/UDC" ]; then
        sudo sh -c 'echo "" > /sys/kernel/config/usb_gadget/orangepi/UDC'
    fi
    # Remove existing configuration
    sudo rm -rf /sys/kernel/config/usb_gadget/orangepi
fi

# Wait a moment for cleanup
sleep 1

# Create gadget directory
sudo mkdir -p /sys/kernel/config/usb_gadget/orangepi
cd /sys/kernel/config/usb_gadget/orangepi || exit 1

# Configure USB device with the new VID/PID
sudo sh -c 'echo 0x1D6B > idVendor'  # Linux Foundation
sudo sh -c 'echo 0x3232 > idProduct'  # Custom PID
sudo sh -c 'echo 0x0100 > bcdDevice'  # v1.0.0
sudo sh -c 'echo 0x0200 > bcdUSB'     # USB 2.0

# Windows extensions
sudo mkdir -p os_desc
sudo sh -c 'echo 1 > os_desc/use'
sudo sh -c 'echo 0xcd > os_desc/b_vendor_code'
sudo sh -c 'echo MSFT100 > os_desc/qw_sign'

# Create device strings directory
sudo mkdir -p strings/0x409
sudo sh -c 'echo "381729645" > strings/0x409/serialnumber'
sudo sh -c 'echo "Open Gadgets" > strings/0x409/manufacturer'   # Changed to Open Gadgets
sudo sh -c 'echo "Pixelcade LCD Marquee" > strings/0x409/product'

# Create configuration
sudo mkdir -p configs/c.1/strings/0x409
sudo sh -c 'echo "RNDIS Configuration" > configs/c.1/strings/0x409/configuration'
sudo sh -c 'echo 250 > configs/c.1/MaxPower'

# Create RNDIS function with specific class codes
sudo mkdir -p functions/rndis.0
sudo sh -c 'echo 0x02 > functions/rndis.0/class'        # Communications
sudo sh -c 'echo 0x02 > functions/rndis.0/subclass'     # Abstract Control Model
sudo sh -c 'echo 0x01 > functions/rndis.0/protocol'     # AT Commands V.250
sudo sh -c 'echo "00:22:82:ff:ff:11" > functions/rndis.0/dev_addr'
sudo sh -c 'echo "00:22:82:ff:ff:22" > functions/rndis.0/host_addr'

# Make sure these directories exist
sudo mkdir -p functions/rndis.0/os_desc/interface.rndis

# Set Windows-specific descriptors
sudo sh -c 'echo "RNDIS" > functions/rndis.0/os_desc/interface.rndis/compatible_id'
sudo sh -c 'echo "5162001" > functions/rndis.0/os_desc/interface.rndis/sub_compatible_id'

# Set interface numbers
sudo sh -c 'echo 0 > functions/rndis.0/ifnum_u'
sudo sh -c 'echo 1 > functions/rndis.0/ifnum_d'

# Link the function to configuration
sudo ln -s functions/rndis.0 configs/c.1/
sudo ln -s configs/c.1 os_desc

# Find and enable UDC
UDC=$(ls /sys/class/udc | head -n 1)
if [ -z "$UDC" ]; then
    echo "No UDC driver found"
    exit 1
fi

# Enable the gadget
sudo sh -c "echo $UDC > UDC"

# Wait for interface
for i in $(seq 1 10); do
    if sudo ip link show usb0 > /dev/null 2>&1; then
        # Reset interface completely
        sudo ip link set usb0 down
        sudo ip addr flush dev usb0
        
        # Configure link-local address with specific scope
        sudo ip addr add 169.254.100.1/16 dev usb0 scope link

        # Create strict isolation rules
        sudo nft flush ruleset
        sudo nft add table ip filter
        sudo nft add chain ip filter input { type filter hook input priority 0 \; }
        sudo nft add chain ip filter output { type filter hook output priority 0 \; }
        sudo nft add chain ip filter forward { type filter hook forward priority 0 \; }

        # Strict interface isolation
        sudo nft add rule ip filter input iifname != "usb0" ip daddr 169.254.100.1/16 drop
        sudo nft add rule ip filter output oifname != "usb0" ip saddr 169.254.100.1/16 drop

        # Block all forwarding for USB interface
        sudo nft add rule ip filter forward iifname "usb0" drop
        sudo nft add rule ip filter forward oifname "usb0" drop

        # Block routing advertisements and discovery
        sudo nft add rule ip filter input iifname "usb0" ip protocol icmp icmp type router-advertisement drop
        sudo nft add rule ip filter output oifname "usb0" ip protocol icmp icmp type router-advertisement drop

        # Disable proxy ARP
        echo 0 | sudo tee /proc/sys/net/ipv4/conf/usb0/proxy_arp
        
        # Disable IP forwarding specifically for USB interface
        echo 0 | sudo tee /proc/sys/net/ipv4/conf/usb0/forwarding
        
        # Prevent automatic route management
        echo 0 | sudo tee /proc/sys/net/ipv4/conf/usb0/accept_redirects
        echo 0 | sudo tee /proc/sys/net/ipv4/conf/usb0/send_redirects
        
        # Set very high metric for USB interface to prevent it from becoming default route
        sudo ip route add 169.254.0.0/16 dev usb0 metric 65535 scope link

        # Disable multicast at interface level
        sudo ip link set usb0 multicast off
        sudo ip link set usb0 up

        # Show final config
        ip addr show usb0
        echo "USB Device successfully configured with:"
        echo "  VID: 0x1D6B"
        echo "  PID: 0x3232" 
        echo "  Device Name: Pixelcade LCD Marquee"
        echo "  Manufacturer: Open Gadgets"
        exit 0
    fi
    sleep 1
done

echo "Failed to create USB network interface"
exit 1