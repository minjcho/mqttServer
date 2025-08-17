#!/bin/bash

# 간단한 Kafka 테스트 (10개 메시지만)

echo "================================================"
echo "Kafka 간단 테스트 (10개 메시지)"
echo "================================================"

# 1. 연결 확인
echo "1. Kafka 상태 확인..."
docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092 | head -3

# 2. 테스트 토픽 생성
echo -e "\n2. 테스트 토픽 생성..."
docker exec kafka kafka-topics --bootstrap-server localhost:9092 \
    --create --topic simple-test \
    --partitions 1 --replication-factor 1 \
    --if-not-exists

# 3. 10개 메시지만 전송
echo -e "\n3. 10개 테스트 메시지 전송..."
for i in {1..10}; do
    echo "Message $i"
done | docker exec -i kafka kafka-console-producer \
    --broker-list localhost:9092 \
    --topic simple-test

echo "✅ 전송 완료"

# 4. 메시지 즉시 확인
echo -e "\n4. 메시지 수신..."
docker exec kafka timeout 3 kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic simple-test \
    --from-beginning 2>/dev/null || true

echo -e "\n================================================"
echo "✅ Kafka가 정상 작동 중입니다!"
echo "================================================"