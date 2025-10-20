#!/bin/bash

# Kafka 토픽 초기화 스크립트
echo "Starting Kafka topic initialization..."

# Kafka가 완전히 시작될 때까지 대기
echo "Waiting for Kafka to be ready..."
until kafka-topics --bootstrap-server kafka:9092 --list; do
    echo "Kafka is not ready yet. Waiting..."
    sleep 5
done

echo "Kafka is ready. Creating topics..."

# MQTT 메시지를 받을 토픽 생성
echo "Creating mqtt-messages topic..."
kafka-topics --bootstrap-server kafka:9092 \
    --create \
    --topic mqtt-messages \
    --partitions 12 \
    --replication-factor 1 \
    --config retention.ms=86400000 \
    --config compression.type=snappy \
    --config min.insync.replicas=1 \
    --if-not-exists

# 생성된 토픽 목록 확인
echo "Created topics:"
kafka-topics --bootstrap-server kafka:9092 --list

echo "Topic initialization completed successfully!"
