#!/bin/bash

# Kafka 실시간 성능 모니터링 대시보드
# 처리량, 지연시간, 파티션 상태를 실시간으로 표시

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# 모니터링 간격 (초)
INTERVAL=${1:-2}

# 통계 변수
TOTAL_MESSAGES=0
LAST_COUNT=0
START_TIME=$(date +%s)

# 실시간 모니터링 함수
monitor_kafka() {
    while true; do
        clear
        
        # 헤더
        echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${CYAN}║           Kafka 실시간 성능 모니터링 대시보드               ║${NC}"
        echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo -e "📅 $(date '+%Y-%m-%d %H:%M:%S') | 갱신 주기: ${INTERVAL}초"
        echo ""
        
        # 1. Kafka 브로커 상태
        echo -e "${BOLD}${GREEN}[브로커 상태]${NC}"
        BROKER_STATUS=$(docker exec kafka kafka-broker-api-versions.sh --bootstrap-server localhost:9092 2>&1 | head -1)
        if [[ $BROKER_STATUS == *"ApiVersion"* ]]; then
            echo -e "  ✅ Kafka 브로커: ${GREEN}정상${NC}"
        else
            echo -e "  ❌ Kafka 브로커: ${RED}오류${NC}"
        fi
        
        # 2. 토픽 목록 및 파티션 수
        echo -e "\n${BOLD}${GREEN}[토픽 통계]${NC}"
        TOPICS=$(docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list 2>/dev/null)
        TOPIC_COUNT=$(echo "$TOPICS" | wc -l)
        echo -e "  📊 총 토픽 수: ${BOLD}${TOPIC_COUNT}${NC}"
        
        # 상위 5개 토픽 표시
        echo -e "  ${CYAN}주요 토픽:${NC}"
        echo "$TOPICS" | head -5 | while read topic; do
            if [ -n "$topic" ]; then
                PARTITIONS=$(docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 \
                    --describe --topic $topic 2>/dev/null | grep -c "Partition:")
                echo -e "    • $topic (파티션: $PARTITIONS)"
            fi
        done
        
        # 3. 실시간 처리량 (초당 메시지)
        echo -e "\n${BOLD}${GREEN}[실시간 처리량]${NC}"
        
        # JMX 메트릭 대신 로그 기반 추정
        if [ -f /tmp/kafka_msg_count ]; then
            LAST_COUNT=$(cat /tmp/kafka_msg_count)
        fi
        
        # 현재 메시지 수 추정 (모든 토픽의 오프셋 합)
        CURRENT_COUNT=0
        for topic in $(echo "$TOPICS" | head -5); do
            if [ -n "$topic" ]; then
                OFFSET=$(docker exec kafka kafka-run-class.sh kafka.tools.GetOffsetShell \
                    --broker-list localhost:9092 --topic $topic --time -1 2>/dev/null | \
                    awk -F: '{sum += $3} END {print sum}')
                CURRENT_COUNT=$((CURRENT_COUNT + ${OFFSET:-0}))
            fi
        done
        
        echo $CURRENT_COUNT > /tmp/kafka_msg_count
        
        MSG_RATE=$(( (CURRENT_COUNT - LAST_COUNT) / INTERVAL ))
        echo -e "  📈 메시지 처리율: ${BOLD}${YELLOW}${MSG_RATE} msg/sec${NC}"
        
        # 처리량 그래프 (간단한 바 차트)
        BAR_LENGTH=$(( MSG_RATE / 100 ))
        [ $BAR_LENGTH -gt 50 ] && BAR_LENGTH=50
        [ $BAR_LENGTH -lt 0 ] && BAR_LENGTH=0
        
        echo -n "  "
        for i in $(seq 1 $BAR_LENGTH); do echo -n "█"; done
        echo ""
        
        # 4. Consumer Group 상태
        echo -e "\n${BOLD}${GREEN}[Consumer Groups]${NC}"
        CONSUMER_GROUPS=$(docker exec kafka kafka-consumer-groups.sh \
            --bootstrap-server localhost:9092 --list 2>/dev/null)
        
        if [ -z "$CONSUMER_GROUPS" ]; then
            echo -e "  ${YELLOW}활성 Consumer Group 없음${NC}"
        else
            echo "$CONSUMER_GROUPS" | head -3 | while read group; do
                if [ -n "$group" ]; then
                    LAG=$(docker exec kafka kafka-consumer-groups.sh \
                        --bootstrap-server localhost:9092 --describe --group $group 2>/dev/null | \
                        grep -E "LAG" | awk '{sum += $5} END {print sum}')
                    
                    if [ -n "$LAG" ] && [ "$LAG" -gt 0 ]; then
                        if [ "$LAG" -gt 1000 ]; then
                            echo -e "  • $group - LAG: ${RED}${LAG}${NC} ⚠️"
                        else
                            echo -e "  • $group - LAG: ${YELLOW}${LAG}${NC}"
                        fi
                    else
                        echo -e "  • $group - LAG: ${GREEN}0${NC} ✅"
                    fi
                fi
            done
        fi
        
        # 5. 시스템 리소스
        echo -e "\n${BOLD}${GREEN}[시스템 리소스]${NC}"
        DOCKER_STATS=$(docker stats kafka --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}" | tail -1)
        CPU=$(echo $DOCKER_STATS | awk '{print $1}')
        MEM=$(echo $DOCKER_STATS | awk '{print $2}')
        
        echo -e "  🖥️  CPU: ${BOLD}$CPU${NC}"
        echo -e "  💾 메모리: ${BOLD}$MEM${NC}"
        
        # 6. 최근 오류 (있는 경우)
        echo -e "\n${BOLD}${GREEN}[최근 로그]${NC}"
        ERRORS=$(docker logs kafka --since 10s 2>&1 | grep -E "ERROR|WARN" | tail -3)
        if [ -n "$ERRORS" ]; then
            echo -e "  ${RED}⚠️ 경고/오류 감지:${NC}"
            echo "$ERRORS" | while read line; do
                echo "    $line" | cut -c1-60
            done
        else
            echo -e "  ${GREEN}✅ 최근 오류 없음${NC}"
        fi
        
        # 7. 통계 요약
        UPTIME=$(($(date +%s) - START_TIME))
        UPTIME_MIN=$((UPTIME / 60))
        
        echo -e "\n${BOLD}${CYAN}────────────────────────────────────────────────────────────${NC}"
        echo -e "⏱️  모니터링 시간: ${UPTIME_MIN}분 | 🔄 Ctrl+C로 종료"
        
        sleep $INTERVAL
    done
}

# 트랩 설정 (종료 시 정리)
trap 'echo -e "\n${GREEN}모니터링 종료${NC}"; rm -f /tmp/kafka_msg_count; exit 0' INT TERM

# 모니터링 시작
echo -e "${GREEN}Kafka 실시간 모니터링 시작...${NC}"
sleep 1
monitor_kafka