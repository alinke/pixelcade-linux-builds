#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

echo "Installing RNDIS USB gadget functionality..."

# Create modules configuration
echo "Creating USB gadget modules configuration..."
cat > /etc/modules-load.d/usb-gadget.conf << 'EOL'
libcomposite
EOL

# Create configure-usb-gadget script
echo "Creating USB gadget configuration script..."
cat > /usr/local/bin/configure-usb-gadget.sh << 'EOL'
# Make script executable
chmod +x /usr/local/bin/configure-usb-gadget.sh

# Create systemd service
echo "Creating systemd service..."
cat > /etc/systemd/system/configure-usb-gadget.service << 'EOL'

# Enable the service
echo "Enabling systemd service..."
systemctl enable configure-usb-gadget.service

# Stop and disable dnsmasq if it exists
if systemctl is-active --quiet dnsmasq; then
    echo "Stopping and disabling dnsmasq..."
    systemctl stop dnsmasq
    systemctl disable dnsmasq
fi

echo "Installation complete. Please reboot to apply changes."

# overwrite this file /home/pi/pixelcade/system/pixelcade-startup.sh with this content:
echo "Overwriting /home/pi/pixelcade/system/pixelcade-startup.sh..."

cat > /home/pi/pixelcade/system/pixelcade-startup.sh << 'EOL'

# Make the startup script executable
chmod +x /home/pi/pixelcade/system/pixelcade-startup.sh

echo "Setup complete. Please reboot the system for the changes to take effect."
