#!/bin/bash

# Centrifugo Setup Script
# This script guides you through setting up Centrifugo with proper configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CENTRIFUGO_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🚀 Centrifugo Setup Script${NC}"
echo -e "${BLUE}==========================${NC}"
echo ""

# Function to check if file exists
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✅ Found: $1${NC}"
        return 0
    else
        echo -e "${RED}❌ Missing: $1${NC}"
        return 1
    fi
}

# Function to create .env file
create_env_file() {
    echo -e "${YELLOW}📝 Creating .env file...${NC}"
    echo ""
    echo "Please create a .env file in the centrifugo-server directory."
    echo "You can copy from env.example and modify the values:"
    echo ""
    echo -e "${BLUE}cp env.example .env${NC}"
    echo ""
    echo "Then edit .env with your actual values:"
    echo "- CENTRIFUGO_PORT: Port for Centrifugo (default: 8000)"
    echo "- CENTRIFUGO_TOKEN_SECRET: Secret key for JWT tokens"
    echo "- CENTRIFUGO_ADMIN_SECRET: Admin secret for API access"
    echo "- CENTRIFUGO_API_KEY: API key for FastAPI integration"
    echo "- CENTRIFUGO_REDIS_HOST: Redis host (default: localhost)"
    echo "- CENTRIFUGO_REDIS_PORT: Redis port (default: 6379)"
    echo "- CENTRIFUGO_REDIS_DB: Redis database number (default: 1)"
    echo ""
    echo -e "${YELLOW}Run this script again after creating the .env file.${NC}"
}

# Function to create config.json
create_config_file() {
    echo -e "${YELLOW}📝 Creating config.json file...${NC}"
    echo ""
    echo "Please create a config.json file in the centrifugo-server directory."
    echo "You can copy from config-dev.json and modify the values:"
    echo ""
    echo -e "${BLUE}cp config-dev.json config.json${NC}"
    echo ""
    echo "Then edit config.json with your actual values:"
    echo "- token_hmac_secret_key: Must match CENTRIFUGO_TOKEN_SECRET from .env"
    echo "- admin_secret: Must match CENTRIFUGO_ADMIN_SECRET from .env"
    echo "- api_key: Must match CENTRIFUGO_API_KEY from .env"
    echo "- port: Must match CENTRIFUGO_PORT from .env"
    echo "- redis.address: Must match your Redis configuration"
    echo ""
    echo -e "${YELLOW}Run this script again after creating the config.json file.${NC}"
}

# Step 1: Check for .env file
echo -e "${BLUE}Step 1: Checking for .env file${NC}"
if ! check_file "$CENTRIFUGO_DIR/.env"; then
    create_env_file
    echo ""
    echo -e "${YELLOW}Please run this script again after creating the .env file.${NC}"
    exit 0
fi

# Step 2: Check for config.json file
echo -e "${BLUE}Step 2: Checking for config.json file${NC}"
if ! check_file "$CENTRIFUGO_DIR/config.json"; then
    create_config_file
    echo ""
    echo -e "${YELLOW}Please run this script again after creating the config.json file.${NC}"
    exit 0
fi

# Step 3: All files exist, proceed with setup
echo -e "${BLUE}Step 3: All configuration files found! Proceeding with setup...${NC}"
echo ""

# Check if Centrifugo binary exists
CENTRIFUGO_BINARY="$CENTRIFUGO_DIR/centrifugo"
if [ ! -f "$CENTRIFUGO_BINARY" ]; then
    echo -e "${YELLOW}📥 Downloading Centrifugo binary...${NC}"
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="arm"
            ;;
        *)
            echo -e "${RED}❌ Unsupported architecture: $ARCH${NC}"
            exit 1
            ;;
    esac
    
    # Detect OS
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    # Download Centrifugo
    VERSION="5.4.0"
    DOWNLOAD_URL="https://github.com/centrifugal/centrifugo/releases/download/v${VERSION}/centrifugo_${VERSION}_${OS}_${ARCH}.tar.gz"
    
    echo "Downloading from: $DOWNLOAD_URL"
    cd "$CENTRIFUGO_DIR"
    wget -O centrifugo.tar.gz "$DOWNLOAD_URL"
    tar -xzf centrifugo.tar.gz
    rm centrifugo.tar.gz
    
    # Make binary executable
    chmod +x centrifugo
    
    echo -e "${GREEN}✅ Centrifugo binary downloaded successfully${NC}"
