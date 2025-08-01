#!/usr/bin/env python3
import redis
import json

# Redis에 연결
r = redis.Redis(host='localhost', port=6379, decode_responses=True)

print("Redis connection test:")
print(f"PING: {r.ping()}")

print("\nAll keys in Redis:")
keys = r.keys("*")
print(f"Total keys: {len(keys)}")

if keys:
    print("\nFirst 10 keys:")
    for key in keys[:10]:
        print(f"- {key}")
        
    print("\nSample data:")
    for key in keys[:3]:
        key_type = r.type(key)
        print(f"\nKey: {key} (type: {key_type})")
        
        if key_type == 'hash':
            data = r.hgetall(key)
            print(f"Hash data: {data}")
        elif key_type == 'string':
            data = r.get(key)
            print(f"String data: {data}")
        elif key_type == 'list':
            data = r.lrange(key, 0, -1)
            print(f"List data: {data}")
else:
    print("No keys found in Redis")

print("\nChecking for robot1 coordinate keys...")
robot_keys = r.keys("robot1:*")
print(f"Robot1 keys: {robot_keys}")

if robot_keys:
    for key in robot_keys:
        print(f"\n{key}: {r.hgetall(key)}")
