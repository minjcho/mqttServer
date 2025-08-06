#!/usr/bin/env python3
"""
Kafka to Redis Consumer - 단순화된 버전
"""

import json
import os
import time
import logging
from datetime import datetime
from kafka import KafkaConsumer
import redis

# 단순한 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def main():
    logger.info("🚀 Starting Simplified Kafka-Redis Consumer")
    
    # 환경변수에서 설정 읽기
    kafka_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'kafka:9092')
    redis_host = os.getenv('REDIS_HOST', 'redis')
    redis_port = int(os.getenv('REDIS_PORT', '6379'))
    
    topics = ['mqtt-messages']
    
    # Kafka Consumer 설정 - Consumer Group 없이
    try:
        from kafka import TopicPartition
        
        consumer = KafkaConsumer(
            bootstrap_servers=[kafka_servers],
            auto_offset_reset='earliest',
            enable_auto_commit=False,  # Consumer Group 없이 수동 관리
            value_deserializer=None,  # Raw bytes를 받아서 수동으로 처리
            consumer_timeout_ms=1000  # 1초 타임아웃
        )
        
        # 수동으로 모든 파티션에 할당
        topic_partitions = [
            TopicPartition('mqtt-messages', 0),
            TopicPartition('mqtt-messages', 1),
            TopicPartition('mqtt-messages', 2)
        ]
        consumer.assign(topic_partitions)
        
        # 처음부터 읽기 (테스트용)
        for tp in topic_partitions:
            consumer.seek_to_beginning(tp)
        
        logger.info(f"✅ Kafka consumer connected to {kafka_servers} (Consumer Group 없음)")
    except Exception as e:
        logger.error(f"❌ Failed to connect to Kafka: {e}")
        return
    
    # Redis 연결
    try:
        redis_client = redis.Redis(
            host=redis_host,
            port=redis_port,
            db=0,
            decode_responses=True
        )
        redis_client.ping()
        logger.info(f"✅ Redis connected to {redis_host}:{redis_port}")
    except Exception as e:
        logger.error(f"❌ Failed to connect to Redis: {e}")
        return
    
    logger.info("🔍 Starting message polling loop...")
    message_count = 0
    
    try:
        while True:
            # Poll for messages - 더 짧은 timeout으로 더 자주 확인
            message_batch = consumer.poll(timeout_ms=500)
            
            if message_batch:
                logger.info(f"📬 Received message batch with {len(message_batch)} topic-partitions")
                
                for topic_partition, messages in message_batch.items():
                    logger.info(f"📍 Processing {len(messages)} messages from {topic_partition}")
                    
                    for message in messages:
                        if message and message.value:
                            message_count += 1
                            
                            # Raw bytes를 문자열로 변환
                            try:
                                message_str = message.value.decode('utf-8')
                                logger.info(f"🔔 Message #{message_count}:")
                                logger.info(f"   Topic: {message.topic}")
                                logger.info(f"   Partition: {message.partition}")
                                logger.info(f"   Offset: {message.offset}")
                                logger.info(f"   Raw Value: {message_str[:500]}...")
                                
                                # JSON 파싱 시도
                                try:
                                    message_data = json.loads(message_str)
                                    logger.info(f"   Parsed JSON: {message_data}")
                                except:
                                    logger.info(f"   Not JSON, treating as plain text")
                                    message_data = {"raw_message": message_str}
                                
                            except Exception as e:
                                logger.error(f"❌ Failed to decode message: {e}")
                                message_str = str(message.value)
                                message_data = {"raw_bytes": message_str}
                            
                            # Redis에 저장
                            try:
                                key = f"message:{message.topic}:{message.partition}:{message.offset}"
                                data = {
                                    "topic": message.topic,
                                    "message": message_str,
                                    "timestamp": datetime.now().isoformat(),
                                    "offset": message.offset,
                                    "partition": message.partition
                                }
                                redis_client.hset(key, mapping=data)
                                
                                # 카운터 증가
                                redis_client.incr("message_count")
                                
                                logger.info(f"✅ Saved to Redis with key: {key}")
                                
                            except Exception as e:
                                logger.error(f"❌ Failed to save to Redis: {e}")
            else:
                # 주기적 상태 로그 - 더 자주 출력
                logger.info(f"🔍 Polling for messages... (processed: {message_count} messages so far)")
                    
    except KeyboardInterrupt:
        logger.info("👋 Consumer stopped by user")
    except Exception as e:
        logger.error(f"❌ Consumer error: {e}")
    finally:
        consumer.close()
        logger.info(f"✅ Consumer closed. Processed {message_count} messages total.")

if __name__ == "__main__":
    main()