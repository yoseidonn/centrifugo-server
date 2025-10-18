# Centrifugo Real-time Messaging Server

Centrifugo is a scalable real-time messaging server written in Go that handles WebSocket connections, presence management, and message broadcasting for the CrewDEV platform.

## 🚀 Quick Start

### Prerequisites
- Redis server running on localhost:6379
- Linux system with systemd (for service installation)

### Installation

1. **Clone and setup:**
   ```bash
   cd /home/yusuf/Software/CrewDEV/centrifugo-server
   sudo ./scripts/setup.sh
   ```

2. **Verify installation:**
   ```bash
   ./scripts/health-check.sh
   ```

3. **Access admin UI:**
   - URL: http://localhost:8000
   - Admin secret: `your-admin-secret` (from config.json)

### Docker Installation

```bash
# Start with Docker Compose
docker-compose up -d

# Check logs
docker-compose logs -f centrifugo
```

## 📋 Configuration

### Main Configuration (`config.json`)

```json
{
  "token_hmac_secret_key": "your-secret-key-here",
  "admin_secret": "your-admin-secret", 
  "api_key": "your-api-key",
  "port": "8000",
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
      "history_ttl": "300s"
    }
  ]
}
```

### Environment Variables

Copy `env.example` to `.env` and customize:

```bash
CENTRIFUGO_PORT=8000
CENTRIFUGO_TOKEN_SECRET=your-secret-key-here
CENTRIFUGO_ADMIN_SECRET=your-admin-secret
CENTRIFUGO_API_KEY=your-api-key
CENTRIFUGO_REDIS_HOST=localhost
CENTRIFUGO_REDIS_PORT=6379
CENTRIFUGO_REDIS_DB=1
```

## 🔧 Service Management

### Systemd Service
```bash
# Check status
sudo systemctl status centrifugo

# View logs
sudo journalctl -u centrifugo -f

# Restart service
sudo systemctl restart centrifugo

# Stop service
sudo systemctl stop centrifugo
```

### Docker Service
```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f centrifugo

# Restart
docker-compose restart centrifugo
```

## 🌐 Endpoints

- **WebSocket**: `ws://localhost:8000/connection/websocket`
- **HTTP API**: `http://localhost:8000/api`
- **Admin UI**: `http://localhost:8000`
- **Health Check**: `http://localhost:8000/health`

## 📡 Channel Namespaces

### Messages Namespace (`messages:`)
- **Purpose**: Text and media messages
- **Channels**: `messages:{server_id}:{channel_id}`
- **Features**: Presence, join/leave events, message history

### Notifications Namespace (`notifications:`)
- **Purpose**: User notifications
- **Channels**: `notifications:{user_id}`
- **Features**: Message history, no presence

### Presence Namespace (`presence:`)
- **Purpose**: Server-wide presence tracking
- **Channels**: `presence:{server_id}`
- **Features**: Presence only, no history

## 🔐 Authentication

### Generate Connection Token
```bash
python3 scripts/generate-token.py "your-secret-key-here" "user123"
```

### Generate Subscription Token
```bash
python3 scripts/generate-token.py "your-secret-key-here" "user123" "messages:1:2"
```

## 📊 Monitoring

### Health Checks
```bash
# Basic health check
curl http://localhost:8000/health

# Detailed health check
./scripts/health-check.sh
```

### Admin UI Features
- Real-time connection monitoring
- Channel statistics
- Message throughput
- Presence information
- Server metrics

## 🔄 Integration with FastAPI

### Channel Naming Convention
```
messages:{server_id}:{channel_id}     # Text/media messages
notifications:{user_id}                # User notifications  
presence:{server_id}                   # Server-wide presence
dm:{user_id_1}:{user_id_2}            # Direct messages
voice:{channel_id}                     # Voice state updates
```

### FastAPI Integration Points
1. **Token Generation**: Generate JWT tokens for client connections
2. **Message Publishing**: Publish messages via HTTP API
3. **Presence Queries**: Query presence information
4. **Channel Management**: Create/manage channels

## 🚨 Troubleshooting

### Common Issues

1. **Service won't start**
   ```bash
   sudo journalctl -u centrifugo -f
   ```

2. **Redis connection failed**
   - Check Redis is running: `redis-cli ping`
   - Verify Redis configuration in config.json

3. **WebSocket connection failed**
   - Check CORS settings in config.json
   - Verify allowed_origins includes your frontend URL

4. **Admin UI not accessible**
   - Check admin_secret in config.json
   - Verify admin and admin_web are set to true

### Debug Mode
Enable debug logging in `config-dev.json`:
```json
{
  "log_level": "debug",
  "debug": true
}
```

## 📚 Documentation

- [API Reference](docs/API.md) - HTTP API and WebSocket protocol
- [Deployment Guide](docs/DEPLOYMENT.md) - Production deployment
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions

## 🔗 Links

- [Centrifugo Documentation](https://centrifugal.dev/)
- [GitHub Repository](https://github.com/centrifugal/centrifugo)
- [Admin UI Demo](http://localhost:8000)

## 📝 License

Centrifugo is released under the MIT License - completely free and open source.
