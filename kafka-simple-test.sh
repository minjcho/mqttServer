#!/bin/bash

# Kafka 간단 연동 테스트 스크립트
# MQTT -> Kafka -> 저장소 파이프라인 검증

set -e

# 설정
KAFKA_SERVER="${1:-localhost:9092}"
TEST_TOPIC="mqtt_sensor_data"
TEST_COUNT=100

# 색상
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================"
echo "Kafka 데이터 파이프라인 간단 테스트"
echo "================================================"
echo "Kafka 서버: $KAFKA_SERVER"
echo "테스트 토픽: $TEST_TOPIC"
echo ""

# 1. Kafka 연결 테스트
echo -e "${YELLOW}[1/5] Kafka 연결 확인...${NC}"
timeout 5 bash -c "echo 'test' | kafka-console-producer.sh --broker-list $KAFKA_SERVER --topic connection_test" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Kafka 연결 성공${NC}"
else
    echo -e "${RED}❌ Kafka 연결 실패${NC}"
    exit 1
fi

# 2. 토픽 생성
echo -e "\n${YELLOW}[2/5] 테스트 토픽 생성...${NC}"
kafka-topics.sh --create \
    --bootstrap-server $KAFKA_SERVER \
    --topic $TEST_TOPIC \
    --partitions 3 \
    --replication-factor 1 \
    --if-not-exists 2>/dev/null || true

echo -e "${GREEN}✅ 토픽 준비 완료${NC}"

# 3. 샘플 데이터 전송
echo -e "\n${YELLOW}[3/5] 샘플 센서 데이터 전송 중...${NC}"

for i in $(seq 1 $TEST_COUNT); do
    timestamp=$(date +%s%3N)
    
    # JSON 형식의 센서 데이터
    message=$(cat <<EOF
{
  "sensor_id": "sensor_$(($i % 10))",
  "timestamp": $timestamp,
  "temperature": $(echo "20 + $RANDOM % 10" | bc),
  "humidity": $(echo "40 + $RANDOM % 30" | bc),
  "location": "room_$(($i % 5))",
  "status": "active"
}
EOF
)
    
    echo "$message" | kafka-console-producer.sh \
        --broker-list $KAFKA_SERVER \
        --topic $TEST_TOPIC 2>/dev/null
    
    if [ $(($i % 20)) -eq 0 ]; then
        echo "  전송: $i/$TEST_COUNT"
    fi
done

echo -e "${GREEN}✅ $TEST_COUNT개 메시지 전송 완료${NC}"

# 4. 데이터 수신 확인
echo -e "\n${YELLOW}[4/5] 데이터 수신 확인 (5초간)...${NC}"

received_count=$(timeout 5 kafka-console-consumer.sh \
    --bootstrap-server $KAFKA_SERVER \
    --topic $TEST_TOPIC \
    --from-beginning \
    --max-messages $TEST_COUNT 2>/dev/null | wc -l)

echo -e "  수신된 메시지: $received_count개"

if [ $received_count -gt 0 ]; then
    echo -e "${GREEN}✅ 데이터 수신 확인${NC}"
else
    echo -e "${RED}❌ 데이터 수신 실패${NC}"
fi

# 5. 토픽 상태 확인
echo -e "\n${YELLOW}[5/5] 토픽 상태 확인...${NC}"

kafka-topics.sh --describe \
    --bootstrap-server $KAFKA_SERVER \
    --topic $TEST_TOPIC 2>/dev/null | head -5

# 오프셋 확인
echo -e "\n${YELLOW}오프셋 정보:${NC}"
kafka-run-class.sh kafka.tools.GetOffsetShell \
    --broker-list $KAFKA_SERVER \
    --topic $TEST_TOPIC \
    --time -1 2>/dev/null || echo "오프셋 정보 조회 실패"

# 결과 요약
echo ""
echo "================================================"
echo "테스트 결과 요약"
echo "================================================"

if [ $received_count -gt 0 ]; then
    success_rate=$(echo "scale=2; $received_count * 100 / $TEST_COUNT" | bc)
    
    echo -e "${GREEN}✅ Kafka 연결: 정상${NC}"
    echo -e "${GREEN}✅ 데이터 전송: ${TEST_COUNT}개${NC}"
    echo -e "${GREEN}✅ 데이터 수신: ${received_count}개${NC}"
    echo -e "${GREEN}✅ 성공률: ${success_rate}%${NC}"
    
    if [ $(echo "$success_rate >= 90" | bc) -eq 1 ]; then
        echo -e "\n${GREEN}🎉 Kafka 데이터 파이프라인 정상 작동!${NC}"
    else
        echo -e "\n${YELLOW}⚠️ 일부 메시지 손실 감지${NC}"
    fi
else
    echo -e "${RED}❌ 테스트 실패: 데이터가 Kafka에 저장되지 않음${NC}"
fi

echo "================================================"

# 정리 옵션
echo ""
read -p "테스트 토픽을 삭제하시겠습니까? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kafka-topics.sh --delete \
        --bootstrap-server $KAFKA_SERVER \
        --topic $TEST_TOPIC 2>/dev/null
    echo "테스트 토픽 삭제 완료"
fi