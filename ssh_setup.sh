#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0"
    echo "This script installs and configures everything required for SSH access."
    exit 1
}

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Install OpenSSH Server
echo "Installing OpenSSH Server..."
apt update && apt install -y openssh-server

# Start and enable SSH service
echo "Starting and enabling SSH service..."
systemctl start ssh
systemctl enable ssh

# Allow SSH through UFW firewall
if ufw status | grep -q "Status: active"; then
    echo "Allowing SSH through the firewall..."
    ufw allow ssh
    ufw reload
fi

echo "SSH is now installed and running. You can configure keys and other settings manually."
