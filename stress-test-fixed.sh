#!/bin/bash

# EC2 서버 한계 스트레스 테스트 스크립트 (개선 버전)
# 타임아웃과 프로세스 관리 개선

echo "==========================================="
echo "    🔥 EC2 서버 한계 스트레스 테스트 🔥"
echo "    Target: minjcho.site"
echo "    WARNING: 극도의 부하 테스트"
echo "==========================================="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# 테스트 설정
TARGET_HOST="minjcho.site"
MQTT_HOST="minjcho.site"
MQTT_PORT=3123

# 결과 저장 디렉토리
RESULT_DIR="stress-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p $RESULT_DIR

# 프로세스 제한 설정
MAX_BACKGROUND_JOBS=50  # 동시 백그라운드 작업 제한

# 백그라운드 작업 대기 함수
wait_for_jobs() {
    while [ $(jobs -r | wc -l) -ge $MAX_BACKGROUND_JOBS ]; do
        sleep 0.1
    done
}

# 시스템 모니터링 시작
echo -e "${YELLOW}시스템 모니터링 백그라운드 시작...${NC}"
(
    while true; do
        echo "$(date +%Y-%m-%d_%H:%M:%S),$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1),$(free | grep Mem | awk '{print int($3/$2 * 100)}')" >> $RESULT_DIR/system-metrics.csv
        sleep 1
    done
) &
MONITOR_PID=$!

# 초기 상태 기록
echo -e "${BLUE}초기 시스템 상태 기록...${NC}"
echo "=== 초기 상태 ===" > $RESULT_DIR/initial-state.txt
free -h >> $RESULT_DIR/initial-state.txt
top -bn1 | head -10 >> $RESULT_DIR/initial-state.txt
ss -s >> $RESULT_DIR/initial-state.txt
echo ""

# 경고 메시지
echo -e "${RED}⚠️  경고: 이 테스트는 서버를 한계까지 몰아붙입니다!${NC}"
echo -e "${RED}    프로덕션 환경에서는 매우 주의하세요!${NC}"
echo -n "계속하시겠습니까? (yes/no): "
read confirm
if [ "$confirm" != "yes" ]; then
    echo "테스트 취소됨"
    kill $MONITOR_PID 2>/dev/null
    exit 1
fi
echo ""

# 1. MQTT Broker 한계 테스트
echo -e "${MAGENTA}===============================================${NC}"
echo -e "${MAGENTA}1. MQTT Broker 한계 테스트${NC}"
echo -e "${MAGENTA}===============================================${NC}"

# MQTT 연결 테스트
echo "MQTT 연결 확인..."
if ! timeout 5 mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t "test/connection" -m "test" 2>/dev/null; then
    echo -e "${RED}❌ MQTT 연결 실패! Mosquitto가 실행 중인지 확인하세요.${NC}"
    kill $MONITOR_PID 2>/dev/null
    exit 1
fi
echo "✅ MQTT 연결 성공"
echo ""

