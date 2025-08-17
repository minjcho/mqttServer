#!/bin/bash

# Docker 컨테이너 내부에서 직접 Kafka 테스트

echo "================================================"
echo "Docker 내부 Kafka 테스트"
echo "================================================"

# 1. 토픽 목록 확인
echo "1. 토픽 목록 확인..."
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# 2. 테스트 토픽 생성
echo -e "\n2. 테스트 토픽 생성..."
docker exec kafka kafka-topics --bootstrap-server localhost:9092 \
    --create --topic docker-test \
    --partitions 1 --replication-factor 1 \
    --if-not-exists

# 3. 메시지 전송
echo -e "\n3. 테스트 메시지 전송..."
echo "Test message $(date)" | docker exec -i kafka \
    kafka-console-producer --broker-list localhost:9092 --topic docker-test

# 4. 메시지 수신
echo -e "\n4. 메시지 수신 (3초 대기)..."
timeout 3 docker exec kafka \
    kafka-console-consumer --bootstrap-server localhost:9092 \
    --topic docker-test --from-beginning --max-messages 1

# 5. Python 테스트를 컨테이너 내부에서 실행
echo -e "\n5. Python 테스트 (컨테이너 내부)..."
docker exec kafka bash -c "
pip install kafka-python 2>/dev/null || true
python3 -c '
from kafka import KafkaProducer
import json

try:
    producer = KafkaProducer(
        bootstrap_servers=\"localhost:9092\",
        value_serializer=lambda v: json.dumps(v).encode()
    )
    future = producer.send(\"python-test\", {\"test\": \"from container\"})
    result = future.get(timeout=5)
    print(f\"✅ Python 테스트 성공: partition={result.partition}, offset={result.offset}\")
    producer.close()
except Exception as e:
    print(f\"❌ Python 테스트 실패: {e}\")
'
"

echo -e "\n================================================"
echo "테스트 완료"
echo "================================================"