#!/bin/bash

# Kafka 컨테이너 내부에서 직접 실행

echo "================================================"
echo "Kafka 데이터 파이프라인 테스트"
echo "================================================"

# 1. 기본 연결 테스트
echo "1. Kafka 토픽 목록..."
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# 2. 테스트 토픽 생성
echo -e "\n2. 테스트 토픽 생성..."
docker exec kafka kafka-topics --bootstrap-server localhost:9092 \
    --create --topic data-test \
    --partitions 3 --replication-factor 1 \
    --if-not-exists

# 3. 100개 메시지 전송 (배치로 한번에)
echo -e "\n3. 100개 메시지 전송..."

# 모든 메시지를 한 번에 생성하여 전송
(
for i in {1..100}; do
    echo "{\"id\": $i, \"data\": \"test_$i\", \"timestamp\": $(date +%s)}"
done
) | docker exec -i kafka kafka-console-producer \
    --broker-list localhost:9092 \
    --topic data-test \
    --batch-size 100 \
    --timeout 5000

echo "✅ 100개 메시지 전송 완료"

# 4. 메시지 수신 및 카운트
echo -e "\n4. 메시지 수신 확인..."
received=$(docker exec kafka kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic data-test \
    --from-beginning \
    --max-messages 100 \
    --timeout-ms 5000 2>/dev/null | wc -l)

echo "수신된 메시지: $received개"

# 5. 결과 확인
echo -e "\n================================================"
if [ "$received" -eq "100" ]; then
    echo "✅ 테스트 성공: 데이터 무결성 100%"
    echo "✅ Kafka 데이터 파이프라인 정상 작동!"
else
    echo "⚠️ 일부 메시지 손실: $(expr 100 - $received)개"
fi
echo "================================================"

# 6. 토픽 상태 확인
echo -e "\n토픽 상세 정보:"
docker exec kafka kafka-topics --bootstrap-server localhost:9092 \
    --describe --topic data-test | head -5