for concurrent in 100 500 1000 2000 3000 5000; do
    echo -e "${YELLOW}🔥 MQTT 동시 발행자: $concurrent${NC}"
    
    START_TIME=$(date +%s.%N)
    SUCCESS_COUNT=0
    FAIL_COUNT=0
    PIDS=()
    
    # 메시지 발송 (배치 처리)
    BATCH_SIZE=100
    for ((batch=0; batch<$concurrent; batch+=$BATCH_SIZE)); do
        end=$((batch + BATCH_SIZE))
        if [ $end -gt $concurrent ]; then
            end=$concurrent
        fi
        
        echo "  발송 중... $batch-$end / $concurrent"
        
        for ((i=$batch; i<$end; i++)); do
            (
                if timeout 5 mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
                    -t "stress/test/$i" \
                    -m "Stress test message $i - $(date +%s%N)" \
                    -q 0 2>/dev/null; then
                    echo "1" >> $RESULT_DIR/mqtt-success-$concurrent.tmp
                else
                    echo "0" >> $RESULT_DIR/mqtt-fail-$concurrent.tmp
                fi
            ) &
            
            # 프로세스 관리
            wait_for_jobs
        done
        
        # 배치 간 짧은 대기
        sleep 0.5
    done
    
    # 모든 백그라운드 작업 완료 대기 (최대 30초)
    echo "  결과 수집 중..."
    WAIT_COUNT=0
    while [ $(jobs -r | wc -l) -gt 0 ] && [ $WAIT_COUNT -lt 60 ]; do
        sleep 0.5
        ((WAIT_COUNT++))
    done
    
    # 남은 프로세스 강제 종료
    jobs -p | xargs -r kill 2>/dev/null
    
    END_TIME=$(date +%s.%N)
    DURATION=$(echo "$END_TIME - $START_TIME" | bc)
    
    # 결과 집계
    SUCCESS_COUNT=$(wc -l < $RESULT_DIR/mqtt-success-$concurrent.tmp 2>/dev/null || echo 0)
    FAIL_COUNT=$(wc -l < $RESULT_DIR/mqtt-fail-$concurrent.tmp 2>/dev/null || echo 0)
    TOTAL_MESSAGES=$((SUCCESS_COUNT + FAIL_COUNT))
    
    if [ $TOTAL_MESSAGES -gt 0 ]; then
        RATE=$(echo "scale=2; $TOTAL_MESSAGES / $DURATION" | bc)
    else
        RATE=0
    fi
    
    echo "✓ 성공: $SUCCESS_COUNT / 실패: $FAIL_COUNT"
    echo "✓ 소요 시간: ${DURATION}s"
    echo "✓ 처리율: $RATE msg/sec"
    
    # 시스템 상태 체크
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
    echo -e "${BLUE}시스템 상태 - CPU: ${CPU_USAGE}%, Memory: ${MEM_USAGE}%${NC}"
    
    echo "$concurrent,$TOTAL_MESSAGES,$DURATION,$RATE,$FAIL_COUNT,$CPU_USAGE,$MEM_USAGE" >> $RESULT_DIR/mqtt-stress.csv
    
    # 임시 파일 정리
    rm -f $RESULT_DIR/mqtt-success-$concurrent.tmp $RESULT_DIR/mqtt-fail-$concurrent.tmp
    
    # CPU가 90% 넘으면 경고
    if (( $(echo "$CPU_USAGE > 90" | bc -l) )); then
        echo -e "${RED}⚠️  CPU 90% 초과! 테스트 위험 수준${NC}"
        break
    fi
    
    # 메모리가 85% 넘으면 경고
    if [ $MEM_USAGE -gt 85 ]; then
        echo -e "${RED}⚠️  메모리 85% 초과! 테스트 위험 수준${NC}"
        break
    fi
    
    echo ""
    sleep 5  # 다음 테스트 전 쿨다운
done

# 2. HTTP API 한계 테스트
echo -e "${MAGENTA}===============================================${NC}"
echo -e "${MAGENTA}2. HTTP API 한계 테스트${NC}"
echo -e "${MAGENTA}===============================================${NC}"

# API 연결 확인
echo "API 연결 확인..."
if ! curl -s -f -o /dev/null -m 5 https://$TARGET_HOST/api/sensor-data/1420524217000; then
    echo -e "${YELLOW}⚠️  API 응답 없음 또는 404 (정상일 수 있음)${NC}"
fi

if command -v ab &> /dev/null; then
    # 극한 동시 접속 테스트
    for concurrent in 100 500 1000 1500 2000 3000; do
        echo -e "${YELLOW}🔥 HTTP 동시 접속: $concurrent${NC}"
        
        # 센서 데이터 API 스트레스
        echo "Testing Sensor Data API..."
        
        # ab 실행 (타임아웃 30초)
        timeout 30 ab -n 5000 -c $concurrent \
           -g $RESULT_DIR/sensor-stress-$concurrent.tsv \
           -r \
           https://$TARGET_HOST/api/sensor-data/1420524217000 2>&1 | \
           tee $RESULT_DIR/sensor-stress-$concurrent.txt | \
           grep -E "Requests per second|Time per request|Failed requests|Non-2xx"
        
        # 시스템 상태 체크
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
        CONNECTIONS=$(ss -s | grep "estab" | awk '{print $2}')
        
        echo -e "${BLUE}시스템 상태:${NC}"
        echo "  CPU: ${CPU_USAGE}%"
        echo "  Memory: ${MEM_USAGE}%"
        echo "  Established Connections: $CONNECTIONS"
        echo ""
        
        # 메모리가 85% 넘으면 경고
        if [ $MEM_USAGE -gt 85 ]; then
            echo -e "${RED}⚠️  메모리 85% 초과! 테스트 중단${NC}"
            break
        fi
        
        sleep 5
    done
