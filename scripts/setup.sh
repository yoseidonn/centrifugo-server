#!/bin/bash
# Install and setup Centrifugo as a system service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up Centrifugo real-time messaging server...${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CENTRIFUGO_DIR="$(dirname "$SCRIPT_DIR")"

# Check if config file exists
if [ ! -f "$CENTRIFUGO_DIR/config.json" ]; then
    echo -e "${RED}config.json not found in $CENTRIFUGO_DIR${NC}"
    exit 1
fi

# Download Centrifugo binary (latest version)
echo -e "${YELLOW}Downloading Centrifugo binary...${NC}"
cd /tmp
wget -q https://github.com/centrifugal/centrifugo/releases/download/v5.0.0/centrifugo_5.0.0_linux_amd64.tar.gz
tar -xzf centrifugo_5.0.0_linux_amd64.tar.gz
sudo mv centrifugo /usr/local/bin/
chmod +x /usr/local/bin/centrifugo

# Create centrifugo user
if ! id "centrifugo" &>/dev/null; then
    echo -e "${YELLOW}Creating centrifugo user...${NC}"
    sudo useradd --system --shell /bin/false --home-dir /var/lib/centrifugo --create-home centrifugo
    echo -e "${GREEN}Created centrifugo user${NC}"
else
    echo -e "${GREEN}centrifugo user already exists${NC}"
fi

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
sudo mkdir -p /etc/centrifugo
sudo mkdir -p /opt/centrifugo
sudo mkdir -p /var/log/centrifugo

# Copy configuration
sudo cp "$CENTRIFUGO_DIR/config.json" /etc/centrifugo/
sudo cp "$CENTRIFUGO_DIR/centrifugo.service" /etc/systemd/system/

# Set ownership
sudo chown -R centrifugo:centrifugo /var/lib/centrifugo
sudo chown -R centrifugo:centrifugo /var/log/centrifugo
sudo chown -R centrifugo:centrifugo /opt/centrifugo
sudo chown centrifugo:centrifugo /etc/centrifugo/config.json

# Set permissions
sudo chmod 644 /etc/centrifugo/config.json
sudo chmod 644 /etc/systemd/system/centrifugo.service

# Reload systemd and start service
echo -e "${YELLOW}Starting Centrifugo service...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable centrifugo
sudo systemctl start centrifugo

# Wait a moment for service to start
sleep 3

# Check service status
if sudo systemctl is-active --quiet centrifugo; then
    echo -e "${GREEN}✅ Centrifugo installed and started successfully${NC}"
    echo -e "${GREEN}Admin UI: http://localhost:8000${NC}"
    echo -e "${GREEN}WebSocket: ws://localhost:8000/connection/websocket${NC}"
    echo -e "${GREEN}API: http://localhost:8000/api${NC}"
    echo ""
    echo -e "${YELLOW}Service management:${NC}"
    echo "  Status:    sudo systemctl status centrifugo"
    echo "  Logs:      sudo journalctl -u centrifugo -f"
    echo "  Restart:   sudo systemctl restart centrifugo"
    echo "  Stop:      sudo systemctl stop centrifugo"
else
    echo -e "${RED}❌ Failed to start Centrifugo service${NC}"
    echo -e "${YELLOW}Check logs: sudo journalctl -u centrifugo -f${NC}"
    exit 1
fi

# Clean up
rm -f /tmp/centrifugo_5.0.0_linux_amd64.tar.gz
rm -f /tmp/centrifugo

echo -e "${GREEN}Setup completed!${NC}"
