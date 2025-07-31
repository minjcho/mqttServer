#!/usr/bin/env python3
"""
수동 Kafka Consumer 테스트
"""

import json
from kafka import KafkaConsumer
import time

def test_consumer():
    print("🔍 Manual Kafka Consumer Test Starting...")
    
    try:
        consumer = KafkaConsumer(
            bootstrap_servers=['localhost:9092'],
            group_id=f'manual-test-group-{int(time.time())}',  # 유니크한 그룹 ID
            auto_offset_reset='earliest',
            enable_auto_commit=False,  # 수동 커밋
            value_deserializer=lambda x: x.decode('utf-8') if x else None,
            consumer_timeout_ms=15000,  # 15초 타임아웃
            fetch_min_bytes=1,  # 최소 1바이트
            fetch_max_wait_ms=500  # 최대 500ms 대기
        )
        
        print("✅ Connected to Kafka")
        
        # 파티션 정보 확인
        partitions = consumer.partitions_for_topic('mqtt-messages')
        print(f"📊 Available partitions for mqtt-messages: {partitions}")
        
        # 명시적으로 파티션 할당
        from kafka import TopicPartition
        consumer.assign([TopicPartition('mqtt-messages', p) for p in partitions])
        
        # 시작 오프셋으로 이동
        consumer.seek_to_beginning()
        
        print("🔍 Polling for messages...")
        
        message_count = 0
        for message in consumer:
            print(f"📨 Message {message_count}: Partition={message.partition}, Offset={message.offset}")
            print(f"    Key: {message.key}")
            print(f"    Value: {message.value}")
            message_count += 1
            if message_count >= 10:  # 최대 10개 메시지만
                break
                
        print(f"✅ Received {message_count} messages")
        consumer.close()
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_consumer()
