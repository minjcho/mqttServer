#!/usr/bin/env python3
import json
import time
from kafka import KafkaConsumer
import logging

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def test_simple_consumer():
    """간단한 Kafka 컨슈머 테스트"""
    logger.info("간단한 Kafka 컨슈머 테스트 시작...")
    
    try:
        # 매우 간단한 컨슈머 생성
        consumer = KafkaConsumer(
            'mqtt-messages',
            bootstrap_servers=['kafka:9092'],
            group_id='test-consumer-group',
            auto_offset_reset='earliest',
            value_deserializer=lambda x: json.loads(x.decode('utf-8')),
            consumer_timeout_ms=10000  # 10초 타임아웃
        )
        
        logger.info("Kafka 컨슈머 생성 완료")
        
        message_count = 0
        for message in consumer:
            message_count += 1
            logger.info(f"메시지 #{message_count}: partition={message.partition}, offset={message.offset}")
            logger.info(f"내용: {message.value}")
            
            if message_count >= 5:  # 처음 5개 메시지만 확인
                break
                
        logger.info(f"총 {message_count}개 메시지 처리 완료")
        consumer.close()
        
    except Exception as e:
        logger.error(f"컨슈머 테스트 중 오류: {e}")

if __name__ == "__main__":
    test_simple_consumer()
