#!/usr/bin/env python3
"""
Debug Consumer - 단순한 테스트용 Kafka Consumer
"""

import json
import time
from kafka import KafkaConsumer

def main():
    print("🔍 Debug Consumer Starting...")
    
    # 단순한 consumer 설정
    try:
        consumer = KafkaConsumer(
            'mqtt-messages',
            bootstrap_servers=['kafka:9092'],
            group_id='debug-consumer-' + str(int(time.time())),
            auto_offset_reset='earliest',
            enable_auto_commit=True,
            value_deserializer=lambda x: x.decode('utf-8') if x else None
        )
        print("✅ Consumer connected")
    except Exception as e:
        print(f"❌ Failed to connect: {e}")
        return
    
    print("🔍 Starting to poll for messages...")
    message_count = 0
    
    try:
        while True:
            # Poll for messages
            message_batch = consumer.poll(timeout_ms=2000)
            
            if message_batch:
                print(f"📬 Got {len(message_batch)} topic partitions with messages")
                
                for topic_partition, messages in message_batch.items():
                    print(f"  📍 Processing {len(messages)} messages from {topic_partition}")
                    
                    for message in messages:
                        message_count += 1
                        print(f"  🔔 Message #{message_count}:")
                        print(f"     Topic: {message.topic}")
                        print(f"     Partition: {message.partition}")
                        print(f"     Offset: {message.offset}")
                        print(f"     Key: {message.key}")
                        print(f"     Value: {message.value}")
                        print(f"     Timestamp: {message.timestamp}")
                        print("    " + "-"*50)
            else:
                print("🔍 No messages in this poll cycle")
                
    except KeyboardInterrupt:
        print("👋 Stopping consumer...")
    except Exception as e:
        print(f"❌ Consumer error: {e}")
    finally:
        consumer.close()
        print(f"✅ Consumer closed. Processed {message_count} messages total.")

if __name__ == "__main__":
    main()
