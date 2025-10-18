# Centrifugo Troubleshooting Guide

This guide covers common issues and solutions for Centrifugo real-time messaging server.

## 🚨 Common Issues

### 1. Service Won't Start

**Symptoms:**
- `systemctl status centrifugo` shows failed status
- Service keeps restarting
- No response on port 8000

**Diagnosis:**
```bash
# Check service status
sudo systemctl status centrifugo

# View detailed logs
sudo journalctl -u centrifugo -f

# Check if port is in use
sudo netstat -tlnp | grep 8000
```

**Solutions:**

**Port Already in Use:**
```bash
# Find process using port 8000
sudo lsof -i :8000

# Kill the process
sudo kill -9 <PID>

# Restart Centrifugo
sudo systemctl restart centrifugo
```

**Permission Issues:**
```bash
# Check file permissions
ls -la /etc/centrifugo/config.json
ls -la /usr/local/bin/centrifugo

# Fix permissions
sudo chown centrifugo:centrifugo /etc/centrifugo/config.json
sudo chmod 644 /etc/centrifugo/config.json
sudo chmod +x /usr/local/bin/centrifugo
```

**Configuration Errors:**
```bash
# Validate configuration
/usr/local/bin/centrifugo --config=/etc/centrifugo/config.json --check-config

# Test configuration
/usr/local/bin/centrifugo --config=/etc/centrifugo/config.json --test-config
```

### 2. Redis Connection Failed

**Symptoms:**
- Centrifugo starts but can't connect to Redis
- Error: "dial tcp: connection refused"
- Redis engine not working

**Diagnosis:**
```bash
# Check Redis status
sudo systemctl status redis
redis-cli ping

# Check Redis configuration
redis-cli info server

# Test Redis connection
redis-cli -h localhost -p 6379 ping
```

**Solutions:**

**Redis Not Running:**
```bash
# Start Redis service
sudo systemctl start redis
sudo systemctl enable redis

# Check Redis logs
sudo journalctl -u redis -f
```

**Wrong Redis Configuration:**
```json
// Check config.json Redis settings
{
  "engine": {
    "type": "redis",
    "redis": {
      "address": "redis://localhost:6379",
      "db": 1,
      "password": "your-password"  // if Redis has password
    }
  }
}
```

**Redis Authentication:**
```bash
# Test Redis with password
redis-cli -a your-password ping

# Update Centrifugo config with password
```

### 3. WebSocket Connection Failed

**Symptoms:**
- Clients can't connect to WebSocket
- CORS errors in browser
- Connection timeout

**Diagnosis:**
```bash
# Test WebSocket endpoint
curl -i -N -H "Connection: Upgrade" \
     -H "Upgrade: websocket" \
     -H "Sec-WebSocket-Version: 13" \
     -H "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" \
     http://localhost:8000/connection/websocket

# Check CORS settings
curl -H "Origin: http://localhost:5173" \
     -H "Access-Control-Request-Method: GET" \
     -H "Access-Control-Request-Headers: authorization" \
     -X OPTIONS \
     http://localhost:8000/connection/websocket
```

**Solutions:**

**CORS Issues:**
```json
// Update config.json
{
  "allowed_origins": [
    "http://localhost:5173",
    "https://crew-tr.com",
    "https://app.crew-tr.com"
  ]
}
```

**Firewall Blocking:**
```bash
# Check firewall status
sudo ufw status

# Allow port 8000
sudo ufw allow 8000/tcp

# Check iptables
sudo iptables -L
```

**Token Issues:**
```bash
# Generate valid token
python3 scripts/generate-token.py "your-secret-key-here" "user123"

# Test token
curl -H "Authorization: Bearer <token>" \
     http://localhost:8000/connection/websocket
```

### 4. Admin UI Not Accessible

**Symptoms:**
- Can't access http://localhost:8000
- 404 or 403 errors
- Admin UI not loading

**Diagnosis:**
```bash
# Check if admin is enabled
curl http://localhost:8000/

# Check admin configuration
grep -A 5 "admin" /etc/centrifugo/config.json
```

**Solutions:**

**Admin Not Enabled:**
```json
// Update config.json
{
  "admin": true,
  "admin_web": true,
  "admin_secret": "your-admin-secret"
}
```

**Wrong Admin Secret:**
```bash
# Access admin UI with correct secret
# URL: http://localhost:8000/?secret=your-admin-secret
```

### 5. High Memory Usage

**Symptoms:**
- Centrifugo using too much RAM
- System running out of memory
- Performance degradation

**Diagnosis:**
```bash
# Check memory usage
ps aux | grep centrifugo
free -h

# Check Redis memory
redis-cli info memory

# Monitor memory over time
watch -n 1 'ps aux | grep centrifugo'
```

**Solutions:**

**Reduce History Size:**
```json
// Update config.json
{
  "namespaces": [
    {
      "name": "messages",
      "history_size": 50,  // Reduce from 100
      "history_ttl": "300s"
    }
  ]
}
```

**Redis Memory Optimization:**
```ini
# redis.conf
maxmemory 2gb
maxmemory-policy allkeys-lru
```

**System Limits:**
```bash
# Check system limits
ulimit -a

# Increase limits
echo "centrifugo soft nofile 65536" >> /etc/security/limits.conf
echo "centrifugo hard nofile 65536" >> /etc/security/limits.conf
```

### 6. Message Delivery Issues

**Symptoms:**
- Messages not reaching clients
- Delayed message delivery
- Messages lost

**Diagnosis:**
```bash
# Check Centrifugo logs
sudo journalctl -u centrifugo -f

# Test message publishing
curl -X POST http://localhost:8000/api \
     -H "Authorization: apikey your-api-key" \
     -H "Content-Type: application/json" \
     -d '{
       "method": "publish",
       "params": {
         "channel": "test",
         "data": {"message": "test"}
       }
     }'
```

