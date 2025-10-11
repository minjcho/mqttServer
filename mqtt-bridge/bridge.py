#!/usr/bin/env python3
import json
import time
import logging
from typing import Dict, Any
import paho.mqtt.client as mqtt
from kafka import KafkaProducer
from config import Config

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class MQTTKafkaBridge:
    def __init__(self):
        # Validate configuration
        Config.validate()

        # MQTT 설정 (환경변수에서 로드)
        self.mqtt_host = Config.MQTT_HOST
        self.mqtt_port = Config.MQTT_PORT
        self.mqtt_topics = Config.MQTT_TOPICS

        # Kafka 설정 (환경변수에서 로드)
        self.kafka_brokers = Config.KAFKA_BROKERS
        self.kafka_topic = Config.KAFKA_TOPIC

        # 클라이언트 초기화
        self.mqtt_client = None
        self.kafka_producer = None
        
    def setup_kafka(self):
        """Kafka 프로듀서 설정"""
        try:
            self.kafka_producer = KafkaProducer(
                bootstrap_servers=self.kafka_brokers,
                value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                key_serializer=lambda v: v.encode('utf-8') if v else None,
                acks=Config.KAFKA_ACKS,
                retries=Config.KAFKA_RETRIES,
                retry_backoff_ms=Config.KAFKA_RETRY_BACKOFF_MS
            )
            logger.info("Kafka producer connected successfully")
            return True
        except Exception as e:
            logger.error(f"Failed to connect to Kafka: {e}")
            return False
    
    def setup_mqtt(self):
        """MQTT 클라이언트 설정"""
        try:
            self.mqtt_client = mqtt.Client()
            self.mqtt_client.on_connect = self.on_mqtt_connect
            self.mqtt_client.on_message = self.on_mqtt_message
            self.mqtt_client.on_disconnect = self.on_mqtt_disconnect
            
            self.mqtt_client.connect(self.mqtt_host, self.mqtt_port, 60)
            logger.info("MQTT client connected successfully")
            return True
        except Exception as e:
            logger.error(f"Failed to connect to MQTT: {e}")
            return False
    
    def on_mqtt_connect(self, client, userdata, flags, rc):
        """MQTT 연결 콜백"""
        if rc == 0:
            logger.info("Connected to MQTT broker")
            # 토픽 구독
            for topic in self.mqtt_topics:
                client.subscribe(topic)
                logger.info(f"Subscribed to {topic}")
        else:
            logger.error(f"Failed to connect to MQTT broker: {rc}")
    
    def on_mqtt_disconnect(self, client, userdata, rc):
        """MQTT 연결 해제 콜백"""
        logger.warning(f"Disconnected from MQTT broker: {rc}")
    
    def on_mqtt_message(self, client, userdata, msg):
        """MQTT 메시지 수신 콜백"""
        try:
            topic = msg.topic
            payload = msg.payload.decode('utf-8')
            timestamp = int(time.time() * 1000)
            
            # 토픽에서 디바이스 ID 추출 (예: sensors/device123/coordinates -> device123)
            topic_parts = topic.split('/')
            device_id = topic_parts[1] if len(topic_parts) > 1 else topic
            
            # Kafka로 전송할 메시지 구성
            kafka_message = {
                "topic": topic,
                "payload": payload,
                "timestamp": timestamp,
                "qos": msg.qos
            }
            
            logger.info(f"🚀 Sending to Kafka topic '{self.kafka_topic}' with key '{device_id}': {kafka_message}")
            
            # Kafka로 전송 (device_id를 파티션 키로 사용)
            future = self.kafka_producer.send(
                self.kafka_topic,
                key=device_id,
                value=kafka_message
            )
            
            # 전송 결과 확인
            try:
                record_metadata = future.get(timeout=10)
                logger.info(f"✅ Successfully sent to Kafka - Topic: {record_metadata.topic}, Partition: {record_metadata.partition}, Offset: {record_metadata.offset}")
                logger.info(f"📨 Original MQTT Topic: {topic}, Payload: {payload}")
            except Exception as e:
                logger.error(f"❌ Failed to send to Kafka: {e}")
            
        except Exception as e:
            logger.error(f"Error processing MQTT message: {e}")
    
    def start(self):
        """브릿지 시작"""
        logger.info("Starting MQTT-Kafka Bridge...")
        
        # Kafka 연결
        if not self.setup_kafka():
            logger.error("Failed to setup Kafka. Exiting.")
            return
        
        # MQTT 연결
        if not self.setup_mqtt():
            logger.error("Failed to setup MQTT. Exiting.")
            return
        
        try:
            # MQTT 루프 시작
            self.mqtt_client.loop_forever()
        except KeyboardInterrupt:
            logger.info("Shutting down bridge...")
        finally:
            self.cleanup()
    
    def cleanup(self):
        """리소스 정리"""
        if self.mqtt_client:
            self.mqtt_client.disconnect()
        if self.kafka_producer:
            self.kafka_producer.close()
        logger.info("Bridge shutdown complete")

if __name__ == "__main__":
    bridge = MQTTKafkaBridge()
    bridge.start() 