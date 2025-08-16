#!/bin/bash

# EC2 서버 한계 스트레스 테스트 스크립트
# 경고: 서버에 극도의 부하를 가합니다. 프로덕션 환경에서는 주의!

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

if command -v mosquitto_pub &> /dev/null; then
    for concurrent in 100 500 1000 2000 3000 5000; do
        echo -e "${YELLOW}🔥 MQTT 동시 발행자: $concurrent${NC}"
        
        START_TIME=$(date +%s.%N)
        ERROR_COUNT=0
        SUCCESS_COUNT=0
        
        # 대량 메시지 발송
        for ((i=1; i<=$concurrent; i++)); do
            (
                for ((j=1; j<=10; j++)); do
                    if mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
                        -t "stress/test/$i" \
                        -m "Stress test from publisher $i - message $j - $(date +%s%N)" \
                        -q 0 2>/dev/null; then
                        ((SUCCESS_COUNT++))
                    else
                        ((ERROR_COUNT++))
                    fi
                done
            ) &
            
            # 100개마다 잠시 대기 (서버 과부하 방지)
            if [ $((i % 100)) -eq 0 ]; then
                sleep 0.1
            fi
        done
        
        wait
        END_TIME=$(date +%s.%N)
        DURATION=$(echo "$END_TIME - $START_TIME" | bc)
        TOTAL_MESSAGES=$((concurrent * 10))
        RATE=$(echo "scale=2; $TOTAL_MESSAGES / $DURATION" | bc)
        
        echo "✓ 전송 시도: $TOTAL_MESSAGES messages"
        echo "✓ 소요 시간: ${DURATION}s"
        echo "✓ 처리율: $RATE msg/sec"
        echo "✓ 에러: $ERROR_COUNT"
        
        # 시스템 상태 체크
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
        echo -e "${BLUE}시스템 상태 - CPU: ${CPU_USAGE}%, Memory: ${MEM_USAGE}%${NC}"
        
        echo "$concurrent,$TOTAL_MESSAGES,$DURATION,$RATE,$ERROR_COUNT,$CPU_USAGE,$MEM_USAGE" >> $RESULT_DIR/mqtt-stress.csv
        
        # CPU가 90% 넘으면 경고
        if (( $(echo "$CPU_USAGE > 90" | bc -l) )); then
            echo -e "${RED}⚠️  CPU 90% 초과! 테스트 위험 수준${NC}"
        fi
        
        echo ""
        sleep 5  # 다음 테스트 전 쿨다운
    done
else
    echo "mosquitto_pub not installed"
fi

# 2. HTTP API 한계 테스트
echo -e "${MAGENTA}===============================================${NC}"
echo -e "${MAGENTA}2. HTTP API 한계 테스트${NC}"
echo -e "${MAGENTA}===============================================${NC}"

if command -v ab &> /dev/null; then
    # 극한 동시 접속 테스트
    for concurrent in 100 500 1000 1500 2000 3000; do
        echo -e "${YELLOW}🔥 HTTP 동시 접속: $concurrent${NC}"
        
        # 센서 데이터 API 스트레스
        echo "Testing Sensor Data API..."
        ab -n 5000 -c $concurrent \
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
        
        # 메모리가 90% 넘으면 경고
        if [ $MEM_USAGE -gt 90 ]; then
            echo -e "${RED}⚠️  메모리 90% 초과! 테스트 중단 권장${NC}"
            break
        fi
        
        sleep 5
    done
fi

# 3. WebSocket 연결 한계 테스트
echo -e "${MAGENTA}===============================================${NC}"
echo -e "${MAGENTA}3. WebSocket 연결 한계 테스트${NC}"
echo -e "${MAGENTA}===============================================${NC}"

echo -e "${YELLOW}🔥 WebSocket 대량 연결 테스트${NC}"

# Node.js 스크립트 생성 (대량 WebSocket 연결용)
cat > /tmp/ws-stress.js << 'EOF'
const SockJS = require('sockjs-client');

const connections = parseInt(process.argv[2]) || 100;
const url = process.argv[3] || 'https://minjcho.site/coordinates';
let connected = 0;
let failed = 0;
let clients = [];

