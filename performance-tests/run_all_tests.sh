#!/bin/bash

echo "=========================================="
echo "MQTT IoT 서버 종합 성능 테스트 스위트"
echo "=========================================="
echo "시작 시간: $(date)"
echo ""

# 테스트 설정
TEST_DIR="/Users/minjcho/development/ssafy/mqttserver/performance-tests"
LOG_DIR="/tmp/performance_test_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="$LOG_DIR/$TIMESTAMP"

# 결과 디렉토리 생성
mkdir -p $RESULTS_DIR
cd "$TEST_DIR" || exit 1

echo "결과 저장 디렉토리: $RESULTS_DIR"
echo ""

# 시스템 정보 수집
echo "=== 시스템 정보 수집 ==="
{
    echo "== 시스템 정보 =="
    uname -a
    echo ""
    echo "== CPU 정보 =="
    sysctl -n machdep.cpu.brand_string 2>/dev/null || cat /proc/cpuinfo | grep "model name" | head -1
    echo "CPU 코어 수: $(sysctl -n hw.ncpu 2>/dev/null || nproc)"
    echo ""
    echo "== 메모리 정보 =="
    echo "총 메모리: $(echo $(sysctl -n hw.memsize 2>/dev/null || grep MemTotal /proc/meminfo | awk '{print $2}') | awk '{print $1/1024/1024/1024 " GB"}')"
    echo ""
    echo "== Docker 정보 =="
    docker --version
    docker-compose --version
    echo ""
    echo "== 테스트 시작 시간 =="
    date
} > $RESULTS_DIR/system_info.txt

echo "✓ 시스템 정보 수집 완료"

# 필수 의존성 확인
echo ""
echo "=== 의존성 확인 ==="

check_dependency() {
    if command -v $1 >/dev/null 2>&1; then
        echo "✓ $1 설치됨"
        return 0
    else
        echo "✗ $1 설치되지 않음"
        return 1
    fi
}

DEPENDENCIES_OK=true

check_dependency "python3" || DEPENDENCIES_OK=false
check_dependency "pip3" || DEPENDENCIES_OK=false
check_dependency "mosquitto_pub" || DEPENDENCIES_OK=false
check_dependency "docker" || DEPENDENCIES_OK=false
check_dependency "docker-compose" || DEPENDENCIES_OK=false
check_dependency "bc" || DEPENDENCIES_OK=false
check_dependency "jq" || DEPENDENCIES_OK=false

if [ "$DEPENDENCIES_OK" = false ]; then
    echo ""
    echo "❌ 필수 의존성이 설치되지 않았습니다."
    echo "다음 명령어로 설치하세요:"
    echo "  brew install mosquitto jq bc"
    echo "  pip3 install paho-mqtt redis requests psutil kafka-python"
    exit 1
fi

# Python 패키지 확인
echo ""
echo "Python 패키지 설치 확인 중..."
python3 -c "
import sys
packages = ['paho.mqtt', 'redis', 'requests', 'psutil', 'kafka']
missing = []
for pkg in packages:
    try:
        __import__(pkg)
        print(f'✓ {pkg}')
    except ImportError:
        print(f'✗ {pkg}')
        missing.append(pkg)
if missing:
    print(f'Missing packages: {missing}')
    print('Install with: pip3 install ' + ' '.join(missing))
    sys.exit(1)
"

if [ $? -ne 0 ]; then
    echo "❌ Python 패키지를 설치해주세요"
    exit 1
fi

echo "✓ 모든 의존성 확인 완료"

# Docker 서비스 상태 확인
echo ""
echo "=== Docker 서비스 상태 확인 ==="
cd /Users/minjcho/development/ssafy/mqttserver

if ! docker compose ps > /dev/null 2>&1; then
    echo "⚠️  Docker 서비스가 실행되지 않고 있습니다. 시작합니다..."
    make setup
    sleep 30
fi

