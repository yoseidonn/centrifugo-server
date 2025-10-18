#!/bin/bash
# Centrifugo Setup Script for /opt/centrifugo-server
# Moves all files to /opt, installs systemd service, and sets proper permissions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Define directories
CENTRIFUGO_DIR="/opt/centrifugo-server"
LOGS_DIR="$CENTRIFUGO_DIR/logs"
SERVICE_FILE="/etc/systemd/system/centrifugo.service"
CONFIG_FILE="$CENTRIFUGO_DIR/config.json"
BINARY="$CENTRIFUGO_DIR/centrifugo"

echo -e "${BLUE}🚀 Centrifugo Setup Script${NC}"
echo ""

# Create directories
echo -e "${YELLOW}📁 Creating /opt/centrifugo-server and logs...${NC}"
sudo mkdir -p "$LOGS_DIR"
sudo chown -R centrifugo:centrifugo "$CENTRIFUGO_DIR"
sudo chmod 750 "$CENTRIFUGO_DIR"
sudo chmod 750 "$LOGS_DIR"
echo -e "${GREEN}✅ Directories created${NC}"

# Download Centrifugo binary if not exists
if [ ! -f "$BINARY" ]; then
    echo -e "${YELLOW}📥 Downloading Centrifugo binary...${NC}"
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l) ARCH="arm" ;;
        *) echo -e "${RED}❌ Unsupported architecture: $ARCH${NC}"; exit 1 ;;
    esac

    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    VERSION="5.4.0"
    URL="https://github.com/centrifugal/centrifugo/releases/download/v${VERSION}/centrifugo_${VERSION}_${OS}_${ARCH}.tar.gz"

    echo "Downloading from: $URL"
    wget -O /tmp/centrifugo.tar.gz "$URL"
    tar -xzf /tmp/centrifugo.tar.gz -C "$CENTRIFUGO_DIR"
    rm /tmp/centrifugo.tar.gz
    chmod +x "$BINARY"
    echo -e "${GREEN}✅ Centrifugo binary installed${NC}"
else
    echo -e "${GREEN}✅ Centrifugo binary already exists${NC}"
fi

# Check config file
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Missing config.json file in $CENTRIFUGO_DIR${NC}"
    echo "Create a config.json based on the example provided in the repo."
    exit 1
fi

# Test config
echo -e "${YELLOW}🧪 Testing configuration...${NC}"
if sudo -u centrifugo "$BINARY" --config="$CONFIG_FILE" checkconfig; then
    echo -e "${GREEN}✅ Configuration is valid${NC}"
else
    echo -e "${RED}❌ Configuration test failed${NC}"
    exit 1
fi

# Create systemd service
echo -e "${YELLOW}📋 Installing systemd service...${NC}"
sudo tee "$SERVICE_FILE" >/dev/null <<EOF
[Unit]
Description=Centrifugo Real-time Messaging Server
Documentation=https://centrifugal.dev/
After=network.target redis.service
Wants=redis.service

[Service]
Type=simple
User=centrifugo
Group=centrifugo
WorkingDirectory=$CENTRIFUGO_DIR
ExecStart=$BINARY --config=$CONFIG_FILE
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=centrifugo

# Security
NoNewPrivileges=true
PrivateTmp=true

# Resource limits
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable centrifugo
sudo systemctl start centrifugo

# Check service
echo -e "${YELLOW}📊 Checking service status...${NC}"
sleep 2
if systemctl is-active --quiet centrifugo; then
    echo -e "${GREEN}✅ Centrifugo is running successfully!${NC}"
else
    echo -e "${RED}❌ Centrifugo failed to start${NC}"
    echo "Check logs: sudo journalctl -u centrifugo -f"
    exit 1
fi

echo -e "${BLUE}🎉 Setup complete!${NC}"
echo "Logs: $LOGS_DIR"
echo "Config: $CONFIG_FILE"
echo "Binary: $BINARY"
echo "Service: $SERVICE_FILE"