else
    echo "Apache Bench (ab) not installed"
    echo "Install with: sudo apt-get install apache2-utils"
fi

# 3. WebSocket 연결 한계 테스트
echo -e "${MAGENTA}===============================================${NC}"
echo -e "${MAGENTA}3. WebSocket 연결 한계 테스트${NC}"
echo -e "${MAGENTA}===============================================${NC}"

echo -e "${YELLOW}🔥 WebSocket 대량 연결 테스트 (curl 방식)${NC}"

for connections in 100 500 1000 2000 3000; do
    echo -e "${YELLOW}Testing $connections WebSocket connections...${NC}"
    
    SUCCESS=0
    FAIL=0
    BATCH_SIZE=100
    
    for ((batch=0; batch<$connections; batch+=$BATCH_SIZE)); do
        end=$((batch + BATCH_SIZE))
        if [ $end -gt $connections ]; then
            end=$connections
        fi
        
        echo "  연결 시도 중... $batch-$end / $connections"
        
        for ((i=$batch; i<$end; i++)); do
            (
                if timeout 3 curl -s -o /dev/null -w "%{http_code}" \
                    --header "Connection: Upgrade" \
                    --header "Upgrade: websocket" \
                    --header "Sec-WebSocket-Version: 13" \
                    --header "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" \
                    https://$TARGET_HOST/coordinates?orinId=stress$i 2>/dev/null | grep -q "101\|200\|426"; then
                    echo "1" >> $RESULT_DIR/ws-success-$connections.tmp
                else
                    echo "0" >> $RESULT_DIR/ws-fail-$connections.tmp
                fi
            ) &
            
            wait_for_jobs
        done
        
        sleep 0.5
    done
    
    # 결과 대기
    echo "  결과 수집 중..."
    wait
    
    # 결과 집계
    SUCCESS=$(wc -l < $RESULT_DIR/ws-success-$connections.tmp 2>/dev/null || echo 0)
    FAIL=$(wc -l < $RESULT_DIR/ws-fail-$connections.tmp 2>/dev/null || echo 0)
    
    echo "✓ Success: $SUCCESS, Failed: $FAIL"
    echo "$connections,$SUCCESS,$FAIL" >> $RESULT_DIR/websocket-connections.csv
    
    # 임시 파일 정리
    rm -f $RESULT_DIR/ws-success-$connections.tmp $RESULT_DIR/ws-fail-$connections.tmp
    
    # 시스템 상태
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
    echo -e "${BLUE}시스템 상태 - CPU: ${CPU_USAGE}%, Memory: ${MEM_USAGE}%${NC}"
    echo ""
    
    # 메모리 체크
    if [ $MEM_USAGE -gt 85 ]; then
        echo -e "${RED}⚠️  메모리 85% 초과! 테스트 중단${NC}"
        break
    fi
    
    sleep 5
done

# 4. 동시 다중 서비스 스트레스 (최종 한계 테스트)
echo -e "${MAGENTA}===============================================${NC}"
echo -e "${MAGENTA}4. 🔥🔥 최종 한계 테스트 - 모든 서비스 동시 🔥🔥${NC}"
echo -e "${MAGENTA}===============================================${NC}"

echo -e "${RED}⚠️  최종 한계 테스트를 시작합니다!${NC}"
echo -e "${RED}    모든 서비스에 동시에 최대 부하를 가합니다.${NC}"
echo ""

# 모든 서비스 동시 공격
echo "Starting all services stress test simultaneously..."

# MQTT 대량 발송 (백그라운드)
echo "MQTT 2000 messages..."
(
    for ((i=1; i<=2000; i++)); do
        timeout 3 mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "ultimate/stress/$i" \
            -m "Ultimate stress test message $i - $(date +%s%N)" 2>/dev/null &
        
        # 50개마다 대기
        if [ $((i % 50)) -eq 0 ]; then
            wait_for_jobs
            echo "  MQTT: $i/2000 sent"
        fi
    done
) &
MQTT_PID=$!

