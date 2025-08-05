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
    --partitions 3 \
    --replication-factor 1 \
    --if-not-exists

# # 센서 데이터 토픽들 생성
# echo "Creating sensor data topics..."
# kafka-topics --bootstrap-server kafka:9092 \
#     --create \
#     --topic coordX \
#     --partitions 3 \
#     --replication-factor 1 \
#     --if-not-exists

# kafka-topics --bootstrap-server kafka:9092 \
#     --create \
#     --topic coordY \
#     --partitions 3 \
#     --replication-factor 1 \
#     --if-not-exists

# kafka-topics --bootstrap-server kafka:9092 \
#     --create \
#     --topic motorRPM \
#     --partitions 3 \
#     --replication-factor 1 \
#     --if-not-exists

# # 처리된 데이터 토픽들 생성
# echo "Creating processed data topics..."
# kafka-topics --bootstrap-server kafka:9092 \
#     --create \
#     --topic processed-sensor-data \
#     --partitions 3 \
#     --replication-factor 1 \
#     --if-not-exists

# kafka-topics --bootstrap-server kafka:9092 \
#     --create \
#     --topic alerts \
#     --partitions 3 \
#     --replication-factor 1 \
#     --if-not-exists

# # 테스트 토픽 생성
# echo "Creating test topics..."
# kafka-topics --bootstrap-server kafka:9092 \
#     --create \
#     --topic test-messages \
#     --partitions 1 \
#     --replication-factor 1 \
#     --if-not-exists

# 생성된 토픽 목록 확인
echo "Created topics:"
kafka-topics --bootstrap-server kafka:9092 --list

echo "Topic initialization completed successfully!"