**Solutions:**

**Redis Engine Issues:**
```bash
# Check Redis connectivity
redis-cli ping

# Check Redis logs
sudo journalctl -u redis -f

# Restart Redis
sudo systemctl restart redis
```

**Channel Configuration:**
```json
// Ensure channels are properly configured
{
  "namespaces": [
    {
      "name": "messages",
      "publish": true,  // Allow publishing
      "subscribe": true  // Allow subscribing
    }
  ]
}
```

### 7. Performance Issues

**Symptoms:**
- Slow message delivery
- High CPU usage
- Connection timeouts

**Diagnosis:**
```bash
# Check CPU usage
top -p $(pgrep centrifugo)

# Check connection count
curl http://localhost:8000/api -H "Authorization: apikey your-api-key" \
     -d '{"method": "channels"}'

# Monitor system resources
htop
```

**Solutions:**

**Optimize Configuration:**
```json
// Update config.json for performance
{
  "engine": {
    "type": "redis",
    "redis": {
      "pool_size": 256,        // Increase pool size
      "min_idle_conns": 10     // Keep connections alive
    }
  },
  "log_level": "warn"  // Reduce logging
}
```

**System Optimization:**
```bash
# Increase file descriptor limits
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# Optimize kernel parameters
echo "net.core.somaxconn = 65535" >> /etc/sysctl.conf
sysctl -p
```

## 🔧 Debug Commands

### Service Management
```bash
# Check service status
sudo systemctl status centrifugo

# View logs
sudo journalctl -u centrifugo -f

# Restart service
sudo systemctl restart centrifugo

# Stop service
sudo systemctl stop centrifugo

# Start service
sudo systemctl start centrifugo
```

### Configuration Testing
```bash
# Validate configuration
/usr/local/bin/centrifugo --config=/etc/centrifugo/config.json --check-config

# Test configuration
/usr/local/bin/centrifugo --config=/etc/centrifugo/config.json --test-config

# Run in debug mode
/usr/local/bin/centrifugo --config=/etc/centrifugo/config.json --debug
```

### Network Testing
```bash
# Test HTTP endpoint
curl http://localhost:8000/health

# Test WebSocket
wscat -c ws://localhost:8000/connection/websocket

# Test API
curl -X POST http://localhost:8000/api \
     -H "Authorization: apikey your-api-key" \
     -H "Content-Type: application/json" \
     -d '{"method": "info"}'
```

### Redis Testing
```bash
# Test Redis connection
redis-cli ping

# Check Redis info
redis-cli info

# Monitor Redis commands
redis-cli monitor

# Check Redis keys
redis-cli keys "centrifugo:*"
```

## 📊 Monitoring Commands

### Health Checks
```bash
# Basic health check
curl -f http://localhost:8000/health || echo "Centrifugo is down"

# Detailed health check
./scripts/health-check.sh

# Check multiple instances
for port in 8000 8001; do
    curl -f http://localhost:$port/health || echo "Port $port is down"
done
```

### Performance Monitoring
```bash
# Check connection count
curl -s http://localhost:8000/api \
     -H "Authorization: apikey your-api-key" \
     -d '{"method": "channels"}' | jq '.result.channels'

# Monitor system resources
watch -n 1 'ps aux | grep centrifugo | head -5'

# Check Redis memory
redis-cli info memory | grep used_memory_human
```

### Log Analysis
```bash
# Search for errors
sudo journalctl -u centrifugo | grep -i error

# Search for specific patterns
sudo journalctl -u centrifugo | grep "connection"

# Monitor logs in real-time
sudo journalctl -u centrifugo -f
```

## 🆘 Emergency Procedures

### Service Recovery
```bash
# Quick restart
sudo systemctl restart centrifugo

# Force restart if stuck
sudo systemctl stop centrifugo
sudo pkill -f centrifugo
sudo systemctl start centrifugo

# Emergency stop
sudo systemctl stop centrifugo
sudo pkill -9 centrifugo
```

### Configuration Recovery
```bash
# Restore from backup
sudo cp /opt/backups/config/centrifugo_config_latest.tar.gz /tmp/
cd /tmp && tar -xzf centrifugo_config_latest.tar.gz
sudo cp -r etc/centrifugo/* /etc/centrifugo/

# Reset to default config
sudo cp /opt/centrifugo/config.json /etc/centrifugo/
sudo systemctl restart centrifugo
```

### Data Recovery
```bash
# Restore Redis from backup
sudo systemctl stop redis
sudo cp /opt/backups/redis/redis_backup_latest.rdb.gz /tmp/
cd /tmp && gunzip redis_backup_latest.rdb.gz
sudo cp redis_backup_latest.rdb /var/lib/redis/dump.rdb
sudo systemctl start redis
```

## 📞 Getting Help

### Log Collection
```bash
# Collect logs for support
sudo journalctl -u centrifugo --since "1 hour ago" > centrifugo.log
sudo journalctl -u redis --since "1 hour ago" > redis.log
systemctl status centrifugo > service-status.txt
```

### System Information
```bash
# Collect system info
uname -a > system-info.txt
free -h >> system-info.txt
df -h >> system-info.txt
ps aux | grep centrifugo >> system-info.txt
```

### Configuration Backup
```bash
# Backup current configuration
tar -czf centrifugo-config-backup.tar.gz /etc/centrifugo/
```

## 🔗 Useful Resources

- [Centrifugo Documentation](https://centrifugal.dev/)
- [Centrifugo GitHub Issues](https://github.com/centrifugal/centrifugo/issues)
- [Redis Documentation](https://redis.io/documentation)
- [Systemd Documentation](https://systemd.io/)
