#!/bin/bash

# Kafka 실시간 모니터링 스크립트
# 토픽별 메시지 수, 오프셋, 컨슈머 그룹 상태 모니터링

KAFKA_HOME="${KAFKA_HOME:-/opt/kafka}"
BOOTSTRAP_SERVER="${1:-localhost:9092}"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

clear

echo "================================================"
echo "Kafka 실시간 모니터링"
echo "서버: $BOOTSTRAP_SERVER"
echo "================================================"

# Kafka 도구 경로 확인
if [ -d "$KAFKA_HOME/bin" ]; then
    KAFKA_BIN="$KAFKA_HOME/bin"
elif command -v kafka-topics.sh &> /dev/null; then
    KAFKA_BIN=""
else
    echo "Kafka 도구를 찾을 수 없습니다. KAFKA_HOME을 설정하세요."
    exit 1
fi

# 함수: 토픽 목록 조회
get_topics() {
    if [ -n "$KAFKA_BIN" ]; then
        $KAFKA_BIN/kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVER --list 2>/dev/null
    else
        kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVER --list 2>/dev/null
    fi
}

# 함수: 토픽 상세 정보
get_topic_details() {
    local topic=$1
    if [ -n "$KAFKA_BIN" ]; then
        $KAFKA_BIN/kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVER --describe --topic $topic 2>/dev/null
    else
        kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVER --describe --topic $topic 2>/dev/null
    fi
}

# 함수: 컨슈머 그룹 목록
get_consumer_groups() {
    if [ -n "$KAFKA_BIN" ]; then
        $KAFKA_BIN/kafka-consumer-groups.sh --bootstrap-server $BOOTSTRAP_SERVER --list 2>/dev/null
    else
        kafka-consumer-groups.sh --bootstrap-server $BOOTSTRAP_SERVER --list 2>/dev/null
    fi
}

# 함수: 컨슈머 그룹 상태
get_consumer_group_status() {
    local group=$1
    if [ -n "$KAFKA_BIN" ]; then
        $KAFKA_BIN/kafka-consumer-groups.sh --bootstrap-server $BOOTSTRAP_SERVER --describe --group $group 2>/dev/null
    else
        kafka-consumer-groups.sh --bootstrap-server $BOOTSTRAP_SERVER --describe --group $group 2>/dev/null
    fi
}

# 함수: 토픽 오프셋 확인
get_topic_offsets() {
    local topic=$1
    if [ -n "$KAFKA_BIN" ]; then
        echo "최신 오프셋:"
        $KAFKA_BIN/kafka-run-class.sh kafka.tools.GetOffsetShell \
            --broker-list $BOOTSTRAP_SERVER \
            --topic $topic \
            --time -1 2>/dev/null
        
        echo "최초 오프셋:"
        $KAFKA_BIN/kafka-run-class.sh kafka.tools.GetOffsetShell \
            --broker-list $BOOTSTRAP_SERVER \
            --topic $topic \
            --time -2 2>/dev/null
    else
        echo "GetOffsetShell 도구를 사용할 수 없습니다."
    fi
}

# 메인 모니터링 루프
while true; do
    clear
    echo "=========================================="
    echo -e "${BLUE}Kafka 모니터링 대시보드${NC}"
    echo "시간: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=========================================="
    
    # 1. 토픽 목록
    echo -e "\n${GREEN}[토픽 목록]${NC}"
    topics=$(get_topics)
    if [ -z "$topics" ]; then
        echo -e "${RED}토픽이 없거나 연결할 수 없습니다.${NC}"
    else
        echo "$topics" | while read topic; do
            if [ -n "$topic" ]; then
                echo "  📁 $topic"
                # 파티션 정보 간단히 표시
                get_topic_details $topic | grep -E "Partition:" | head -1
            fi
        done
    fi
    
    # 2. 컨슈머 그룹 상태
    echo -e "\n${GREEN}[컨슈머 그룹]${NC}"
    groups=$(get_consumer_groups)
    if [ -z "$groups" ]; then
        echo "  활성 컨슈머 그룹 없음"
    else
        echo "$groups" | while read group; do
            if [ -n "$group" ]; then
                echo -e "  ${YELLOW}그룹: $group${NC}"
                # LAG 정보 표시
                get_consumer_group_status $group | grep -E "TOPIC|LAG" | head -5
            fi
        done
    fi
    
    # 3. 시스템 리소스 (간단)
    echo -e "\n${GREEN}[시스템 상태]${NC}"
    echo "  CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
    echo "  메모리: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
    echo "  디스크: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')"
    
    # 4. Kafka 프로세스
    echo -e "\n${GREEN}[Kafka 프로세스]${NC}"
    kafka_pids=$(pgrep -f kafka.Kafka)
    if [ -n "$kafka_pids" ]; then
        echo -e "  ${GREEN}✓ Kafka 실행 중${NC} (PID: $kafka_pids)"
    else
        echo -e "  ${RED}✗ Kafka 프로세스 없음${NC}"
    fi
    
    zk_pids=$(pgrep -f zookeeper)
    if [ -n "$zk_pids" ]; then
        echo -e "  ${GREEN}✓ Zookeeper 실행 중${NC} (PID: $zk_pids)"
    else
        echo -e "  ${YELLOW}⚠ Zookeeper 프로세스 없음${NC}"
    fi
    
    echo -e "\n=========================================="
    echo "갱신 주기: 5초 | 종료: Ctrl+C"
    
    sleep 5
done