# 서비스 헬스체크
services=("mosquitto:3123" "kafka:9092" "redis:6379" "websocket-server:8081")
for service in "${services[@]}"; do
    name=$(echo $service | cut -d: -f1)
    port=$(echo $service | cut -d: -f2)
    
    if nc -z 3.36.126.83 $port 2>/dev/null; then
        echo "✓ $name (포트 $port) 정상"
    else
        echo "✗ $name (포트 $port) 장애"
    fi
done

echo ""
echo "=========================================="
echo "성능 테스트 시작"
echo "=========================================="

# 시스템 모니터링 백그라운드 시작
echo ""
echo "=== 시스템 모니터링 시작 ==="
python3 $TEST_DIR/system_monitor.py --output $RESULTS_DIR --duration 1800 > $RESULTS_DIR/monitor.log 2>&1 &
MONITOR_PID=$!
echo "시스템 모니터링이 백그라운드에서 시작됨 (PID: $MONITOR_PID)"

# 테스트 실행 함수
run_test() {
    local test_name=$1
    local test_command=$2
    local description=$3
    
    echo ""
    echo "----------------------------------------"
    echo "[$test_name] $description"
    echo "시작 시간: $(date)"
    echo "----------------------------------------"
    
    local start_time=$(date +%s)
    
    # 테스트 실행
    eval $test_command > $RESULTS_DIR/${test_name}.log 2>&1
    local exit_code=$?
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        echo "✓ $test_name 완료 (${duration}초)"
    else
        echo "✗ $test_name 실패 (${duration}초)"
    fi
    
    echo "$test_name,$exit_code,$duration,$(date)" >> $RESULTS_DIR/test_results.csv
}

# CSV 헤더 생성
echo "test_name,exit_code,duration_seconds,completed_at" > $RESULTS_DIR/test_results.csv

# 1. 대량 메시지 처리량 테스트
run_test "load_test" \
    "chmod +x $TEST_DIR/load_test.sh && $TEST_DIR/load_test.sh" \
    "대량 MQTT 메시지 처리량 테스트"

sleep 10

# 2. 지연시간 테스트
run_test "latency_test" \
    "python3 $TEST_DIR/latency_test.py --count 200" \
    "End-to-End 지연시간 측정"

sleep 5

# 3. 동시 연결 부하 테스트
run_test "concurrent_test" \
    "chmod +x $TEST_DIR/concurrent_test.sh && $TEST_DIR/concurrent_test.sh" \
    "동시 연결 부하 테스트"

sleep 10

# 4. Kafka 성능 테스트
run_test "kafka_performance" \
    "python3 $TEST_DIR/kafka_performance_test.py --test partition" \
    "Kafka 파티션 성능 테스트"

sleep 5

# 5. Redis 벤치마크
run_test "redis_benchmark" \
    "python3 $TEST_DIR/redis_benchmark.py --operations 5000 --cleanup" \
    "Redis 성능 벤치마크"

sleep 5

# 6. MQTT 클라이언트 성능 테스트
run_test "mqtt_client_performance" \
    "python3 $TEST_DIR/mqtt_client_performance.py --test all --duration 60" \
    "MQTT 클라이언트 성능 테스트"

sleep 5

# 7. HTTP vs MQTT 비교
run_test "http_vs_mqtt" \
    "python3 $TEST_DIR/http_vs_mqtt_comparison.py --requests 500 --concurrent 5" \
    "HTTP API vs MQTT 성능 비교"

sleep 10

# 8. 장애 복구력 테스트 (선택적)
echo ""
echo "장애 복구력 테스트를 실행하시겠습니까? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    run_test "fault_tolerance" \
        "chmod +x $TEST_DIR/fault_tolerance_test.sh && $TEST_DIR/fault_tolerance_test.sh" \
        "장애 복구력 테스트"
else
    echo "장애 복구력 테스트를 건너뜁니다."
fi

# 시스템 모니터링 종료
echo ""
echo "=== 시스템 모니터링 종료 ==="
if kill -0 $MONITOR_PID 2>/dev/null; then
    kill $MONITOR_PID
    wait $MONITOR_PID 2>/dev/null
    echo "시스템 모니터링이 종료되었습니다."
fi

