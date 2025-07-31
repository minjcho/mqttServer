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
    
    # Kafka Consumer 설정
    try:
        consumer = KafkaConsumer(
            *topics,
            bootstrap_servers=[kafka_servers],
            group_id='simple-consumer-' + str(int(time.time())),
            auto_offset_reset='earliest',
            enable_auto_commit=True,
            value_deserializer=lambda x: x.decode('utf-8') if x else None
        )
        logger.info(f"✅ Kafka consumer connected to {kafka_servers}")
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
            # Poll for messages
            message_batch = consumer.poll(timeout_ms=1000)
            
            if message_batch:
                logger.info(f"📬 Received message batch with {len(message_batch)} topic-partitions")
                
                for topic_partition, messages in message_batch.items():
                    logger.info(f"📍 Processing {len(messages)} messages from {topic_partition}")
                    
                    for message in messages:
                        if message and message.value:
                            message_count += 1
                            
                            logger.info(f"🔔 Message #{message_count}:")
                            logger.info(f"   Topic: {message.topic}")
                            logger.info(f"   Partition: {message.partition}")
                            logger.info(f"   Offset: {message.offset}")
                            logger.info(f"   Value: {message.value[:200]}...")
                            
                            # Redis에 저장
                            try:
                                key = f"message:{message.topic}:{message.offset}"
                                data = {
                                    "topic": message.topic,
                                    "message": message.value,
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
                # 주기적 상태 로그
                if message_count == 0:
                    logger.info("🔍 Polling for messages... (no messages yet)")
                    
    except KeyboardInterrupt:
        logger.info("👋 Consumer stopped by user")
    except Exception as e:
        logger.error(f"❌ Consumer error: {e}")
    finally:
        consumer.close()
        logger.info(f"✅ Consumer closed. Processed {message_count} messages total.")

if __name__ == "__main__":
    main()
