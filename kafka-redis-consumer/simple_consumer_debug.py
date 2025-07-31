#!/usr/bin/env python3
"""
극도로 단순화된 Kafka Consumer - 디버깅용
"""

import json
import os
import time
import logging
from datetime import datetime
from kafka import KafkaConsumer
import redis

# 로깅 설정
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def main():
    logger.info("=== 디버깅용 단순 Consumer 시작 ===")
    
    # 환경변수
    kafka_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'kafka:9092')
    redis_host = os.getenv('REDIS_HOST', 'redis')
    redis_port = int(os.getenv('REDIS_PORT', '6379'))
    
    logger.info(f"Kafka servers: {kafka_servers}")
    logger.info(f"Redis: {redis_host}:{redis_port}")
    
    # Redis 연결 테스트
    try:
        redis_client = redis.Redis(host=redis_host, port=redis_port, db=0, decode_responses=True)
        redis_client.ping()
        logger.info("✅ Redis OK")
    except Exception as e:
        logger.error(f"❌ Redis 실패: {e}")
        return
    
    # Kafka Consumer 설정 - 최대한 단순하게
    try:
        consumer = KafkaConsumer(
            'mqtt-messages',
            bootstrap_servers=[kafka_servers],
            group_id='debug-consumer-' + str(int(time.time())),
            auto_offset_reset='latest',
            enable_auto_commit=True,
            value_deserializer=lambda x: x.decode('utf-8') if x else None,
            consumer_timeout_ms=2000
        )
        logger.info("✅ Kafka Consumer OK")
    except Exception as e:
        logger.error(f"❌ Kafka Consumer 실패: {e}")
        return
    
    logger.info("=== 메시지 대기 시작 ===")
    message_count = 0
    poll_count = 0
    
    try:
        while True:
            poll_count += 1
            logger.info(f"Poll #{poll_count} - 메시지 확인 중...")
            
            # 단순 poll
            messages = consumer.poll(timeout_ms=1000)
            
            if messages:
                logger.info(f"🎉 메시지 수신! {len(messages)} topic-partitions")
                
                for topic_partition, msgs in messages.items():
                    logger.info(f"📍 {topic_partition}: {len(msgs)} 메시지")
                    
                    for msg in msgs:
                        message_count += 1
                        logger.info(f"📨 메시지 #{message_count}: {msg.value}")
                        
                        # Redis에 간단히 저장
                        try:
                            key = f"debug:msg:{message_count}"
                            redis_client.set(key, msg.value)
                            redis_client.incr("debug:count")
                            logger.info(f"✅ Redis 저장: {key}")
                        except Exception as e:
                            logger.error(f"❌ Redis 저장 실패: {e}")
            else:
                logger.info("🔍 메시지 없음 - 계속 대기...")
            
            time.sleep(0.5)  # 0.5초 대기
            
    except KeyboardInterrupt:
        logger.info("👋 중단됨")
    except Exception as e:
        logger.error(f"❌ 오류: {e}")
    finally:
        consumer.close()
        logger.info(f"✅ 종료 - 총 {message_count}개 메시지 처리")

if __name__ == "__main__":
    main()