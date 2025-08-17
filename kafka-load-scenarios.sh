#!/bin/bash

# Kafka 부하 시나리오별 테스트
# 실제 운영 환경을 시뮬레이션하는 다양한 부하 패턴

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# 결과 파일
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULT_DIR="kafka-load-test-${TIMESTAMP}"
mkdir -p $RESULT_DIR

echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}           Kafka 부하 시나리오 테스트 Suite                    ${NC}"
echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""

# 시나리오 선택
echo -e "${YELLOW}테스트 시나리오를 선택하세요:${NC}"
echo "  1) 🚀 점진적 증가 (Ramp-up Test)"
echo "  2) 💥 스파이크 테스트 (Spike Test)"
echo "  3) 🏃 지속 부하 테스트 (Sustained Load)"
echo "  4) 🌊 웨이브 패턴 (Wave Pattern)"
echo "  5) 🎯 실제 워크로드 시뮬레이션"
echo "  6) 🔥 스트레스 테스트 (한계 측정)"
echo "  7) 📊 전체 시나리오 실행"
echo ""
read -p "선택 (1-7): " scenario

# 공통 함수
create_topic() {
    local topic=$1
    local partitions=${2:-6}
    
    docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 \
        --create --topic $topic \
        --partitions $partitions \
        --replication-factor 1 \
        --config retention.ms=3600000 \
        --config segment.ms=60000 \
        --if-not-exists 2>/dev/null || true
}

run_producer() {
    local topic=$1
    local records=$2
    local size=$3
    local throughput=$4
    local name=$5
    
    echo -e "${GREEN}▶ $name 실행 중...${NC}"
    docker exec kafka kafka-producer-perf-test.sh \
        --topic $topic \
        --num-records $records \
        --record-size $size \
        --throughput $throughput \
        --producer-props bootstrap.servers=localhost:9092 \
            acks=1 \
            compression.type=lz4
}

# 시나리오 1: 점진적 증가 (Ramp-up)
scenario_rampup() {
    echo -e "\n${BOLD}${MAGENTA}[시나리오 1] 점진적 부하 증가 테스트${NC}"
    echo "처리량을 단계적으로 증가: 1K → 5K → 10K → 50K → 100K msgs/sec"
    
    TOPIC="scenario-rampup"
    create_topic $TOPIC 10
    
    local levels=(1000 5000 10000 50000 100000)
    local names=("1K msgs/sec" "5K msgs/sec" "10K msgs/sec" "50K msgs/sec" "100K msgs/sec")
    
    for i in ${!levels[@]}; do
        echo -e "\n${YELLOW}단계 $((i+1)): ${names[$i]}${NC}"
        run_producer $TOPIC 100000 1024 ${levels[$i]} "${names[$i]}" | tee $RESULT_DIR/rampup-$i.txt
        echo "10초 대기..."
        sleep 10
    done
    
    echo -e "${GREEN}✅ Ramp-up 테스트 완료${NC}"
}

# 시나리오 2: 스파이크 테스트
scenario_spike() {
    echo -e "\n${BOLD}${MAGENTA}[시나리오 2] 스파이크 부하 테스트${NC}"
    echo "갑작스런 트래픽 증가 시뮬레이션"
    
    TOPIC="scenario-spike"
    create_topic $TOPIC 10
    
    echo -e "${YELLOW}평상시 부하 (10K msgs/sec)${NC}"
    run_producer $TOPIC 50000 1024 10000 "Normal Load" &
    
    sleep 5
    
    echo -e "${RED}🔥 스파이크 발생! (무제한 처리량)${NC}"
    run_producer $TOPIC 500000 1024 -1 "SPIKE" | tee $RESULT_DIR/spike.txt
    
    echo -e "${YELLOW}평상시로 복귀${NC}"
    run_producer $TOPIC 50000 1024 10000 "Recovery" | tee $RESULT_DIR/spike-recovery.txt
    
    echo -e "${GREEN}✅ 스파이크 테스트 완료${NC}"
}

