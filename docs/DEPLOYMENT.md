# Centrifugo Deployment Guide

This guide covers production deployment of Centrifugo for the CrewDEV platform.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Load Balancer │    │   Centrifugo 1  │    │   Centrifugo 2  │
│   (nginx)       │────│   Port 8000     │    │   Port 8001     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │
                                └────────┬───────────────┘
                                         │
                                ┌─────────────────┐
                                │   Redis Cluster │
                                │   Port 6379     │
                                └─────────────────┘
```

## 🚀 Production Setup

### 1. Server Requirements

**Minimum Requirements:**
- CPU: 2 cores
- RAM: 4GB
- Storage: 20GB SSD
- Network: 1Gbps

**Recommended:**
- CPU: 4+ cores
- RAM: 8GB+
- Storage: 50GB+ SSD
- Network: 10Gbps

### 2. Redis Setup

**Redis Configuration (`redis.conf`):**
```ini
# Memory settings
maxmemory 2gb
maxmemory-policy allkeys-lru

# Persistence
save 900 1
save 300 10
save 60 10000

# Network
bind 0.0.0.0
port 6379
timeout 300

# Security
requirepass your-redis-password
```

**Redis Cluster Setup:**
```bash
# Create Redis cluster
redis-cli --cluster create \
  192.168.1.10:6379 \
  192.168.1.11:6379 \
  192.168.1.12:6379 \
  --cluster-replicas 1
