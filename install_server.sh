#!/bin/bash

# Default values
FRP_VERSION="0.56.0"
DEFAULT_BIND_PORT="443"
DEFAULT_HTTP_PORT="5010"
DEFAULT_SSH_CLIENTS_PORT="5006"
DEFAULT_HTTPS_PORT="5011"

# Function to select architecture
select_architecture() {
    local choice
    read -p "Select architecture. Enter choice (1-2) [1]: linux_amd64 [2]: linux_arm64 " choice
    case $choice in
        2) echo "linux_arm64" ;;
        *) echo "linux_amd64" ;;  # Default to linux_amd64
    esac
}

# Function to display a menu and get a choice
prompt_for_choice() {
    local prompt="$1"
    local default="$2"
    local choice

    read -p "$prompt [$default]: " choice
    echo "${choice:-$default}"  # Use default if no input is provided
}

echo "FRP Server Installation"

# Check if openssl is installed, if not, install it
if ! command -v openssl &> /dev/null; then
    echo "openssl could not be found. Installing..."
    sudo apt-get update && sudo apt-get install -y openssl
else
    echo "openssl is already installed."
fi

# Function to generate a strong token password
generate_token() {
    local random_string=$(openssl rand -base64 32)
    echo $(echo -n "$random_string" | sha256sum | cut -d' ' -f1)
}

TOKEN=$(generate_token)

# Select architecture
FRP_ARCH=$(select_architecture)

# Select bind port
BIND_PORT=$(prompt_for_choice "Select bind port" "$DEFAULT_BIND_PORT")

# Select external ssh port
SSH_CLIENTS_PORT=$(prompt_for_choice "Select external ssh port" "$DEFAULT_SSH_CLIENTS_PORT")

# Select HTTP port
HTTP_PORT=$(prompt_for_choice "Select HTTP port" "$DEFAULT_HTTP_PORT")

# Select HTTPS port
HTTPS_PORT=$(prompt_for_choice "Select HTTPS port" "$DEFAULT_HTTPS_PORT")

# Download and extract FRP
echo "Downloading FRP v$FRP_VERSION for $FRP_ARCH..."
wget "https://github.com/fatedier/frp/releases/download/v$FRP_VERSION/frp_${FRP_VERSION}_${FRP_ARCH}.tar.gz"
tar xzf "frp_${FRP_VERSION}_${FRP_ARCH}.tar.gz"
cd "frp_${FRP_VERSION}_${FRP_ARCH}"

# Move binaries to /usr/bin
echo "Installing FRP..."
sudo mv frps /usr/bin

# Create configuration directory
sudo mkdir -p /etc/frps

# Create FRP configuration file
echo "Creating FRP configuration filehj..."
cat << EOF | sudo tee /etc/frps/frps.toml
bindPort = $BIND_PORT
tcpmuxHTTPConnectPort = $SSH_CLIENTS_PORT 
vhostHTTPPort = $HTTP_PORT
vhostHTTPSPort = $HTTPS_PORT
auth.method = "token"
auth.token = "$TOKEN"
EOF

# Create systemd service file
echo "Creating systemd service file for FRP..."
cat << EOF | sudo tee /etc/systemd/system/frps.service
[Unit]
Description=FRP Server
After=network.target

[Service]
ExecStart=/usr/bin/frps -c /etc/frps/frps.toml
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

# Enable and start FRP service
echo "Enabling and starting FRP service..."
sudo systemctl enable frps
sudo systemctl start frps

# Clean up
rm -rf frp*

echo "FRP Server installation and setup completed!"
