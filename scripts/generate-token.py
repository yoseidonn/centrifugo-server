#!/usr/bin/env python3
"""
Generate JWT tokens for Centrifugo connections.
This script helps generate connection and subscription tokens for testing.
"""

import hmac
import hashlib
import json
import sys
import time
from datetime import datetime, timedelta

try:
    import jwt
except ImportError:
    print("Error: PyJWT library not installed. Install with: pip install PyJWT")
    sys.exit(1)

def generate_connection_token(secret: str, user_id: str, exp_hours: int = 24) -> str:
    """Generate JWT token for Centrifugo connection"""
    exp = int(time.time()) + (exp_hours * 3600)
    payload = {
        "sub": str(user_id),
        "exp": exp,
        "iat": int(time.time())
    }
    return jwt.encode(payload, secret, algorithm="HS256")

def generate_subscription_token(secret: str, user_id: str, channel: str, exp_hours: int = 24) -> str:
    """Generate subscription token for private channels"""
    exp = int(time.time()) + (exp_hours * 3600)
    payload = {
        "sub": str(user_id),
        "channel": channel,
        "exp": exp,
        "iat": int(time.time())
    }
    return jwt.encode(payload, secret, algorithm="HS256")

def main():
    if len(sys.argv) < 3:
        print("Usage:")
        print("  python generate-token.py <secret> <user_id> [exp_hours]")
        print("  python generate-token.py <secret> <user_id> <channel> [exp_hours]  # for subscription token")
        print("")
        print("Examples:")
        print("  python generate-token.py 'your-secret-key-here' '123'")
        print("  python generate-token.py 'your-secret-key-here' '123' 'messages:1:2'")
        sys.exit(1)
    
    secret = sys.argv[1]
    user_id = sys.argv[2]
    exp_hours = int(sys.argv[4]) if len(sys.argv) > 4 else 24
    
    if len(sys.argv) >= 4 and sys.argv[3].startswith('messages:') or sys.argv[3].startswith('notifications:'):
        # Generate subscription token
        channel = sys.argv[3]
        token = generate_subscription_token(secret, user_id, channel, exp_hours)
        print(f"Subscription token for user {user_id}, channel {channel}:")
    else:
        # Generate connection token
        token = generate_connection_token(secret, user_id, exp_hours)
        print(f"Connection token for user {user_id}:")
    
    print(token)
    print("")
    
    # Decode and show token info
    try:
        decoded = jwt.decode(token, secret, algorithms=["HS256"])
        print("Token info:")
        print(f"  User ID: {decoded['sub']}")
        print(f"  Expires: {datetime.fromtimestamp(decoded['exp'])}")
        if 'channel' in decoded:
            print(f"  Channel: {decoded['channel']}")
    except Exception as e:
        print(f"Error decoding token: {e}")

if __name__ == "__main__":
    main()
