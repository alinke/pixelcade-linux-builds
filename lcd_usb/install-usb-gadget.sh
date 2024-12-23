#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

echo "Installing RNDIS USB gadget functionality..."

# Define an array of files with their respective URLs and destinations
FILES=(
    "https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/refs/heads/main/lcd_usb/configure-usb-gadget.sh:/usr/local/bin/configure-usb-gadget.sh:executable"
    "https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/refs/heads/main/lcd_usb/usb-gadget.conf:/etc/modules-load.d/usb-gadget.conf"
    "https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/refs/heads/main/lcd_usb/configure-usb-gadget.service:/etc/systemd/system/configure-usb-gadget.service"
    "https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/refs/heads/main/lcd_usb/pixelcade-startup.sh:/home/pi/pixelcade/system/pixelcade-startup.sh:executable"
)

# Loop through each file, download and copy to its destination
for file_entry in "${FILES[@]}"; do
    # Parse the entry
    IFS=":" read -r FILE_URL DEST_PATH PERMISSIONS <<< "$file_entry"

    # Temporary file path
    TEMP_FILE="/tmp/$(basename "$DEST_PATH")"

    echo "Downloading $FILE_URL..."
    wget -q --show-progress -O "$TEMP_FILE" "$FILE_URL"

    if [ $? -eq 0 ]; then
        echo "Successfully downloaded $FILE_URL to $TEMP_FILE."

        # Copy to the destination
        echo "Copying $TEMP_FILE to $DEST_PATH..."
        sudo cp -f "$TEMP_FILE" "$DEST_PATH"

        # Set permissions if required
        if [ "$PERMISSIONS" == "executable" ]; then
            echo "Setting executable permissions for $DEST_PATH..."
            sudo chmod +x "$DEST_PATH"
        fi

        # Clean up the temporary file
        echo "Cleaning up temporary file..."
        rm -f "$TEMP_FILE"
    else
        echo "Failed to download $FILE_URL. Skipping."
    fi
done

echo "All files processed."

sudo chmod +x /usr/local/bin/configure-usb-gadget.sh
sudo chmod +x /home/pi/pixelcade/system/pixelcade-startup.sh

# Create systemd service
echo "Creating systemd service..."
echo "Enabling systemd service..."
systemctl enable configure-usb-gadget.service

# Stop and disable dnsmasq if it exists, this is a fail safe, we should not need it
if systemctl is-active --quiet dnsmasq; then
    echo "Stopping and disabling dnsmasq..."
    systemctl stop dnsmasq
    systemctl disable dnsmasq
fi

echo "Setup complete. Please reboot the system for the changes to take effect."
