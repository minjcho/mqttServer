#!/bin/bash

# Kafka 성능 테스트 요약 리포트
# 빠른 성능 측정 (2분 소요)

set -e

# 색상
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}================================================${NC}"
echo -e "${BOLD}${BLUE}       Kafka 빠른 성능 측정 (2분)              ${NC}"
echo -e "${BOLD}${BLUE}================================================${NC}"

# 결과 저장
RESULT_FILE="kafka-perf-summary-$(date +%Y%m%d-%H%M%S).txt"

# 1. 처리량 테스트 (10만 메시지)
echo -e "\n${GREEN}1. 처리량 테스트${NC}"
TOPIC="quick-throughput-test"

docker exec kafka kafka-topics --bootstrap-server localhost:9092 \
    --create --topic $TOPIC \
    --partitions 6 --replication-factor 1 \
    --if-not-exists 2>/dev/null || true

echo "   10만 메시지 전송 중..."
THROUGHPUT_RESULT=$(docker exec kafka kafka-producer-perf-test \
    --topic $TOPIC \
    --num-records 100000 \
    --record-size 1024 \
    --throughput -1 \
    --producer-props bootstrap.servers=localhost:9092 \
        acks=1 \
        compression.type=lz4 2>&1 | tail -1)

echo "$THROUGHPUT_RESULT" | tee -a $RESULT_FILE

# 결과 파싱
THROUGHPUT=$(echo "$THROUGHPUT_RESULT" | grep -oE '[0-9]+\.[0-9]+ records/sec' | head -1)
AVG_LATENCY=$(echo "$THROUGHPUT_RESULT" | grep -oE '[0-9]+\.[0-9]+ ms avg latency' | head -1)
P99_LATENCY=$(echo "$THROUGHPUT_RESULT" | grep -oE '[0-9]+ ms 99th' | head -1)

# 2. Consumer 테스트
echo -e "\n${GREEN}2. Consumer 처리량 테스트${NC}"
echo "   10만 메시지 소비 중..."

CONSUMER_RESULT=$(docker exec kafka timeout 10 kafka-consumer-perf-test \
    --bootstrap-server localhost:9092 \
    --topic $TOPIC \
    --messages 100000 \
    --consumer.config /dev/null 2>&1 | tail -1)

echo "$CONSUMER_RESULT" | tee -a $RESULT_FILE

# 3. End-to-End 지연시간 (5회 측정)
echo -e "\n${GREEN}3. End-to-End 지연시간${NC}"
TOPIC_E2E="quick-e2e-test"

docker exec kafka kafka-topics --bootstrap-server localhost:9092 \
    --create --topic $TOPIC_E2E \
    --partitions 1 --replication-factor 1 \
    --if-not-exists 2>/dev/null || true

TOTAL_LATENCY=0
for i in {1..5}; do
    START_NS=$(date +%s%N)
    
    echo "test-$i" | docker exec -i kafka kafka-console-producer \
        --broker-list localhost:9092 --topic $TOPIC_E2E
    
    docker exec kafka timeout 1 kafka-console-consumer \
        --bootstrap-server localhost:9092 \
        --topic $TOPIC_E2E --from-beginning --max-messages 1 >/dev/null 2>&1
    
    END_NS=$(date +%s%N)
    LATENCY=$(( (END_NS - START_NS) / 1000000 ))
    echo "   테스트 $i: ${LATENCY}ms"
    TOTAL_LATENCY=$((TOTAL_LATENCY + LATENCY))
done

AVG_E2E=$((TOTAL_LATENCY / 5))
echo "   평균 E2E: ${AVG_E2E}ms" | tee -a $RESULT_FILE

# 4. 시스템 리소스
echo -e "\n${GREEN}4. 시스템 리소스${NC}"
docker stats kafka --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | tee -a $RESULT_FILE

# 결과 요약
echo -e "\n${BOLD}${BLUE}================================================${NC}"
echo -e "${BOLD}${BLUE}                성능 측정 결과                  ${NC}"
echo -e "${BOLD}${BLUE}================================================${NC}"

echo -e "\n📊 ${BOLD}핵심 지표:${NC}"
echo -e "  • 처리량: ${YELLOW}${THROUGHPUT}${NC}"
echo -e "  • 평균 지연: ${YELLOW}${AVG_LATENCY}${NC}"
echo -e "  • P99 지연: ${YELLOW}${P99_LATENCY}${NC}"
echo -e "  • E2E 지연: ${YELLOW}${AVG_E2E}ms${NC}"

# 성능 평가
echo -e "\n📈 ${BOLD}성능 평가:${NC}"

# 처리량 평가
THROUGHPUT_NUM=$(echo "$THROUGHPUT" | grep -oE '[0-9]+' | head -1)
if [ "$THROUGHPUT_NUM" -gt 50000 ]; then
    echo -e "  • 처리량: ${GREEN}우수 (>50K msg/sec)${NC}"
elif [ "$THROUGHPUT_NUM" -gt 20000 ]; then
    echo -e "  • 처리량: ${YELLOW}양호 (>20K msg/sec)${NC}"
else
    echo -e "  • 처리량: ${RED}개선 필요 (<20K msg/sec)${NC}"
fi

# E2E 지연 평가
if [ "$AVG_E2E" -lt 100 ]; then
    echo -e "  • 지연시간: ${GREEN}우수 (<100ms)${NC}"
elif [ "$AVG_E2E" -lt 500 ]; then
    echo -e "  • 지연시간: ${YELLOW}양호 (<500ms)${NC}"
else
    echo -e "  • 지연시간: ${RED}개선 필요 (>500ms)${NC}"
fi

echo -e "\n📁 상세 결과: ${BOLD}$RESULT_FILE${NC}"

# 테스트 토픽 정리
docker exec kafka kafka-topics --bootstrap-server localhost:9092 \
    --delete --topic $TOPIC 2>/dev/null || true
docker exec kafka kafka-topics --bootstrap-server localhost:9092 \
    --delete --topic $TOPIC_E2E 2>/dev/null || true

echo -e "\n${GREEN}✅ 성능 측정 완료!${NC}"