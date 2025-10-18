#!/bin/bash
# Centrifugo Setup Script for /opt/centrifugo-server
# Moves files to /opt, downloads binary, sets proper permissions, installs systemd service

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Directories and files
CENTRIFUGO_DIR="/opt/centrifugo-server"
LOGS_DIR="$CENTRIFUGO_DIR/logs"
BINARY="$CENTRIFUGO_DIR/centrifugo"
SERVICE_FILE="/etc/systemd/system/centrifugo.service"
CONFIG_FILE="$CENTRIFUGO_DIR/config.json"
SERVICE_TEMPLATE="$CENTRIFUGO_DIR/centrifugo.service.template"

echo -e "${BLUE}🚀 Centrifugo Setup Script${NC}"

# Create centrifugo user if missing
if ! id centrifugo &>/dev/null; then
    echo -e "${YELLOW}👤 Creating system user 'centrifugo'...${NC}"
    sudo useradd --system --no-create-home --shell /bin/false centrifugo
    echo -e "${GREEN}✅ User created${NC}"
else
    echo -e "${GREEN}✅ User 'centrifugo' already exists${NC}"
fi

# Create directories
echo -e "${YELLOW}📁 Creating directories...${NC}"
sudo mkdir -p "$LOGS_DIR"
sudo chown -R centrifugo:centrifugo "$CENTRIFUGO_DIR"
sudo chmod 750 "$CENTRIFUGO_DIR"
sudo chmod 750 "$LOGS_DIR"
echo -e "${GREEN}✅ Directories ready${NC}"

# Download Centrifugo binary
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
    wget -O /tmp/centrifugo.tar.gz "$URL"
    tar -xzf /tmp/centrifugo.tar.gz -C "$CENTRIFUGO_DIR"
    rm /tmp/centrifugo.tar.gz
    chmod +x "$BINARY"
    sudo chown centrifugo:centrifugo "$BINARY"
    echo -e "${GREEN}✅ Binary installed${NC}"
else
    echo -e "${GREEN}✅ Binary already exists${NC}"
fi

# Check config file
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}📝 Creating example config.json...${NC}"
    cat > "$CONFIG_FILE" <<EOF
{
  "token_hmac_secret_key": "your-secret-key-here",
  "admin_password": "admin123",
  "admin_secret": "your-admin-secret",
  "api_key": "your-api-key",
  "http_server": {
    "port": "8000",
    "address": "0.0.0.0"
  },
  "allowed_origins": ["*"],
  "engine": {
    "type": "redis",
    "redis": {
      "address": "redis://localhost:6379",
      "db": 1,
      "prefix": "centrifugo"
    }
  },
  "namespaces": [
    {
      "name": "messages",
      "presence": true,
      "join_leave": true,
      "history_size": 100,
      "history_ttl": "300s",
      "publish": true,
      "subscribe_to_publish": true
    }
  ],
  "log_level": "info",
  "log_file": "logs/centrifugo.log",
  "log_handler": "file"
}
EOF
    sudo chown centrifugo:centrifugo "$CONFIG_FILE"
    sudo chmod 640 "$CONFIG_FILE"
    echo -e "${GREEN}✅ Example config.json created at $CONFIG_FILE${NC}"
fi

# Test configuration
echo -e "${YELLOW}🧪 Testing configuration...${NC}"
sudo -u centrifugo "$BINARY" --config="$CONFIG_FILE" checkconfig || {
    echo -e "${RED}❌ Configuration test failed${NC}"
    exit 1
}
echo -e "${GREEN}✅ Configuration is valid${NC}"

# Copy systemd service template
if [ ! -f "$SERVICE_TEMPLATE" ]; then
    echo -e "${YELLOW}📄 Creating service template...${NC}"
    cat > "$SERVICE_TEMPLATE" <<EOF
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
    echo -e "${GREEN}✅ Service template created at $SERVICE_TEMPLATE${NC}"
fi

# Install systemd service
echo -e "${YELLOW}📋 Installing systemd service...${NC}"
sudo cp "$SERVICE_TEMPLATE" "$SERVICE_FILE"
sudo systemctl daemon-reload
sudo systemctl enable centrifugo
sudo systemctl restart centrifugo

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
echo "Service template: $SERVICE_TEMPLATE"
echo "Systemd service: $SERVICE_FILE"