# HTTP API 연속 요청 (백그라운드)
echo "HTTP 10000 requests..."
if command -v ab &> /dev/null; then
    (
        timeout 60 ab -n 10000 -c 1000 -r \
           https://$TARGET_HOST/api/sensor-data/1420524217000 \
           > $RESULT_DIR/ultimate-http.txt 2>&1
    ) &
    HTTP_PID=$!
fi

# WebSocket 연결 (백그라운드)
echo "WebSocket 500 connections..."
(
    for ((i=1; i<=500; i++)); do
        timeout 3 curl -s -o /dev/null \
            --header "Connection: Upgrade" \
            --header "Upgrade: websocket" \
            https://$TARGET_HOST/coordinates?orinId=ultimate$i 2>/dev/null &
        
        if [ $((i % 50)) -eq 0 ]; then
            wait_for_jobs
            echo "  WebSocket: $i/500 connected"
        fi
    done
) &
WS_PID=$!

# 30초 동안 시스템 상태 모니터링
echo -e "${YELLOW}30초 동안 극한 부하 테스트 진행 중...${NC}"
for ((i=1; i<=30; i++)); do
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "N/A")
    MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}' 2>/dev/null || echo "N/A")
    LOAD=$(uptime | awk -F'load average:' '{print $2}')
    
    printf "[%02d/30] CPU: %5s%% | Mem: %3s%% | Load:%s\n" $i "$CPU_USAGE" "$MEM_USAGE" "$LOAD"
    
    # 위험 수준 체크
    if [ "$MEM_USAGE" != "N/A" ] && [ $MEM_USAGE -gt 90 ]; then
        echo -e "${RED}⚠️  메모리 90% 초과! 테스트 중단!${NC}"
        break
    fi
    
    sleep 1
done

# 프로세스 정리
echo -e "${YELLOW}테스트 프로세스 정리 중...${NC}"
kill $MQTT_PID $HTTP_PID $WS_PID 2>/dev/null
wait $MQTT_PID $HTTP_PID $WS_PID 2>/dev/null

# 남은 mosquitto_pub 프로세스 정리
pkill -f "mosquitto_pub.*stress" 2>/dev/null

# 5. 결과 분석
echo -e "${MAGENTA}===============================================${NC}"
echo -e "${MAGENTA}5. 테스트 결과 분석${NC}"
echo -e "${MAGENTA}===============================================${NC}"

# 모니터링 종료
kill $MONITOR_PID 2>/dev/null

# 최종 시스템 상태
echo -e "${BLUE}=== 최종 시스템 상태 ===${NC}"
free -h
echo ""
top -bn1 | head -10
echo ""
ss -s
echo ""

# 메트릭 분석
if [ -f "$RESULT_DIR/system-metrics.csv" ]; then
    echo -e "${YELLOW}시스템 메트릭 요약:${NC}"
    MAX_CPU=$(awk -F',' '{if($2>max)max=$2}END{print max}' $RESULT_DIR/system-metrics.csv)
    MAX_MEM=$(awk -F',' '{if($3>max)max=$3}END{print max}' $RESULT_DIR/system-metrics.csv)
    AVG_CPU=$(awk -F',' '{sum+=$2; count++}END{if(count>0) print sum/count; else print 0}' $RESULT_DIR/system-metrics.csv)
    AVG_MEM=$(awk -F',' '{sum+=$3; count++}END{if(count>0) print sum/count; else print 0}' $RESULT_DIR/system-metrics.csv)
    
    echo "  최대 CPU 사용률: ${MAX_CPU}%"
    echo "  최대 메모리 사용률: ${MAX_MEM}%"
    printf "  평균 CPU 사용률: %.1f%%\n" $AVG_CPU
    printf "  평균 메모리 사용률: %.1f%%\n" $AVG_MEM
    echo ""
fi

# MQTT 결과 요약
if [ -f "$RESULT_DIR/mqtt-stress.csv" ]; then
    echo -e "${YELLOW}MQTT 스트레스 테스트 결과:${NC}"
    echo "Concurrent | Messages | Duration | Rate | Errors | CPU% | Mem%"
    echo "-----------|----------|----------|------|--------|------|------"
    cat $RESULT_DIR/mqtt-stress.csv | while IFS=',' read -r c m d r e cpu mem; do
        printf "%-10s | %-8s | %8.2f | %4.0f | %-6s | %4s | %5s\n" "$c" "$m" "$d" "$r" "$e" "$cpu" "$mem"
    done
    echo ""
