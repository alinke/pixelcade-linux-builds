#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

#!/bin/bash

# Define an array of files with their respective URLs, destinations, and permissions
FILES=(
    "https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/refs/heads/main/lcd_usb/configure-usb-gadget.sh|/usr/local/bin/configure-usb-gadget.sh|executable"
    "https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/refs/heads/main/lcd_usb/usb-gadget.conf|/etc/modules-load.d/usb-gadget.conf"
    "https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/refs/heads/main/lcd_usb/configure-usb-gadget.service|/etc/systemd/system/configure-usb-gadget.service"
    "https://raw.githubusercontent.com/alinke/pixelcade-linux-builds/refs/heads/main/lcd_usb/pixelcade-startup.sh|/home/pi/pixelcade/system/pixelcade-startup.sh|executable"
)

# Use a different delimiter to avoid conflicts with URLs
DELIMITER="|"

# Create a temporary directory for downloads
TEMP_DIR="/tmp/temp_downloads"
mkdir -p "$TEMP_DIR"

for file_entry in "${FILES[@]}"; do
    # Parse the entry using the custom delimiter
    IFS="$DELIMITER" read -r FILE_URL DEST_PATH PERMISSIONS <<< "$file_entry"

    echo "Processing URL: $FILE_URL"
    echo "Destination: $DEST_PATH"
    echo "Permissions: $PERMISSIONS"

    # Validate that the URL and destination are not empty
    if [[ -z "$FILE_URL" || -z "$DEST_PATH" ]]; then
        echo "Error: Invalid entry in FILES array. Skipping..."
        continue
    fi

    # Temporary file path
    TEMP_FILE="$TEMP_DIR/$(basename "$DEST_PATH")"

    echo "Downloading $FILE_URL..."
    wget -q -O "$TEMP_FILE" "$FILE_URL"

    # Check if wget succeeded
    if [ $? -eq 0 ]; then
        echo "Successfully downloaded $FILE_URL to $TEMP_FILE."

        # Ensure destination directory exists
        DEST_DIR=$(dirname "$DEST_PATH")
        if [ ! -d "$DEST_DIR" ]; then
            echo "Creating directory $DEST_DIR..."
            sudo mkdir -p "$DEST_DIR"
        fi

        # Move the file to its destination
        echo "Moving $TEMP_FILE to $DEST_PATH..."
        sudo mv "$TEMP_FILE" "$DEST_PATH"

        # Set permissions if required
        if [[ "$PERMISSIONS" == "executable" ]]; then
            echo "Setting executable permissions for $DEST_PATH..."
            sudo chmod +x "$DEST_PATH"
        fi
    else
        echo "Failed to download $FILE_URL. Please check the URL or your network connection."
    fi
done

# Clean up the temporary directory
echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

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
