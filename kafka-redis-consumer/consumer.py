#!/usr/bin/env python3
"""
Kafka to Redis Consumer - 단순화된 버전
"""

import json
import os
import time
import logging
import re
from datetime import datetime
from kafka import KafkaConsumer
import redis

# 단순한 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def extract_orin_id(mqtt_topic):
    """MQTT 토픽에서 ORIN ID 추출 (예: sensors/ORIN001/coordinates -> ORIN001)"""
    if not mqtt_topic:
        return None
    
    # sensors/ORIN001/coordinates 패턴에서 ORIN ID 추출
    match = re.search(r'sensors/([^/]+)/', mqtt_topic)
    if match:
        return match.group(1)
    return None

def main():
    logger.info("🚀 Starting Simplified Kafka-Redis Consumer")
    
    # 환경변수에서 설정 읽기
    kafka_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'kafka:9092')
    redis_host = os.getenv('REDIS_HOST', 'redis')
    redis_port = int(os.getenv('REDIS_PORT', '6379'))
    
    topics = ['mqtt-messages']
    
    # Kafka Consumer 설정 - Consumer Group 적용
    try:
        consumer = KafkaConsumer(
            'mqtt-messages',  # 토픽 직접 지정
            bootstrap_servers=[kafka_servers],
            group_id='coordinate-consumer-group',  # Consumer Group 적용
            auto_offset_reset='latest',  # 최신 메시지부터 (실시간 우선)
            enable_auto_commit=True,  # 자동 오프셋 커밋
            auto_commit_interval_ms=5000,  # 5초마다 커밋
            fetch_min_bytes=1,  # 즉시 가져오기
            fetch_max_wait_ms=500,  # 최대 0.5초 대기
            max_poll_records=500,  # 배치 500개
            value_deserializer=None,  # Raw bytes를 받아서 수동으로 처리
            consumer_timeout_ms=1000  # 1초 타임아웃
        )

        logger.info(f"✅ Kafka consumer connected to {kafka_servers} (group: coordinate-consumer-group)")
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
                                    
                                    # MQTT 토픽에서 ORIN ID 추출 (Telegraf 포맷)
                                    mqtt_topic = message_data.get('tags', {}).get('mqtt_topic', '')
                                    orin_id = extract_orin_id(mqtt_topic)
                                    logger.info(f"   MQTT Topic: {mqtt_topic}, ORIN ID: {orin_id}")
                                    
                                except:
                                    logger.info(f"   Not JSON, treating as plain text")
                                    message_data = {"raw_message": message_str}
                                    orin_id = None
                                
                            except Exception as e:
                                logger.error(f"❌ Failed to decode message: {e}")
                                message_str = str(message.value)
                                message_data = {"raw_bytes": message_str}
                            
                            # Redis에 저장
                            try:
                                # 기본 메시지 저장
                                key = f"message:{message.topic}:{message.partition}:{message.offset}"
                                data = {
                                    "topic": message.topic,
                                    "message": message_str,
                                    "timestamp": datetime.now().isoformat(),
                                    "offset": message.offset,
                                    "partition": message.partition
                                }
                                redis_client.hset(key, mapping=data)
                                
                                # ORIN ID별 최신 데이터 저장
                                if orin_id and isinstance(message_data, dict) and 'fields' in message_data:
                                    orin_key = f"orin:{orin_id}:latest"
                                    
                                    # fields.value에서 실제 좌표 데이터 추출
                                    try:
                                        value_json = message_data.get('fields', {}).get('value', '{}')
                                        coord_data = json.loads(value_json)
                                        
                                        orin_data = {
                                            "orin_id": orin_id,
                                            "data": json.dumps(coord_data),  # 좌표 데이터만 저장
                                            "timestamp": datetime.now().isoformat(),
                                            "mqtt_topic": mqtt_topic
                                        }
                                        redis_client.hset(orin_key, mapping=orin_data)
                                        logger.info(f"✅ Saved ORIN data to Redis with key: {orin_key} - X={coord_data.get('coordX')}, Y={coord_data.get('coordY')}")
                                    except Exception as e:
                                        logger.error(f"❌ Failed to parse coordinate data for {orin_id}: {e}")
                                
                                # 카운터 증가
                                redis_client.incr("message_count")
                                if orin_id:
                                    redis_client.incr(f"orin:{orin_id}:count")
                                
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