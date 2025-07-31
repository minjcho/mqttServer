#!/usr/bin/env python3
"""
직접 Kafka 프로듀서 테스트
"""

import json
from kafka import KafkaProducer
import time

def test_producer():
    print("🚀 Direct Kafka Producer Test Starting...")
    
    try:
        producer = KafkaProducer(
            bootstrap_servers=['localhost:9092'],
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda v: v.encode('utf-8') if v else None
        )
        
        test_message = {
            "topic": "test/direct",
            "payload": "direct kafka test",
            "timestamp": int(time.time() * 1000),
            "qos": 0
        }
        
        future = producer.send(
            'mqtt-messages',
            key='test/direct', 
            value=test_message
        )
        
        record_metadata = future.get(timeout=10)
        print(f"✅ Sent to Kafka - Topic: {record_metadata.topic}, Partition: {record_metadata.partition}, Offset: {record_metadata.offset}")
        
        producer.close()
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_producer()
