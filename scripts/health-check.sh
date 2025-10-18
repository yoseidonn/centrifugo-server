#!/bin/bash
# Health check for Centrifugo server

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Checking Centrifugo server health...${NC}"

# Check if service is running
if ! systemctl is-active --quiet centrifugo; then
    echo -e "${RED}❌ Centrifugo service is not running${NC}"
    exit 1
fi

# Check HTTP endpoint
if curl -s -f http://localhost:8000/health > /dev/null; then
    echo -e "${GREEN}✅ Centrifugo HTTP endpoint is responding${NC}"
else
    echo -e "${RED}❌ Centrifugo HTTP endpoint is not responding${NC}"
    exit 1
fi

# Check WebSocket endpoint
if curl -s -f http://localhost:8000/connection/websocket > /dev/null; then
    echo -e "${GREEN}✅ Centrifugo WebSocket endpoint is available${NC}"
else
    echo -e "${RED}❌ Centrifugo WebSocket endpoint is not available${NC}"
    exit 1
fi

# Get server info
echo -e "${YELLOW}Server information:${NC}"
curl -s http://localhost:8000/api | jq '.' 2>/dev/null || echo "API endpoint available but jq not installed for pretty printing"

echo -e "${GREEN}✅ Centrifugo server is healthy${NC}"
