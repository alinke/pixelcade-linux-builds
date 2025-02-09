#!/bin/bash

# Install i2c-tools if not present
echo "Installing i2c-tools..."
apt-get install -y i2c-tools

# Add i2c group if it doesn't exist
if ! getent group i2c > /dev/null; then
    echo "Creating i2c group..."
    groupadd i2c
fi

# Add user to i2c group (assuming pi is the user)
echo "Adding user pi to i2c group..."
usermod -a -G i2c pi

# Create udev rule for i2c permissions
echo "Creating udev rule for i2c..."
echo 'KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0666"' > /etc/udev/rules.d/10-i2c.rules

# Enable i2c module
echo "Enabling i2c module..."
if ! grep -q "^i2c-dev" /etc/modules; then
    echo "i2c-dev" >> /etc/modules
fi

# Load i2c module immediately
echo "Loading i2c module..."
modprobe i2c-dev

# Set permissions for i2c device
echo "Setting i2c device permissions..."
chown :i2c /dev/i2c-3
chmod 666 /dev/i2c-3

# Reload udev rules
echo "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger

sudo sh -c 'echo "export PATH=\$PATH:/usr/sbin" > /etc/profile.d/usr-sbin-path.sh'

echo "I2C permissions setup complete!"
echo "Note: A system reboot is recommended for all changes to take effect."