#!/bin/bash

# Default version
FRP_VERSION="0.56.0"

# Function to select architecture
select_architecture() {
    local choice
    read -p "Select architecture (1 for linux_amd64, 2 for linux_arm64) [1]: " choice
    case $choice in
        2) echo "linux_arm64" ;;
        *) echo "linux_amd64" ;;
    esac
}

# Function to prompt for user input
prompt_for_input() {
    local prompt_message="$1"
    local default_value="$2"
    read -p "$prompt_message [$default_value]: " input
    echo "${input:-$default_value}"
}

# Prompt for all configurations
FRP_ARCH=$(select_architecture)
SERVER_ADDR=$(prompt_for_input "Enter your FRP server address" "server_address_here")
SERVER_PORT=$(prompt_for_input "Enter your FRP server port" "443")
TOKEN=$(prompt_for_input "Enter your FRP token" "token_here")
SSH_REMOTE_PORT=$(prompt_for_input "Enter SSH remote port" "5006")
WEB_REMOTE_PORT=$(prompt_for_input "Enter web remote port" "5010")
SUBDOMAIN=$(prompt_for_input "Enter subdomain" "hostname.frpsserver.com") 
HTTP_USER=$(prompt_for_input "Enter HTTP user" "user")
HTTP_PASSWORD=$(prompt_for_input "Enter HTTP password" "password")
HOSTNAME=$(prompt_for_input "Enter server name" "Server")

# Download and extract FRP client
echo "Downloading FRP client v$FRP_VERSION for $FRP_ARCH..."
wget "https://github.com/fatedier/frp/releases/download/v$FRP_VERSION/frp_${FRP_VERSION}_${FRP_ARCH}.tar.gz"
tar xzf "frp_${FRP_VERSION}_${FRP_ARCH}.tar.gz"
cd "frp_${FRP_VERSION}_${FRP_ARCH}"

# Install the FRP client binary
echo "Installing FRP client..."
sudo mv frpc /usr/bin

# Create configuration directory
sudo mkdir -p /etc/frp

# Generate FRP client configuration file in TOML format
echo "Creating FRP client configuration file..."
cat << EOF | sudo tee /etc/frp/frpc.toml
serverAddr = "$SERVER_ADDR"
serverPort = $SERVER_PORT
auth.method = "token"
auth.token = "$TOKEN"
user = "$HOSTNAME"

[[proxies]]
name="ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = $SSH_REMOTE_PORT
transport.useEncryption = true 
transport.useCompression = true 

[[proxies]]
name="httpweb"
type = "http"
localIP = "127.0.0.1"
localPort = 8080
remotePort = $WEB_REMOTE_PORT
httpUser = "$HTTP_USER"
httpPassword = "$HTTP_PASSWORD"
customDomains = ["$SUBDOMAIN"]
EOF

# Create systemd service file for the FRP client
echo "Creating systemd service file for FRP client..."
cat << EOF | sudo tee /etc/systemd/system/frpc.service
[Unit]
Description=FRP Client
After=network.target

[Service]
ExecStart=/usr/bin/frpc -c /etc/frp/frpc.toml
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the FRP client service
echo "Enabling and starting FRP client service..."
sudo systemctl enable frpc
sudo systemctl start frpc

echo "FRP Client installation and setup completed!"

# Clean up downloaded files
echo "Cleaning up downloaded files..."
cd ..
rm -rf "frp_${FRP_VERSION}_${FRP_ARCH}.tar.gz" "frp_${FRP_VERSION}_${FRP_ARCH}"

echo "Cleanup completed."

