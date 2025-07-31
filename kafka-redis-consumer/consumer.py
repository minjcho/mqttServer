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
        
        self.consumer = None
        self.redis_client = None
        
    def connect_kafka(self):
        """Kafka 연결"""
        try:
            self.consumer = KafkaConsumer(
                *self.topics,
                bootstrap_servers=[self.kafka_servers],
                auto_offset_reset='earliest',  # 처음부터 메시지 읽기
                enable_auto_commit=True,
                group_id='redis-consumer-new-' + str(int(time.time())),  # 유니크한 그룹 ID
                value_deserializer=lambda x: x.decode('utf-8') if x else None
            )
            logger.info("Kafka consumer connected", extra={
                "bootstrap_servers": self.kafka_servers,
                "topics": self.topics
            })
            return True
        except Exception as e:
            logger.error("Failed to connect to Kafka", extra={
                "error": str(e),
                "bootstrap_servers": self.kafka_servers
            })
            return False
    
    def connect_redis(self):
        """Redis 연결"""
        try:
            self.redis_client = redis.Redis(
                host=self.redis_host,
                port=self.redis_port,
                db=self.redis_db,
                decode_responses=True,
                socket_connect_timeout=5,
                socket_timeout=5
            )
            # 연결 테스트
            self.redis_client.ping()
            logger.info("Redis client connected", extra={
                "host": self.redis_host,
                "port": self.redis_port,
                "db": self.redis_db
            })
            return True
        except Exception as e:
            logger.error("Failed to connect to Redis", extra={
                "error": str(e),
                "host": self.redis_host,
                "port": self.redis_port
            })
            return False
    
    def store_message_in_redis(self, topic, message, timestamp):
        """Redis에 메시지 저장"""
        try:
            # 메시지 데이터 구조
            data = {
                "topic": topic,
                "message": message,
                "timestamp": timestamp,
                "processed_at": datetime.now().isoformat()
            }
            
            # 1. 최신 메시지를 topic별로 저장 (Hash)
            redis_key = f"latest:{topic}"
            self.redis_client.hset(redis_key, mapping=data)
            
            # 2. 시계열 데이터로 저장 (List, 최근 1000개만 유지)
            timeseries_key = f"timeseries:{topic}"
            self.redis_client.lpush(timeseries_key, json.dumps(data))
            self.redis_client.ltrim(timeseries_key, 0, 999)  # 최근 1000개만 유지
            
            # 3. 센서 데이터의 경우 별도 처리
            if topic in ['coordX', 'coordY', 'motorRPM']:
                try:
                    # 숫자 값인 경우 통계 정보 업데이트
                    value = float(message)
                    stats_key = f"stats:{topic}"
                    
                    # 현재 통계 가져오기
                    current_stats = self.redis_client.hgetall(stats_key)
                    
                    if current_stats:
                        count = int(current_stats.get('count', 0)) + 1
                        total = float(current_stats.get('total', 0)) + value
                        min_val = min(float(current_stats.get('min', value)), value)
                        max_val = max(float(current_stats.get('max', value)), value)
                    else:
                        count = 1
                        total = value
                        min_val = max_val = value
                    
                    # 통계 업데이트
                    stats = {
                        'count': count,
                        'total': total,
                        'average': total / count,
                        'min': min_val,
                        'max': max_val,
                        'last_updated': datetime.now().isoformat()
                    }
                    
                    self.redis_client.hset(stats_key, mapping=stats)
                    
                except ValueError:
                    # 숫자가 아닌 경우 통계 처리 생략
                    pass
            
            # 4. 알람의 경우 별도 저장 (Set으로 중복 제거)
            if topic == 'alerts':
                alerts_key = "active_alerts"
                self.redis_client.sadd(alerts_key, json.dumps(data))
                # 알람은 24시간 후 자동 만료
                self.redis_client.expire(alerts_key, 86400)
            
            logger.debug("Message stored in Redis", extra={
                "topic": topic,
                "redis_key": redis_key,
                "message_length": len(message)
            })
            
        except Exception as e:
            logger.error("Failed to store message in Redis", extra={
                "topic": topic,
                "error": str(e),
                "message": message[:100] if len(message) > 100 else message
            })
    
    def run(self):
        """메인 실행 루프"""
        logger.info("Starting Kafka-Redis Consumer")
        
        # 연결 재시도 로직
        max_retries = 5
        retry_delay = 5
        
        for attempt in range(max_retries):
            if self.connect_kafka() and self.connect_redis():
                break
            
            if attempt < max_retries - 1:
                logger.warning(f"Connection failed, retrying in {retry_delay}s... (attempt {attempt + 1}/{max_retries})")
                time.sleep(retry_delay)
                retry_delay *= 2  # 지수적 백오프
            else:
                logger.error("Failed to establish connections after all retries")
                return
        
        logger.info("Consumer started successfully, waiting for messages...")
        
        try:
            message_count = 0
            logger.info("Starting message polling loop...")
            
            # 더 명시적인 처리 방식
            while True:
                try:
                    # Poll로 메시지 확인 (더 긴 timeout)
                    message_batch = self.consumer.poll(timeout_ms=5000)
                    
                    if message_batch:
                        logger.info("📬 Received message batch", extra={"batch_size": len(message_batch)})
                        
                        for topic_partition, messages in message_batch.items():
                            logger.info(f"Processing {len(messages)} messages from {topic_partition}")
                            for message in messages:
                                if message and message.value:
                                    timestamp = datetime.fromtimestamp(message.timestamp / 1000).isoformat()
                                    
                                    logger.info("🔔 MESSAGE RECEIVED!", extra={
                                        "topic": message.topic,
                                        "partition": message.partition,
                                        "offset": message.offset,
                                        "message": message.value[:200],  # 처음 200자
                                        "timestamp": timestamp
                                    })
                                    
                                    # Redis에 저장 시도
                                    self.store_message_in_redis(
                                        topic=message.topic,
                                        message=message.value,
                                        timestamp=timestamp
                                    )
                                    
                                    message_count += 1
                                    
                                    logger.info("✅ Message stored successfully", extra={
                                        "count": message_count,
                                        "topic": message.topic
                                    })
                    else:
                        # 주기적으로 상태 로그 출력 (더 자주)
                        logger.info("🔍 Polling for messages...", extra={"current_count": message_count})
                            
                except Exception as e:
                    logger.error("Error in message loop", extra={"error": str(e)})
                    time.sleep(1)
                
        except KeyboardInterrupt:
            logger.info("Consumer stopped by user")
        except Exception as e:
            logger.error("Consumer error", extra={"error": str(e)})
        finally:
            if self.consumer:
                self.consumer.close()
            if self.redis_client:
                self.redis_client.close()
            logger.info("Consumer closed")

def main():
    consumer = KafkaRedisConsumer()
    consumer.run()

if __name__ == "__main__":
    main()
