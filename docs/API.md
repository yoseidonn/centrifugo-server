# Centrifugo API Reference

This document describes the HTTP API and WebSocket protocol for the Centrifugo real-time messaging server.

## 🌐 HTTP API

Base URL: `http://localhost:8000/api`

### Authentication

All API requests require the `Authorization` header:
```
Authorization: apikey your-api-key
```

### Endpoints

#### Publish Message
**POST** `/api/publish`

Publish a message to a channel.

**Request:**
```json
{
  "channel": "messages:1:2",
  "data": {
    "user_id": 123,
    "message": "Hello world!",
    "timestamp": "2024-01-01T12:00:00Z"
  }
}
```

**Response:**
```json
{
  "result": {
    "offset": 12345,
    "epoch": "xyz"
  }
}
```

#### Broadcast Message
**POST** `/api/broadcast`

Broadcast a message to multiple channels.

**Request:**
```json
{
  "channels": ["messages:1:2", "messages:1:3"],
  "data": {
    "type": "notification",
    "message": "Server maintenance in 5 minutes"
  }
}
```

#### Get Presence
**POST** `/api/presence`

Get presence information for a channel.

**Request:**
```json
{
  "channel": "presence:1"
}
```

**Response:**
```json
{
  "result": {
    "presence": {
      "123": {
        "client": "client-id-1",
        "user": "123",
        "conn_info": {},
        "chan_info": {}
      }
    }
  }
}
```

#### Get History
**POST** `/api/history`

Get message history for a channel.

**Request:**
```json
{
  "channel": "messages:1:2",
  "limit": 50
}
```

**Response:**
```json
{
  "result": {
    "publications": [
      {
        "data": {
          "user_id": 123,
          "message": "Hello world!"
        },
        "offset": 12345,
        "epoch": "xyz"
      }
    ],
    "offset": 12345,
    "epoch": "xyz"
  }
}
```

#### Get Channels
**POST** `/api/channels`

Get list of active channels.

**Response:**
```json
{
  "result": {
    "channels": {
      "messages:1:2": {
        "num_clients": 5
      },
      "notifications:123": {
        "num_clients": 1
      }
    }
  }
}
```

## 🔌 WebSocket Protocol

### Connection

**URL:** `ws://localhost:8000/connection/websocket`

**Headers:**
```
Authorization: Bearer <jwt-token>
```

### Message Format

All WebSocket messages use JSON format:

```json
{
  "id": 1,
  "method": "connect",
  "params": {
    "token": "jwt-token-here"
  }
}
```

### Client → Server Messages

#### Connect
```json
{
  "id": 1,
  "method": "connect",
  "params": {
    "token": "jwt-token-here"
  }
}
```

#### Subscribe
```json
{
  "id": 2,
  "method": "subscribe",
  "params": {
    "channel": "messages:1:2",
    "token": "subscription-token" // optional for private channels
  }
}
```

#### Unsubscribe
```json
{
  "id": 3,
  "method": "unsubscribe",
  "params": {
    "channel": "messages:1:2"
  }
}
```

#### Publish
```json
{
  "id": 4,
  "method": "publish",
  "params": {
    "channel": "messages:1:2",
    "data": {
      "message": "Hello from client!"
    }
  }
}
```

### Server → Client Messages

#### Connect Response
```json
{
  "id": 1,
  "result": {
    "client": "client-id-123",
    "version": "5.0.0",
    "expires": false,
    "ttl": 0
  }
}
```

#### Subscribe Response
```json
{
  "id": 2,
  "result": {
    "channel": "messages:1:2",
    "status": "subscribed"
  }
}
```

#### Publication (Message)
```json
{
  "channel": "messages:1:2",
  "data": {
    "user_id": 123,
    "message": "Hello world!",
    "timestamp": "2024-01-01T12:00:00Z"
  },
  "offset": 12345,
  "epoch": "xyz"
}
```

