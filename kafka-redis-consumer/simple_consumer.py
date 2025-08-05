#!/usr/bin/env python3
"""
Simple Test Consumer for debugging
"""

import json
import time
from kafka import KafkaConsumer
import redis

print("🚀 Starting Simple Consumer...")

# Redis 연결 테스트
try:
    redis_client = redis.Redis(host='redis', port=6379, db=0, decode_responses=True)
    redis_client.ping()
    print("✅ Redis connected successfully")
except Exception as e:
    print(f"❌ Redis connection failed: {e}")
    exit(1)

# Kafka Consumer 생성
try:
    consumer = KafkaConsumer(
        'test-messages',
        bootstrap_servers=['kafka:9092'],
        auto_offset_reset='earliest',
        group_id='simple-test-consumer-' + str(int(time.time())),
        value_deserializer=lambda x: x.decode('utf-8') if x else None
    )
    print("✅ Kafka consumer created successfully")
except Exception as e:
    print(f"❌ Kafka consumer creation failed: {e}")
    exit(1)

print("🔄 Starting message consumption loop...")
message_count = 0

try:
    for message in consumer:
        if message.value:
            message_count += 1
            print(f"🔔 Message #{message_count}: {message.value}")
            
            # Redis에 저장
            key = f"simple_test:{message_count}"
            redis_client.set(key, message.value)
            print(f"💾 Stored in Redis with key: {key}")
            
        # 10개 메시지 처리 후 중단
        if message_count >= 5:
            print("✅ Processed 5 messages, stopping...")
            break
            
except Exception as e:
    print(f"❌ Error in message loop: {e}")
finally:
    consumer.close()
    print("🏁 Consumer closed")