# 최종 시스템 상태 수집
{
    echo "== 테스트 완료 후 시스템 상태 =="
    echo "완료 시간: $(date)"
    echo ""
    echo "== Docker 컨테이너 상태 =="
    docker compose ps
    echo ""
    echo "== 메모리 사용량 =="
    free -h 2>/dev/null || vm_stat | head -5
    echo ""
    echo "== 디스크 사용량 =="
    df -h /
} >> $RESULTS_DIR/system_info.txt

# 결과 요약 생성
echo ""
echo "=========================================="
echo "테스트 결과 요약 생성"
echo "=========================================="

{
    echo "# MQTT IoT 서버 성능 테스트 결과"
    echo "생성 시간: $(date)"
    echo ""
    echo "## 테스트 환경"
    cat $RESULTS_DIR/system_info.txt | head -20
    echo ""
    echo "## 테스트 실행 결과"
    echo ""
    printf "%-20s %-10s %-15s %s\n" "테스트명" "결과" "소요시간(초)" "완료시간"
    echo "$(printf '%0.s-' {1..70})"
    
    while IFS=',' read -r test_name exit_code duration completed_at; do
        if [ "$test_name" != "test_name" ]; then
            result=$([ "$exit_code" -eq 0 ] && echo "✓ 성공" || echo "✗ 실패")
            printf "%-20s %-10s %-15s %s\n" "$test_name" "$result" "$duration" "$completed_at"
        fi
    done < $RESULTS_DIR/test_results.csv
    
    echo ""
    echo "## 주요 결과 파일"
    echo "- 전체 결과: $RESULTS_DIR/"
    echo "- 시스템 모니터링: $RESULTS_DIR/system_metrics_*.json"
    echo "- 개별 테스트 로그: $RESULTS_DIR/*.log"
    echo ""
    echo "## 추천 분석"
    echo "1. load_test.log: 대량 처리 성능 확인"
    echo "2. latency_test.log: 응답시간 분석"
    echo "3. http_vs_mqtt.log: 프로토콜 비교"
    echo "4. system_metrics_*.csv: 시스템 리소스 사용량 분석"
    
} > $RESULTS_DIR/README.md

# 압축 파일 생성
echo ""
echo "결과 압축 중..."
cd $LOG_DIR
tar -czf "performance_test_results_$TIMESTAMP.tar.gz" $TIMESTAMP/
ARCHIVE_SIZE=$(ls -lh "performance_test_results_$TIMESTAMP.tar.gz" | awk '{print $5}')

echo ""
echo "=========================================="
echo "테스트 완료!"
echo "=========================================="
echo "총 소요 시간: $(($(date +%s) - $(date -j -f "%Y%m%d_%H%M%S" "$TIMESTAMP" +%s 2>/dev/null || echo 0)))초"
echo ""
echo "📊 결과 파일:"
echo "  - 상세 결과: $RESULTS_DIR/"
echo "  - 요약 보고서: $RESULTS_DIR/README.md"
echo "  - 압축 파일: $LOG_DIR/performance_test_results_$TIMESTAMP.tar.gz ($ARCHIVE_SIZE)"
echo ""
echo "📈 다음 단계:"
echo "1. README.md 파일을 확인하여 테스트 결과 요약을 확인하세요"
echo "2. system_metrics_*.csv 파일을 Excel이나 Python으로 분석하세요"
echo "3. 개별 *.log 파일들을 확인하여 상세 성능 지표를 분석하세요"
echo ""
echo "🎯 발표 준비:"
echo "- 처리량: load_test.log에서 'msg/sec' 수치"
echo "- 지연시간: latency_test.log에서 평균/95퍼센타일"
echo "- 비교우위: http_vs_mqtt.log에서 'MQTT 우위' 수치"
echo "- 안정성: fault_tolerance_test.log에서 복구시간과 성공률"

# 결과 디렉토리 열기 (macOS)
if command -v open >/dev/null 2>&1; then
    echo ""
    echo "결과 디렉토리를 열까요? (y/n)"
    read -r open_response
    if [[ "$open_response" =~ ^[Yy]$ ]]; then
        open $RESULTS_DIR
    fi
fi