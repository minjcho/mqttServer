#!/bin/bash

# Docker 환경에서 Kafka 테스트 스크립트

echo "================================================"
echo "Docker Kafka 연결 테스트"
echo "================================================"

# 1. Docker 컨테이너 상태 확인
echo "1. Kafka 컨테이너 상태 확인..."
docker ps | grep kafka

echo ""
echo "2. Kafka 네트워크 테스트..."

# Docker 네트워크 내부에서 테스트
docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list

echo ""
echo "3. 테스트 토픽 생성..."
docker exec kafka kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --create \
    --topic test-topic \
    --partitions 1 \
    --replication-factor 1 \
    --if-not-exists

echo ""
echo "4. 메시지 전송 테스트..."
echo "test message $(date)" | docker exec -i kafka kafka-console-producer.sh \
    --broker-list localhost:9092 \
    --topic test-topic

echo ""
echo "5. 메시지 수신 테스트..."
docker exec kafka kafka-console-consumer.sh \
    --bootstrap-server localhost:9092 \
    --topic test-topic \
    --from-beginning \
    --max-messages 1

echo ""
echo "================================================"
echo "테스트 완료!"
echo "================================================"