console.log(`Opening ${connections} WebSocket connections to ${url}`);

for (let i = 0; i < connections; i++) {
    setTimeout(() => {
        try {
            const client = new SockJS(`${url}?orinId=stress${i}`);
            
            client.onopen = () => {
                connected++;
                if (connected % 100 === 0) {
                    console.log(`Connected: ${connected}/${connections}`);
                }
            };
            
            client.onerror = (error) => {
                failed++;
                console.error(`Connection ${i} failed:`, error.message);
            };
            
            client.onclose = () => {
                // Connection closed
            };
            
            clients.push(client);
        } catch (error) {
            failed++;
            console.error(`Failed to create connection ${i}:`, error.message);
        }
    }, i * 10); // 10ms 간격으로 연결 시도
}

// 30초 후 결과 출력 및 종료
setTimeout(() => {
    console.log(`\nResults:`);
    console.log(`Successfully connected: ${connected}`);
    console.log(`Failed connections: ${failed}`);
    console.log(`Success rate: ${(connected/(connected+failed)*100).toFixed(2)}%`);
    
    // 연결 종료
    clients.forEach(client => {
        try { client.close(); } catch(e) {}
    });
    
    process.exit(0);
}, 30000);
EOF

# Node.js가 있으면 WebSocket 스트레스 테스트 실행
if command -v node &> /dev/null; then
    # sockjs-client 설치 확인
    if ! npm list sockjs-client &>/dev/null; then
        echo "Installing sockjs-client..."
        npm install sockjs-client &>/dev/null
    fi
    
    for connections in 100 500 1000 2000 3000; do
        echo -e "${YELLOW}Testing $connections WebSocket connections...${NC}"
        timeout 35 node /tmp/ws-stress.js $connections https://$TARGET_HOST/coordinates 2>&1 | tee $RESULT_DIR/ws-stress-$connections.log
        
        # 시스템 상태
        CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
        echo -e "${BLUE}시스템 상태 - CPU: ${CPU_USAGE}%, Memory: ${MEM_USAGE}%${NC}"
        echo ""
        
        sleep 5
    done
else
    echo "Node.js not installed. Using curl fallback..."
    
    for connections in 100 500 1000; do
        echo -e "${YELLOW}Opening $connections connections (curl)...${NC}"
        SUCCESS=0
        FAIL=0
        
        for ((i=1; i<=$connections; i++)); do
            timeout 2 curl -s -o /dev/null \
                --header "Connection: Upgrade" \
                --header "Upgrade: websocket" \
                https://$TARGET_HOST/coordinates?orinId=stress$i &>/dev/null
            
            if [ $? -eq 0 ]; then
                ((SUCCESS++))
            else
                ((FAIL++))
            fi
            
            if [ $((i % 100)) -eq 0 ]; then
                echo "Progress: $i/$connections"
            fi
        done
        
        echo "✓ Success: $SUCCESS, Failed: $FAIL"
        echo ""
        sleep 5
    done
fi

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
(
    for ((i=1; i<=2000; i++)); do
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
            -t "ultimate/stress/$i" \
            -m "Ultimate stress test message $i - $(date +%s%N)" &
        if [ $((i % 100)) -eq 0 ]; then
            sleep 0.1
        fi
    done
) &
MQTT_PID=$!

# HTTP API 연속 요청 (백그라운드)
(
    ab -n 10000 -c 1000 -r \
       https://$TARGET_HOST/api/sensor-data/1420524217000 \
       > $RESULT_DIR/ultimate-http.txt 2>&1
) &
HTTP_PID=$!

# WebSocket 연결 (백그라운드)
(
    for ((i=1; i<=500; i++)); do
        curl -s -o /dev/null \
            --header "Connection: Upgrade" \
            --header "Upgrade: websocket" \
            https://$TARGET_HOST/coordinates?orinId=ultimate$i &
    done
) &
WS_PID=$!

