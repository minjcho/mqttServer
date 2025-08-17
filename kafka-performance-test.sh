#!/bin/bash

# Kafka 성능 벤치마크 테스트
# 처리량, 지연시간, 안정성 측정

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 설정
TOPIC_PREFIX="perf-test"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULT_FILE="kafka-performance-${TIMESTAMP}.txt"

echo "================================================"
echo "Kafka 성능 벤치마크 테스트"
echo "시작 시간: $(date)"
echo "================================================"

# 결과 파일 초기화
echo "Kafka Performance Test Results - ${TIMESTAMP}" > $RESULT_FILE
echo "================================================" >> $RESULT_FILE

# 1. 기본 처리량 테스트 (Throughput Test)
echo -e "\n${BLUE}[1/5] 처리량 테스트 (100만 메시지)${NC}"
echo -e "\n[처리량 테스트]" >> $RESULT_FILE

TOPIC="${TOPIC_PREFIX}-throughput"
docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 \
    --create --topic $TOPIC \
    --partitions 6 --replication-factor 1 \
    --config compression.type=lz4 \
    --config segment.ms=60000 \
    --if-not-exists

echo "테스트 실행 중..."
START_TIME=$(date +%s)

# Producer 성능 테스트
docker exec kafka kafka-producer-perf-test.sh \
    --topic $TOPIC \
    --num-records 1000000 \
    --record-size 1024 \
    --throughput -1 \
    --producer-props bootstrap.servers=localhost:9092 \
        acks=1 \
        compression.type=lz4 \
        batch.size=16384 \
        linger.ms=10 | tee -a $RESULT_FILE

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "처리 시간: ${DURATION}초" | tee -a $RESULT_FILE

# 2. 지연시간 테스트 (Latency Test)
echo -e "\n${BLUE}[2/5] 지연시간 테스트 (10만 메시지)${NC}"
echo -e "\n[지연시간 테스트]" >> $RESULT_FILE

TOPIC="${TOPIC_PREFIX}-latency"
docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 \
    --create --topic $TOPIC \
    --partitions 3 --replication-factor 1 \
    --if-not-exists

echo "낮은 지연시간 설정으로 테스트..."
docker exec kafka kafka-producer-perf-test.sh \
    --topic $TOPIC \
    --num-records 100000 \
    --record-size 512 \
    --throughput 10000 \
    --producer-props bootstrap.servers=localhost:9092 \
        acks=1 \
        compression.type=none \
        batch.size=1 \
        linger.ms=0 | tee -a $RESULT_FILE

# 3. Consumer 성능 테스트
echo -e "\n${BLUE}[3/5] Consumer 처리량 테스트${NC}"
echo -e "\n[Consumer 테스트]" >> $RESULT_FILE

echo "Consumer 테스트 실행 중..."
docker exec kafka kafka-consumer-perf-test.sh \
    --bootstrap-server localhost:9092 \
    --topic $TOPIC \
    --messages 100000 \
    --threads 1 \
    --consumer.config /dev/null | tee -a $RESULT_FILE

# 4. 동시성 테스트 (Multiple Producers)
echo -e "\n${BLUE}[4/5] 동시 Producer 테스트 (10개 병렬)${NC}"
echo -e "\n[동시성 테스트]" >> $RESULT_FILE

TOPIC="${TOPIC_PREFIX}-concurrent"
docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 \
    --create --topic $TOPIC \
    --partitions 10 --replication-factor 1 \
    --if-not-exists

echo "10개 Producer 동시 실행..."
for i in {1..10}; do
    docker exec -d kafka kafka-producer-perf-test.sh \
        --topic $TOPIC \
        --num-records 100000 \
        --record-size 1024 \
        --throughput -1 \
        --producer-props bootstrap.servers=localhost:9092 \
            acks=1 \
            client.id=producer-$i &
done

# 모든 백그라운드 작업 대기
wait
echo "동시 Producer 완료" | tee -a $RESULT_FILE

# 5. End-to-End 지연시간 테스트
echo -e "\n${BLUE}[5/5] End-to-End 지연시간 측정${NC}"
echo -e "\n[End-to-End 지연시간]" >> $RESULT_FILE

TOPIC="${TOPIC_PREFIX}-e2e"
docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 \
    --create --topic $TOPIC \
    --partitions 1 --replication-factor 1 \
    --if-not-exists

# 간단한 E2E 테스트
echo "실시간 메시지 왕복 시간 측정..."
for i in {1..10}; do
    START_NS=$(date +%s%N)
    
    # 메시지 전송
    echo "test-message-$i" | docker exec -i kafka \
        kafka-console-producer.sh --broker-list localhost:9092 --topic $TOPIC
    
    # 메시지 수신
    docker exec kafka timeout 1 \
        kafka-console-consumer.sh --bootstrap-server localhost:9092 \
        --topic $TOPIC --from-beginning --max-messages 1 > /dev/null 2>&1
    
    END_NS=$(date +%s%N)
    LATENCY=$(( (END_NS - START_NS) / 1000000 ))
    echo "  메시지 $i: ${LATENCY}ms" | tee -a $RESULT_FILE
done

# 시스템 리소스 상태
echo -e "\n${BLUE}[시스템 상태]${NC}"
echo -e "\n[시스템 리소스]" >> $RESULT_FILE

docker stats kafka --no-stream | tee -a $RESULT_FILE

# 토픽 통계
echo -e "\n${BLUE}[토픽 상태]${NC}"
echo -e "\n[토픽 통계]" >> $RESULT_FILE

for topic in $(docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list | grep $TOPIC_PREFIX); do
    echo "토픽: $topic" | tee -a $RESULT_FILE
    docker exec kafka kafka-log-dirs.sh --bootstrap-server localhost:9092 \
        --topic-list $topic --describe 2>/dev/null | grep -E "topic|size" | head -5 | tee -a $RESULT_FILE
done

# 결과 요약
echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}성능 테스트 완료${NC}"
echo -e "${GREEN}================================================${NC}"
echo "결과 파일: $RESULT_FILE"

# 테스트 토픽 정리 옵션
echo ""
read -p "테스트 토픽을 삭제하시겠습니까? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    for topic in $(docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list | grep $TOPIC_PREFIX); do
        docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic $topic
    done
    echo "테스트 토픽 삭제 완료"
fi