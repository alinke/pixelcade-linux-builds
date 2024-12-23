#!/bin/bash
set -x  # Enable debugging

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

# Function to check if an IP is in use
check_ip_in_use() {
    local ip=$1
    # Use arping to check if IP is in use (timeout after 1 second)
    arping -D -I usb0 -c 1 -w 1 "$ip" > /dev/null 2>&1
    return $?
}

# Function to find next available IP
find_available_ip() {
    local base_ip="169.254.100"
    local ip_suffix=1
    
    while [ $ip_suffix -lt 255 ]; do
        local test_ip="${base_ip}.${ip_suffix}"
        
        # Check if IP exists in any interface
        if ! ip addr show | grep -q "$test_ip"; then
            # Double check with arping
            if ! check_ip_in_use "$test_ip"; then
                echo "$test_ip"
                return 0
            fi
        fi
        
        ((ip_suffix++))
    done
    
    echo "No available IPs found in range ${base_ip}.1-254"
    return 1
}

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

# Configure USB device
sudo sh -c 'echo 0x1d6b > idVendor'  # Linux Foundation
sudo sh -c 'echo 0x0104 > idProduct'  # Multifunction Composite Gadget
sudo sh -c 'echo 0x0100 > bcdDevice'  # v1.0.0
sudo sh -c 'echo 0x0200 > bcdUSB'     # USB 2.0

# Windows extensions
sudo mkdir -p os_desc
sudo sh -c 'echo 1 > os_desc/use'
sudo sh -c 'echo 0xcd > os_desc/b_vendor_code'
sudo sh -c 'echo MSFT100 > os_desc/qw_sign'

# Create device strings directory
sudo mkdir -p strings/0x409
sudo sh -c 'echo "123456789" > strings/0x409/serialnumber'
sudo sh -c 'echo "Pixelcade" > strings/0x409/manufacturer'
sudo sh -c 'echo "Pixelcade LCD Marquee" > strings/0x409/product'

# Create configuration
sudo mkdir -p configs/c.1/strings/0x409
sudo sh -c 'echo "Config 1: RNDIS" > configs/c.1/strings/0x409/configuration'
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
        
        # Find available IP
        AVAILABLE_IP=$(find_available_ip)
        if [ $? -ne 0 ]; then
            echo "Failed to find available IP address"
            exit 1
        fi
        
        # Configure link-local address with specific scope
        sudo ip addr add "${AVAILABLE_IP}/16" dev usb0 scope link

        # Create strict isolation rules
        sudo nft flush ruleset
        sudo nft add table ip filter
        sudo nft add chain ip filter input { type filter hook input priority 0 \; }
        sudo nft add chain ip filter output { type filter hook output priority 0 \; }
        sudo nft add chain ip filter forward { type filter hook forward priority 0 \; }

        # Strict interface isolation (using dynamic IP)
        sudo nft add rule ip filter input iifname != "usb0" ip daddr "${AVAILABLE_IP}/16" drop
        sudo nft add rule ip filter output oifname != "usb0" ip saddr "${AVAILABLE_IP}/16" drop

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
        echo "Successfully configured USB gadget with IP: ${AVAILABLE_IP}"
        ip addr show usb0
        exit 0
    fi
    sleep 1
done

echo "Failed to create USB network interface"
exit 1