# 30초 동안 시스템 상태 모니터링
echo -e "${YELLOW}30초 동안 극한 부하 테스트 진행 중...${NC}"
for ((i=1; i<=30; i++)); do
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "N/A")
    MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}' 2>/dev/null || echo "N/A")
    LOAD=$(uptime | awk -F'load average:' '{print $2}')
    
    echo -e "[$i/30] CPU: ${CPU_USAGE}% | Mem: ${MEM_USAGE}% | Load:${LOAD}"
    
    # 위험 수준 체크
    if [ "$MEM_USAGE" != "N/A" ] && [ $MEM_USAGE -gt 95 ]; then
        echo -e "${RED}⚠️  메모리 95% 초과! 테스트 중단!${NC}"
        break
    fi
    
    sleep 1
done

# 프로세스 정리
echo -e "${YELLOW}테스트 프로세스 정리 중...${NC}"
kill $MQTT_PID $HTTP_PID $WS_PID 2>/dev/null
wait $MQTT_PID $HTTP_PID $WS_PID 2>/dev/null

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
    AVG_CPU=$(awk -F',' '{sum+=$2; count++}END{print sum/count}' $RESULT_DIR/system-metrics.csv)
    AVG_MEM=$(awk -F',' '{sum+=$3; count++}END{print sum/count}' $RESULT_DIR/system-metrics.csv)
    
    echo "  최대 CPU 사용률: ${MAX_CPU}%"
    echo "  최대 메모리 사용률: ${MAX_MEM}%"
    echo "  평균 CPU 사용률: ${AVG_CPU}%"
    echo "  평균 메모리 사용률: ${AVG_MEM}%"
    echo ""
fi

# MQTT 결과 요약
if [ -f "$RESULT_DIR/mqtt-stress.csv" ]; then
    echo -e "${YELLOW}MQTT 스트레스 테스트 결과:${NC}"
    echo "Concurrent | Messages | Duration | Rate | Errors | CPU% | Mem%"
    echo "-----------|----------|----------|------|--------|------|------"
    cat $RESULT_DIR/mqtt-stress.csv | while IFS=',' read -r c m d r e cpu mem; do
        printf "%-10s | %-8s | %-8s | %-4s | %-6s | %-4s | %-5s\n" "$c" "$m" "$d" "$r" "$e" "$cpu" "$mem"
    done
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
else
    echo "✅ CPU: ${MAX_CPU}% 최대 (여유 있음)"
fi

# 메모리 한계
if [ $MAX_MEM -gt 90 ]; then
    echo "❌ 메모리 한계: ${MAX_MEM}% 도달 (90% 초과)"
else
    echo "✅ 메모리: ${MAX_MEM}% 최대 (여유 있음)"
fi

# 최종 판정
echo ""
echo -e "${GREEN}📈 예상 최대 처리 능력:${NC}"

# MQTT 최대 처리량 계산
MAX_MQTT_RATE=$(awk -F',' '{if($4>max)max=$4}END{print max}' $RESULT_DIR/mqtt-stress.csv 2>/dev/null || echo "N/A")
echo "  MQTT: 최대 ${MAX_MQTT_RATE} msg/sec"

# HTTP 처리량 확인
if [ -f "$RESULT_DIR/sensor-stress-1000.txt" ]; then
    HTTP_RPS=$(grep "Requests per second" $RESULT_DIR/sensor-stress-1000.txt | awk '{print $4}')
    echo "  HTTP API: 최대 ${HTTP_RPS} req/sec"
fi

echo ""
echo -e "${GREEN}🎯 권장 동시 사용자 수:${NC}"

# 안전한 운영 기준 (CPU 70%, Memory 80%)
if (( $(echo "$MAX_CPU < 70" | bc -l) )) && [ $MAX_MEM -lt 80 ]; then
    echo "  안전 운영: 현재 테스트 수준 가능"
    echo "  최대 운영: 현재 테스트의 1.2배"
elif (( $(echo "$MAX_CPU < 90" | bc -l) )) && [ $MAX_MEM -lt 90 ]; then
    echo "  안전 운영: 현재 테스트의 0.7배"
    echo "  최대 운영: 현재 테스트 수준"
else
    echo "  ⚠️  한계 도달: 현재 테스트의 0.5배 권장"
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