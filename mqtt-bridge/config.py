#!/usr/bin/env python3
"""
Configuration management for MQTT-Kafka Bridge
All hardcoded values are replaced with environment variables
"""

import os
from typing import List


class Config:
    """Configuration class for MQTT-Kafka Bridge"""

    # MQTT Configuration
    MQTT_HOST = os.getenv('MQTT_HOST', 'mosquitto')
    MQTT_PORT = int(os.getenv('MQTT_PORT', '3123'))
    MQTT_TOPICS = os.getenv('MQTT_TOPICS', 'sensors/+/coordinates').split(',')

    # Kafka Configuration
    KAFKA_BROKERS = os.getenv('KAFKA_BROKERS', 'kafka:9092').split(',')
    KAFKA_TOPIC = os.getenv('KAFKA_TOPIC', 'mqtt-messages')
    KAFKA_ACKS = os.getenv('KAFKA_ACKS', 'all')
    KAFKA_RETRIES = int(os.getenv('KAFKA_RETRIES', '3'))
    KAFKA_RETRY_BACKOFF_MS = int(os.getenv('KAFKA_RETRY_BACKOFF_MS', '100'))

    @classmethod
    def validate(cls):
        """Validate required configuration"""
        required_configs = {
            'MQTT_HOST': cls.MQTT_HOST,
            'MQTT_PORT': cls.MQTT_PORT,
            'KAFKA_BROKERS': cls.KAFKA_BROKERS,
            'KAFKA_TOPIC': cls.KAFKA_TOPIC
        }

        for key, value in required_configs.items():
            if not value:
                raise ValueError(f"Required configuration {key} is missing")

        return True

    @classmethod
    def get_mqtt_config(cls) -> dict:
        """Get MQTT configuration as dictionary"""
        return {
            'host': cls.MQTT_HOST,
            'port': cls.MQTT_PORT,
            'topics': cls.MQTT_TOPICS
        }

    @classmethod
    def get_kafka_config(cls) -> dict:
        """Get Kafka configuration as dictionary"""
        return {
            'bootstrap_servers': cls.KAFKA_BROKERS,
            'topic': cls.KAFKA_TOPIC,
            'acks': cls.KAFKA_ACKS,
            'retries': cls.KAFKA_RETRIES,
            'retry_backoff_ms': cls.KAFKA_RETRY_BACKOFF_MS
        }