else
    echo -e "${GREEN}✅ Centrifugo binary already exists${NC}"
fi

# Test configuration
echo -e "${YELLOW}🧪 Testing configuration...${NC}"
cd "$CENTRIFUGO_DIR"
if ./centrifugo --config=config.json --check-config; then
    echo -e "${GREEN}✅ Configuration is valid${NC}"
else
    echo -e "${RED}❌ Configuration test failed${NC}"
    echo "Please check your config.json file for errors."
    exit 1
fi

# Create logs directory
echo -e "${YELLOW}📁 Creating logs directory...${NC}"
mkdir -p "$CENTRIFUGO_DIR/logs"

# Create centrifugo user if it doesn't exist
echo -e "${YELLOW}👤 Creating centrifugo user...${NC}"
if ! id "centrifugo" &>/dev/null; then
    sudo useradd --system --no-create-home --shell /bin/false centrifugo
    echo -e "${GREEN}✅ Created centrifugo user${NC}"
else
    echo -e "${GREEN}✅ Centrifugo user already exists${NC}"
fi

# Copy service file to systemd directory
echo -e "${YELLOW}📋 Installing systemd service...${NC}"
sudo cp "$CENTRIFUGO_DIR/centrifugo.service" /etc/systemd/system/
echo -e "${GREEN}✅ Service file installed${NC}"

# Update service file paths
echo -e "${YELLOW}🔧 Updating service file paths...${NC}"
sudo sed -i "s|WorkingDirectory=/opt/centrifugo|WorkingDirectory=$CENTRIFUGO_DIR|g" /etc/systemd/system/centrifugo.service
sudo sed -i "s|ExecStart=/usr/local/bin/centrifugo|ExecStart=$CENTRIFUGO_BINARY|g" /etc/systemd/system/centrifugo.service
sudo sed -i "s|--config=/etc/centrifugo/config.json|--config=$CENTRIFUGO_DIR/config.json|g" /etc/systemd/system/centrifugo.service
echo -e "${GREEN}✅ Service file paths updated${NC}"

# Set proper ownership
echo -e "${YELLOW}🔐 Setting proper ownership...${NC}"
sudo chown -R centrifugo:centrifugo "$CENTRIFUGO_DIR"
sudo chmod +x "$CENTRIFUGO_BINARY"
echo -e "${GREEN}✅ Ownership set to centrifugo:centrifugo${NC}"

# Reload systemd and enable service
echo -e "${YELLOW}🔄 Reloading systemd and enabling service...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable centrifugo
echo -e "${GREEN}✅ Service enabled${NC}"

# Start the service
echo -e "${YELLOW}🚀 Starting Centrifugo service...${NC}"
sudo systemctl start centrifugo

# Check service status
echo -e "${YELLOW}📊 Checking service status...${NC}"
sleep 2
if sudo systemctl is-active --quiet centrifugo; then
    echo -e "${GREEN}✅ Centrifugo is running successfully!${NC}"
else
    echo -e "${RED}❌ Centrifugo failed to start${NC}"
    echo "Check the logs with: sudo journalctl -u centrifugo -f"
    exit 1
fi

# Display service information
echo ""
echo -e "${BLUE}🎉 Centrifugo Setup Complete!${NC}"
echo -e "${BLUE}============================${NC}"
echo ""
echo -e "${GREEN}Service Status:${NC}"
sudo systemctl status centrifugo --no-pager -l
echo ""
echo -e "${GREEN}Useful Commands:${NC}"
echo "  Start:   sudo systemctl start centrifugo"
echo "  Stop:    sudo systemctl stop centrifugo"
echo "  Restart: sudo systemctl restart centrifugo"
echo "  Status:  sudo systemctl status centrifugo"
echo "  Logs:    sudo journalctl -u centrifugo -f"
echo ""
echo -e "${GREEN}Configuration Files:${NC}"
echo "  Service: /etc/systemd/system/centrifugo.service"
echo "  Config:  $CENTRIFUGO_DIR/config.json"
echo "  Binary:  $CENTRIFUGO_BINARY"
echo "  Logs:    $CENTRIFUGO_DIR/logs/"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "1. Update your FastAPI .env file with Centrifugo configuration"
echo "2. Test the connection from your FastAPI backend"
echo "3. Configure your frontend to connect to Centrifugo"
echo ""
echo -e "${BLUE}Happy coding! 🚀${NC}"