```

### 3. Centrifugo Configuration

**Production Config (`config-prod.json`):**
```json
{
  "token_hmac_secret_key": "your-production-secret-key",
  "admin_secret": "your-production-admin-secret",
  "api_key": "your-production-api-key",
  "admin": true,
  "admin_web": true,
  "port": "8000",
  "engine": {
    "type": "redis",
    "redis": {
      "address": "redis://192.168.1.10:6379",
      "password": "your-redis-password",
      "db": 1,
      "prefix": "centrifugo",
      "pool_size": 256,
      "min_idle_conns": 10
    }
  },
  "allowed_origins": [
    "https://crew-tr.com",
    "https://app.crew-tr.com"
  ],
  "namespaces": [
    {
      "name": "messages",
      "presence": true,
      "join_leave": true,
      "history_size": 1000,
      "history_ttl": "3600s",
      "recover": true,
      "publish": true
    },
    {
      "name": "notifications",
      "presence": false,
      "join_leave": false,
      "history_size": 100,
      "history_ttl": "300s"
    },
    {
      "name": "presence",
      "presence": true,
      "join_leave": true,
      "history_size": 0
    }
  ],
  "log_level": "info",
  "log_file": "/var/log/centrifugo/centrifugo.log",
  "log_rotation": true,
  "log_rotation_max_size": "100MB",
  "log_rotation_max_age": "7",
  "log_rotation_max_backups": "10"
}
```

### 4. Load Balancer Configuration

**Nginx Configuration (`nginx.conf`):**
```nginx
upstream centrifugo {
    least_conn;
    server 127.0.0.1:8000 max_fails=3 fail_timeout=30s;
    server 127.0.0.1:8001 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name centrifugo.crew-tr.com;
    
    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name centrifugo.crew-tr.com;
    
    # SSL Configuration
    ssl_certificate /etc/ssl/certs/crew-tr.com.crt;
    ssl_certificate_key /etc/ssl/private/crew-tr.com.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    
    # WebSocket proxy
    location /connection/websocket {
        proxy_pass http://centrifugo;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }
    
    # HTTP API proxy
    location /api {
        proxy_pass http://centrifugo;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Admin UI proxy
    location / {
        proxy_pass http://centrifugo;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 5. Systemd Service Configuration

**Multi-instance Setup (`centrifugo@.service`):**
```ini
[Unit]
Description=Centrifugo Real-time Messaging Server (Instance %i)
Documentation=https://centrifugal.dev/
After=network.target redis.service
Wants=redis.service

[Service]
Type=simple
User=centrifugo
Group=centrifugo
WorkingDirectory=/opt/centrifugo
ExecStart=/usr/local/bin/centrifugo --config=/etc/centrifugo/config-%i.json
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=centrifugo-%i

# Security
NoNewPrivileges=true
PrivateTmp=true

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
```

**Service Management:**
```bash
# Enable multiple instances
sudo systemctl enable centrifugo@1
sudo systemctl enable centrifugo@2

# Start instances
sudo systemctl start centrifugo@1
sudo systemctl start centrifugo@2

# Check status
sudo systemctl status centrifugo@1
sudo systemctl status centrifugo@2
```

### 6. Monitoring Setup

**Prometheus Configuration:**
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'centrifugo'
    static_configs:
      - targets: ['localhost:8000', 'localhost:8001']
    metrics_path: '/metrics'
    scrape_interval: 15s
```

**Grafana Dashboard:**
- Import Centrifugo dashboard from Grafana.com
- Configure alerts for connection count, error rate, latency

**Health Check Script:**
```bash
#!/bin/bash
# /opt/centrifugo/health-check.sh

for port in 8000 8001; do
    if ! curl -s -f http://localhost:$port/health > /dev/null; then
        echo "Centrifugo on port $port is not responding"
        systemctl restart centrifugo@$((port-7999))
    fi
done
```

### 7. Security Configuration

**Firewall Rules:**
```bash
# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow Redis (internal only)
ufw allow from 192.168.1.0/24 to any port 6379

# Allow Centrifugo (internal only)
ufw allow from 192.168.1.0/24 to any port 8000
ufw allow from 192.168.1.0/24 to any port 8001
```

**SSL Certificate Setup:**
```bash
# Generate SSL certificate with Let's Encrypt
certbot --nginx -d centrifugo.crew-tr.com
```

### 8. Backup Strategy

**Redis Backup:**
```bash
#!/bin/bash
# /opt/centrifugo/backup-redis.sh

BACKUP_DIR="/opt/backups/redis"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup Redis data
redis-cli --rdb $BACKUP_DIR/redis_backup_$DATE.rdb

# Compress backup
gzip $BACKUP_DIR/redis_backup_$DATE.rdb

# Keep only last 7 days
find $BACKUP_DIR -name "redis_backup_*.rdb.gz" -mtime +7 -delete
```

**Configuration Backup:**
```bash
#!/bin/bash
# /opt/centrifugo/backup-config.sh

BACKUP_DIR="/opt/backups/config"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR
tar -czf $BACKUP_DIR/centrifugo_config_$DATE.tar.gz /etc/centrifugo/
```

### 9. Performance Tuning

**System Limits:**
```bash
# /etc/security/limits.conf
centrifugo soft nofile 65536
centrifugo hard nofile 65536
centrifugo soft nproc 4096
centrifugo hard nproc 4096
```

**Kernel Parameters:**
```bash
# /etc/sysctl.conf
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.core.netdev_max_backlog = 5000
```

**Redis Tuning:**
```ini
# redis.conf
tcp-keepalive 60
tcp-backlog 511
timeout 0
```

### 10. Deployment Checklist

**Pre-deployment:**
- [ ] Redis cluster configured and tested
- [ ] SSL certificates installed
- [ ] Firewall rules configured
- [ ] Monitoring setup complete
- [ ] Backup scripts tested
- [ ] Load balancer configured

**Deployment:**
- [ ] Deploy Centrifugo binaries
- [ ] Configure systemd services
- [ ] Start Centrifugo instances
- [ ] Verify health checks
- [ ] Test WebSocket connections
- [ ] Test HTTP API
- [ ] Verify admin UI access

**Post-deployment:**
- [ ] Monitor connection counts
- [ ] Check error rates
- [ ] Verify message delivery
- [ ] Test failover scenarios
- [ ] Performance benchmarks
- [ ] Security audit

### 11. Scaling Considerations

**Horizontal Scaling:**
- Add more Centrifugo instances behind load balancer
- Use Redis cluster for engine scaling
- Implement sticky sessions for WebSocket connections

**Vertical Scaling:**
- Increase server resources (CPU, RAM)
- Optimize Redis memory usage
- Tune Centrifugo configuration parameters

**Geographic Distribution:**
- Deploy Centrifugo instances in multiple regions
- Use Redis replication across regions
- Implement client-side region selection

## 📊 Performance Metrics

**Key Metrics to Monitor:**
- Connection count per instance
- Message throughput (messages/second)
- API response time
- WebSocket connection latency
- Redis memory usage
- CPU and memory utilization

**Alert Thresholds:**
- Connection count > 80% of capacity
- Error rate > 1%
- Response time > 100ms
- Memory usage > 90%
- Redis memory > 80%