fi

# WebSocket 결과 요약
if [ -f "$RESULT_DIR/websocket-connections.csv" ]; then
    echo -e "${YELLOW}WebSocket 연결 성공률:${NC}"
    echo "Concurrent | Success | Failed | Success Rate"
    echo "-----------|---------|--------|-------------"
    while IFS=',' read -r concurrent success failed; do
        total=$((success + failed))
        if [ $total -gt 0 ]; then
            rate=$(echo "scale=2; $success * 100 / $total" | bc)
            printf "%-10s | %-7s | %-6s | %s%%\n" "$concurrent" "$success" "$failed" "$rate"
        fi
    done < $RESULT_DIR/websocket-connections.csv
    echo ""
fi

# 한계점 판정
echo -e "${GREEN}===============================================${NC}"
echo -e "${GREEN}📊 서버 한계점 분석${NC}"
echo -e "${GREEN}===============================================${NC}"

echo "🔍 발견된 한계점:"
echo ""

# CPU 한계
if (( $(echo "$MAX_CPU > 90" | bc -l) )); then
    echo "❌ CPU 한계: ${MAX_CPU}% 도달 (90% 초과)"
elif (( $(echo "$MAX_CPU > 70" | bc -l) )); then
    echo "⚠️  CPU 주의: ${MAX_CPU}% 도달 (70% 초과)"
else
    echo "✅ CPU: ${MAX_CPU}% 최대 (여유 있음)"
fi

# 메모리 한계
if [ ${MAX_MEM:-0} -gt 90 ]; then
    echo "❌ 메모리 한계: ${MAX_MEM}% 도달 (90% 초과)"
elif [ ${MAX_MEM:-0} -gt 80 ]; then
    echo "⚠️  메모리 주의: ${MAX_MEM}% 도달 (80% 초과)"
else
    echo "✅ 메모리: ${MAX_MEM}% 최대 (여유 있음)"
fi

# 최종 판정
echo ""
echo -e "${GREEN}📈 예상 최대 처리 능력:${NC}"

# MQTT 최대 처리량 계산
if [ -f "$RESULT_DIR/mqtt-stress.csv" ]; then
    MAX_MQTT_RATE=$(awk -F',' '{if($4>max)max=$4}END{print max}' $RESULT_DIR/mqtt-stress.csv 2>/dev/null || echo "N/A")
    echo "  MQTT: 최대 ${MAX_MQTT_RATE} msg/sec"
fi

# HTTP 처리량 확인
for file in $RESULT_DIR/sensor-stress-*.txt; do
    if [ -f "$file" ]; then
        concurrent=$(basename "$file" | sed 's/sensor-stress-\(.*\)\.txt/\1/')
        rps=$(grep "Requests per second" "$file" | awk '{print $4}' | head -1)
        if [ ! -z "$rps" ]; then
            echo "  HTTP API ($concurrent concurrent): ${rps} req/sec"
        fi
    fi
done

echo ""
echo -e "${GREEN}🎯 권장 동시 사용자 수:${NC}"

# 안전한 운영 기준 (CPU 70%, Memory 80%)
if (( $(echo "${MAX_CPU:-0} < 70" | bc -l) )) && [ ${MAX_MEM:-0} -lt 80 ]; then
    echo "  ✅ 안전 운영: 현재 테스트 수준 가능"
    echo "  ✅ 최대 운영: 현재 테스트의 1.2배"
elif (( $(echo "${MAX_CPU:-0} < 90" | bc -l) )) && [ ${MAX_MEM:-0} -lt 90 ]; then
    echo "  ⚠️  안전 운영: 현재 테스트의 0.7배"
    echo "  ⚠️  최대 운영: 현재 테스트 수준"
else
    echo "  ❌ 한계 도달: 현재 테스트의 0.5배 권장"
fi

echo ""
echo -e "${GREEN}===============================================${NC}"
echo "스트레스 테스트 완료!"
echo "결과 디렉토리: $RESULT_DIR"
echo -e "${GREEN}===============================================${NC}"

# 서버 복구 대기
echo ""
echo -e "${YELLOW}서버 안정화를 위해 10초 대기...${NC}"
sleep 10
echo "✅ 테스트 완전 종료"