#### Join Event
```json
{
  "channel": "messages:1:2",
  "data": {
    "user": "456",
    "client": "client-id-456",
    "conn_info": {},
    "chan_info": {}
  }
}
```

#### Leave Event
```json
{
  "channel": "messages:1:2",
  "data": {
    "user": "456",
    "client": "client-id-456",
    "conn_info": {},
    "chan_info": {}
  }
}
```

#### Error Response
```json
{
  "id": 1,
  "error": {
    "code": 1001,
    "message": "Invalid token"
  }
}
```

## 🔐 JWT Token Structure

### Connection Token
```json
{
  "sub": "user123",
  "exp": 1640995200,
  "iat": 1640908800
}
```

### Subscription Token
```json
{
  "sub": "user123",
  "channel": "messages:1:2",
  "exp": 1640995200,
  "iat": 1640908800
}
```

## 📡 Channel Namespaces

### Messages (`messages:`)
- **Format**: `messages:{server_id}:{channel_id}`
- **Features**: Presence, join/leave events, history
- **Example**: `messages:1:2` (Server 1, Channel 2)

### Notifications (`notifications:`)
- **Format**: `notifications:{user_id}`
- **Features**: History only, no presence
- **Example**: `notifications:123` (User 123's notifications)

### Presence (`presence:`)
- **Format**: `presence:{server_id}`
- **Features**: Presence only, no history
- **Example**: `presence:1` (Server 1 presence)

### Direct Messages (`dm:`)
- **Format**: `dm:{user_id_1}:{user_id_2}`
- **Features**: Presence, history
- **Example**: `dm:123:456` (DM between users 123 and 456)

## 🚨 Error Codes

| Code | Description |
|------|-------------|
| 1001 | Invalid token |
| 1002 | Token expired |
| 1003 | Connection expired |
| 1004 | Wrong state |
| 1005 | Too many requests |
| 1006 | Internal error |
| 1007 | Bad request |
| 1008 | Method not found |
| 1009 | Not available |
| 1010 | Unauthorized |
| 1011 | Forbidden |

## 📊 Rate Limits

- **Connections**: 1000 per IP per minute
- **Subscriptions**: 100 per connection
- **Publishes**: 100 per connection per minute
- **API calls**: 1000 per minute

## 🔧 Configuration Options

### Namespace Configuration
```json
{
  "name": "messages",
  "presence": true,
  "join_leave": true,
  "history_size": 100,
  "history_ttl": "300s",
  "recover": true,
  "publish": true,
  "subscribe_to_publish": false
}
```

### Engine Configuration
```json
{
  "type": "redis",
  "redis": {
    "address": "redis://localhost:6379",
    "db": 1,
    "prefix": "centrifugo",
    "pool_size": 256,
    "min_idle_conns": 10
  }
}
```

## 📝 Examples

### JavaScript Client Example
```javascript
const centrifuge = new Centrifuge('ws://localhost:8000/connection/websocket', {
  token: 'your-jwt-token'
});

centrifuge.on('connect', function(ctx) {
  console.log('Connected', ctx);
});

centrifuge.on('disconnect', function(ctx) {
  console.log('Disconnected', ctx);
});

const sub = centrifuge.newSubscription('messages:1:2');

sub.on('publication', function(ctx) {
  console.log('Message received:', ctx.data);
});

sub.subscribe();

centrifuge.connect();
```

### Python Client Example
```python
import asyncio
from centrifuge import Centrifuge

async def main():
    client = Centrifuge('ws://localhost:8000/connection/websocket')
    client.set_token('your-jwt-token')
    
    def on_connect(ctx):
        print('Connected', ctx)
    
    def on_disconnect(ctx):
        print('Disconnected', ctx)
    
    client.on('connect', on_connect)
    client.on('disconnect', on_disconnect)
    
    await client.connect()
    
    def on_message(ctx):
        print('Message received:', ctx.data)
    
    sub = client.new_subscription('messages:1:2')
    sub.on('publication', on_message)
    await sub.subscribe()
    
    await client.run()

asyncio.run(main())
```