# 시나리오 3: 지속 부하 테스트
scenario_sustained() {
    echo -e "\n${BOLD}${MAGENTA}[시나리오 3] 지속 부하 테스트 (5분)${NC}"
    echo "일정한 부하를 장시간 유지"
    
    TOPIC="scenario-sustained"
    create_topic $TOPIC 10
    
    echo -e "${YELLOW}50K msgs/sec로 5분간 지속${NC}"
    
    # 5분 = 300초, 50K/sec = 15,000,000 메시지
    run_producer $TOPIC 15000000 1024 50000 "Sustained Load" | tee $RESULT_DIR/sustained.txt
    
    # 시스템 상태 확인
    echo -e "\n${BLUE}시스템 상태:${NC}"
    docker stats kafka --no-stream | tee -a $RESULT_DIR/sustained.txt
    
    echo -e "${GREEN}✅ 지속 부하 테스트 완료${NC}"
}

# 시나리오 4: 웨이브 패턴
scenario_wave() {
    echo -e "\n${BOLD}${MAGENTA}[시나리오 4] 웨이브 패턴 테스트${NC}"
    echo "주기적인 부하 변동 시뮬레이션"
    
    TOPIC="scenario-wave"
    create_topic $TOPIC 10
    
    for wave in {1..3}; do
        echo -e "\n${YELLOW}Wave $wave${NC}"
        
        echo "  📈 상승"
        run_producer $TOPIC 100000 1024 20000 "Rising" &
        sleep 10
        
        echo "  📊 피크"
        run_producer $TOPIC 200000 1024 100000 "Peak" &
        sleep 10
        
        echo "  📉 하강"
        run_producer $TOPIC 100000 1024 20000 "Falling" &
        sleep 10
        
        echo "  📊 저점"
        run_producer $TOPIC 50000 1024 5000 "Valley" &
        sleep 10
    done
    
    wait
    echo -e "${GREEN}✅ 웨이브 패턴 테스트 완료${NC}"
}

# 시나리오 5: 실제 워크로드 시뮬레이션
scenario_realistic() {
    echo -e "\n${BOLD}${MAGENTA}[시나리오 5] 실제 워크로드 시뮬레이션${NC}"
    echo "다양한 메시지 크기와 패턴으로 실제 환경 모사"
    
    # 여러 토픽 생성 (다양한 용도)
    create_topic "events-small" 3      # 작은 이벤트
    create_topic "events-medium" 6     # 중간 크기
    create_topic "events-large" 10     # 큰 페이로드
    create_topic "events-batch" 5      # 배치 처리
    
    echo -e "${YELLOW}다양한 워크로드 동시 실행${NC}"
    
    # 작은 이벤트 (100 bytes, 높은 빈도)
    echo "  • 작은 이벤트 스트림"
    docker exec -d kafka kafka-producer-perf-test.sh \
        --topic events-small \
        --num-records 1000000 \
        --record-size 100 \
        --throughput 50000 \
        --producer-props bootstrap.servers=localhost:9092
    
    # 중간 크기 (1KB, 중간 빈도)
    echo "  • 중간 크기 메시지"
    docker exec -d kafka kafka-producer-perf-test.sh \
        --topic events-medium \
        --num-records 500000 \
        --record-size 1024 \
        --throughput 10000 \
        --producer-props bootstrap.servers=localhost:9092
    
    # 큰 페이로드 (10KB, 낮은 빈도)
    echo "  • 큰 페이로드"
    docker exec -d kafka kafka-producer-perf-test.sh \
        --topic events-large \
        --num-records 100000 \
        --record-size 10240 \
        --throughput 1000 \
        --producer-props bootstrap.servers=localhost:9092
    
    # 배치 처리 (버스트)
    echo "  • 배치 버스트"
    docker exec -d kafka kafka-producer-perf-test.sh \
        --topic events-batch \
        --num-records 200000 \
        --record-size 2048 \
        --throughput -1 \
        --producer-props bootstrap.servers=localhost:9092 \
            batch.size=65536 \
            linger.ms=100
    
    echo -e "\n${BLUE}30초 동안 실행...${NC}"
    sleep 30
    
    # 통계 수집
    echo -e "\n${BLUE}토픽별 통계:${NC}"
    for topic in events-small events-medium events-large events-batch; do
        echo -e "${YELLOW}$topic:${NC}"
        docker exec kafka kafka-log-dirs.sh --bootstrap-server localhost:9092 \
            --topic-list $topic --describe 2>/dev/null | grep size | head -1
    done | tee $RESULT_DIR/realistic.txt
    
    echo -e "${GREEN}✅ 실제 워크로드 시뮬레이션 완료${NC}"
}

