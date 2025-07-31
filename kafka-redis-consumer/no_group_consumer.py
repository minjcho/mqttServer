#!/usr/bin/env python3
"""
Consumer Group 없이 단순한 Kafka Consumer
"""

import json
import os
import time
import logging
from datetime import datetime
from kafka import KafkaConsumer, TopicPartition
import redis

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def main():
    logger.info("=== Consumer Group 없는 단순 Consumer ===")
    
    kafka_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'kafka:9092')
    redis_host = os.getenv('REDIS_HOST', 'redis')
    redis_port = int(os.getenv('REDIS_PORT', '6379'))
    
    # Redis 연결
    try:
        redis_client = redis.Redis(host=redis_host, port=redis_port, db=0, decode_responses=True)
        redis_client.ping()
        logger.info("✅ Redis 연결 성공")
    except Exception as e:
        logger.error(f"❌ Redis 실패: {e}")
        return
    
    # Consumer Group 없이 KafkaConsumer 생성
    try:
        consumer = KafkaConsumer(
            bootstrap_servers=[kafka_servers],
            value_deserializer=lambda x: x.decode('utf-8') if x else None,
            consumer_timeout_ms=2000,
            # Consumer Group 설정 제거
            enable_auto_commit=False,
            auto_offset_reset='latest'
        )
        
        # 수동으로 topic partition 할당
        topic_partition = TopicPartition('mqtt-messages', 0)  # partition 0만 우선 테스트
        consumer.assign([topic_partition])
        
        # 가장 최근 offset으로 이동
        consumer.seek_to_end(topic_partition)
        
        logger.info("✅ Kafka Consumer 설정 완료 (Consumer Group 없음)")
        
    except Exception as e:
        logger.error(f"❌ Kafka Consumer 실패: {e}")
        return
    
    logger.info("=== 메시지 대기 시작 (최신 메시지부터) ===")
    message_count = 0
    poll_count = 0
    
    try:
        while True:
            poll_count += 1
            logger.info(f"Poll #{poll_count} - 메시지 확인 중...")
            
            messages = consumer.poll(timeout_ms=1000)
            
            if messages:
                logger.info(f"🎉 메시지 수신! {len(messages)} topic-partitions")
                
                for topic_partition, msgs in messages.items():
                    logger.info(f"📍 {topic_partition}: {len(msgs)} 메시지")
                    
                    for msg in msgs:
                        message_count += 1
                        logger.info(f"📨 메시지 #{message_count}: {msg.value}")
                        
                        # Redis에 저장
                        try:
                            key = f"nogroup:msg:{message_count}"
                            data = {
                                "topic": msg.topic,
                                "partition": msg.partition,
                                "offset": msg.offset,
                                "message": msg.value,
                                "timestamp": datetime.now().isoformat()
                            }
                            redis_client.hset(key, mapping=data)
                            redis_client.incr("nogroup:count")
                            logger.info(f"✅ Redis 저장: {key}")
                        except Exception as e:
                            logger.error(f"❌ Redis 저장 실패: {e}")
            else:
                logger.info("🔍 메시지 없음 - 계속 대기...")
            
            time.sleep(0.5)
            
    except KeyboardInterrupt:
        logger.info("👋 중단됨")
    except Exception as e:
        logger.error(f"❌ 오류: {e}")
    finally:
        consumer.close()
        logger.info(f"✅ 종료 - 총 {message_count}개 메시지 처리")

if __name__ == "__main__":
    main()