# 시나리오 6: 스트레스 테스트
scenario_stress() {
    echo -e "\n${BOLD}${MAGENTA}[시나리오 6] 스트레스 테스트 (한계 측정)${NC}"
    echo -e "${RED}⚠️ 주의: 시스템 한계까지 부하를 가합니다${NC}"
    
    read -p "계속하시겠습니까? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    TOPIC="scenario-stress"
    create_topic $TOPIC 20
    
    echo -e "${RED}🔥 최대 부하 테스트 시작${NC}"
    
    # 20개 프로듀서 동시 실행 (무제한 처리량)
    for i in {1..20}; do
        echo "  Producer $i 시작"
        docker exec -d kafka kafka-producer-perf-test.sh \
            --topic $TOPIC \
            --num-records 1000000 \
            --record-size 1024 \
            --throughput -1 \
            --producer-props bootstrap.servers=localhost:9092 \
                client.id=stress-producer-$i \
                acks=0 \
                compression.type=none
    done
    
    echo -e "\n${YELLOW}60초 동안 스트레스 테스트 실행${NC}"
    
    # 실시간 모니터링
    for i in {1..12}; do
        sleep 5
        echo -n "."
        # CPU/메모리 체크
        STATS=$(docker stats kafka --no-stream --format "CPU: {{.CPUPerc}} | MEM: {{.MemUsage}}")
        echo " [$STATS]"
    done
    
    # 결과 수집
    echo -e "\n${BLUE}스트레스 테스트 결과:${NC}"
    docker stats kafka --no-stream | tee $RESULT_DIR/stress.txt
    
    # 프로세스 정리
    docker exec kafka pkill -f kafka-producer-perf-test || true
    
    echo -e "${GREEN}✅ 스트레스 테스트 완료${NC}"
}

# 시나리오 7: 전체 실행
run_all_scenarios() {
    echo -e "${BOLD}${BLUE}전체 시나리오 순차 실행${NC}"
    
    scenario_rampup
    sleep 30
    
    scenario_spike
    sleep 30
    
    scenario_sustained
    sleep 30
    
    scenario_wave
    sleep 30
    
    scenario_realistic
    sleep 30
    
    scenario_stress
}

# 메인 실행
case $scenario in
    1) scenario_rampup ;;
    2) scenario_spike ;;
    3) scenario_sustained ;;
    4) scenario_wave ;;
    5) scenario_realistic ;;
    6) scenario_stress ;;
    7) run_all_scenarios ;;
    *) echo "잘못된 선택입니다."; exit 1 ;;
esac

# 최종 리포트
echo -e "\n${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}                    테스트 완료 리포트                          ${NC}"
echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"

echo -e "\n📁 결과 디렉토리: ${BOLD}$RESULT_DIR${NC}"
echo -e "📊 결과 파일:"
ls -la $RESULT_DIR/

# 시스템 최종 상태
echo -e "\n${BLUE}시스템 최종 상태:${NC}"
docker stats kafka --no-stream

echo -e "\n${GREEN}모든 테스트가 완료되었습니다!${NC}"

# 정리 옵션
echo ""
read -p "테스트 토픽을 모두 삭제하시겠습니까? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    for topic in $(docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list | grep scenario-); do
        docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic $topic 2>/dev/null || true
    done
    echo "테스트 토픽 삭제 완료"
fi