#!/bin/bash

# EC2 서버 부하 테스트 스크립트
# 필요 도구: ab, curl, mosquitto-clients, jq

echo "==========================================="
echo "    EC2 서버 부하 테스트"
echo "    Target: minjcho.site"
echo "    Date: $(date)"
echo "==========================================="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 테스트 설정
TARGET_HOST="minjcho.site"
MQTT_HOST="minjcho.site"
MQTT_PORT=3123

# 결과 저장 디렉토리
RESULT_DIR="load-test-$(date +%Y%m%d-%H%M%S)"
mkdir -p $RESULT_DIR

# 동시 접속자 수 설정
CONCURRENT_USERS=(10 50 100 200 500)
TOTAL_REQUESTS=1000

echo -e "${BLUE}테스트 환경 준비${NC}"
echo "-------------------------------------------"
echo "Target Host: $TARGET_HOST"
echo "Test Levels: ${CONCURRENT_USERS[@]} concurrent users"
echo "Total Requests per Test: $TOTAL_REQUESTS"
echo ""

# 1. MQTT Broker 부하 테스트
echo -e "${BLUE}1. MQTT Broker 부하 테스트${NC}"
echo "-------------------------------------------"

if command -v mosquitto_pub &> /dev/null; then
    echo "Testing MQTT message throughput..."
    
    for concurrent in ${CONCURRENT_USERS[@]}; do
        echo -e "${YELLOW}Testing with $concurrent concurrent publishers...${NC}"
        
        START_TIME=$(date +%s.%N)
        
        # 동시에 여러 publisher 실행
        for ((i=1; i<=$concurrent; i++)); do
            (
                for ((j=1; j<=10; j++)); do
                    mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT \
                        -t "load/test/$i" \
                        -m "Test message from publisher $i - message $j" \
                        2>/dev/null
                done
            ) &
        done
        
        wait
        END_TIME=$(date +%s.%N)
        DURATION=$(echo "$END_TIME - $START_TIME" | bc)
        MESSAGES=$((concurrent * 10))
        RATE=$(echo "scale=2; $MESSAGES / $DURATION" | bc)
        
        echo "✓ Sent $MESSAGES messages in ${DURATION}s"
        echo "✓ Message rate: $RATE msg/sec"
        echo "$concurrent,$MESSAGES,$DURATION,$RATE" >> $RESULT_DIR/mqtt-throughput.csv
        echo ""
        
        sleep 2
    done
else
    echo "mosquitto_pub not installed. Skipping MQTT tests."
fi

# 2. WebSocket API 부하 테스트
echo -e "${BLUE}2. WebSocket/REST API 부하 테스트${NC}"
echo "-------------------------------------------"

# API 엔드포인트 목록
declare -A apis
apis["MQTT Command API"]="/api/mqtt/commands/1420524217000"
apis["Sensor Data API"]="/api/sensor-data/1420524217000"
apis["Map Data API"]="/api/map-data/1420524217000/latest"

if command -v ab &> /dev/null; then
    for api_name in "${!apis[@]}"; do
        api_path=${apis[$api_name]}
        echo -e "${YELLOW}Testing $api_name${NC}"
        echo "Endpoint: https://$TARGET_HOST$api_path"
        echo ""
        
        for concurrent in ${CONCURRENT_USERS[@]}; do
            echo "Testing with $concurrent concurrent users..."
            
            if [[ "$api_name" == "MQTT Command API" ]]; then
                # POST 요청용 데이터 준비
                echo '{"command":"STATUS"}' > /tmp/test_payload.json
                ab -n $TOTAL_REQUESTS -c $concurrent \
                   -T application/json \
                   -p /tmp/test_payload.json \
                   -g $RESULT_DIR/${api_name// /_}-$concurrent.tsv \
                   https://$TARGET_HOST$api_path 2>&1 | \
                   grep -E "Requests per second|Time per request|Transfer rate|Failed requests|Non-2xx responses" | \
                   tee -a $RESULT_DIR/${api_name// /_}-summary.txt
            else
                # GET 요청
                ab -n $TOTAL_REQUESTS -c $concurrent \
                   -g $RESULT_DIR/${api_name// /_}-$concurrent.tsv \
                   https://$TARGET_HOST$api_path 2>&1 | \
                   grep -E "Requests per second|Time per request|Transfer rate|Failed requests|Non-2xx responses" | \
                   tee -a $RESULT_DIR/${api_name// /_}-summary.txt
            fi
            
            echo ""
            sleep 3
        done
        echo "---"
    done
else
    echo "Apache Bench (ab) not installed. Install with: apt-get install apache2-utils"
fi

# 3. WebSocket 연결 테스트
echo -e "${BLUE}3. WebSocket 동시 연결 테스트${NC}"
echo "-------------------------------------------"

echo "Testing WebSocket connections..."
for concurrent in 10 50 100; do
    echo -e "${YELLOW}Opening $concurrent WebSocket connections...${NC}"
    
    SUCCESS_COUNT=0
    FAIL_COUNT=0
    
    for ((i=1; i<=$concurrent; i++)); do
        # WebSocket 연결 시도 (timeout 5초)
        timeout 5 curl -s -o /dev/null -w "%{http_code}" \
            --header "Connection: Upgrade" \
            --header "Upgrade: websocket" \
            --header "Sec-WebSocket-Version: 13" \
            --header "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" \
            https://$TARGET_HOST/coordinates?orinId=test$i &>/dev/null
        
        if [ $? -eq 0 ]; then
            ((SUCCESS_COUNT++))
        else
            ((FAIL_COUNT++))
        fi
    done
    
    echo "✓ Successful connections: $SUCCESS_COUNT"
    echo "✗ Failed connections: $FAIL_COUNT"
    echo "$concurrent,$SUCCESS_COUNT,$FAIL_COUNT" >> $RESULT_DIR/websocket-connections.csv
    echo ""
done

# 4. 데이터베이스 부하 테스트 (QR Login)
echo -e "${BLUE}4. QR Login System 부하 테스트${NC}"
echo "-------------------------------------------"

# QR 초기화 API 테스트
if command -v ab &> /dev/null; then
    echo "Testing QR initialization endpoint..."
    
    for concurrent in 10 50 100; do
        echo "Testing with $concurrent concurrent users..."
        
        ab -n 500 -c $concurrent \
           -g $RESULT_DIR/qr-init-$concurrent.tsv \
           https://$TARGET_HOST/api/qr/init 2>&1 | \
           grep -E "Requests per second|Time per request|Failed requests" | \
           tee -a $RESULT_DIR/qr-performance.txt
        
        echo ""
        sleep 2
    done
fi

# 5. 시스템 리소스 모니터링 (원격)
echo -e "${BLUE}5. 서버 응답 시간 측정${NC}"
echo "-------------------------------------------"

echo "Measuring server response times..."
for i in {1..10}; do
    RESPONSE_TIME=$(curl -o /dev/null -s -w '%{time_total}\n' https://$TARGET_HOST)
    echo "Attempt $i: ${RESPONSE_TIME}s"
    echo "$i,$RESPONSE_TIME" >> $RESULT_DIR/response-times.csv
    sleep 1
done

# 6. 결과 분석
echo -e "${BLUE}6. 테스트 결과 분석${NC}"
echo "==========================================="

# MQTT 처리량 분석
if [ -f "$RESULT_DIR/mqtt-throughput.csv" ]; then
    echo -e "${YELLOW}MQTT Broker 처리량:${NC}"
    echo "Concurrent Users | Messages | Duration | Rate (msg/sec)"
    echo "-----------------|----------|----------|---------------"
    while IFS=',' read -r concurrent messages duration rate; do
        printf "%-16s | %-8s | %-8s | %-14s\n" "$concurrent" "$messages" "$duration" "$rate"
    done < $RESULT_DIR/mqtt-throughput.csv
    echo ""
fi

# API 성능 요약
echo -e "${YELLOW}API 성능 요약:${NC}"
for summary_file in $RESULT_DIR/*-summary.txt; do
    if [ -f "$summary_file" ]; then
        basename "$summary_file" .txt
        cat "$summary_file"
        echo "---"
    fi
done

# WebSocket 연결 성공률
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

# 평균 응답 시간
if [ -f "$RESULT_DIR/response-times.csv" ]; then
    echo -e "${YELLOW}평균 응답 시간:${NC}"
    avg=$(awk -F',' '{sum+=$2; count++} END {print sum/count}' $RESULT_DIR/response-times.csv)
    echo "Average Response Time: ${avg}s"
    echo ""
fi

echo -e "${GREEN}==========================================="
echo "부하 테스트 완료!"
echo "결과 디렉토리: $RESULT_DIR"
echo "==========================================="
echo ""

# 7. 권장사항
echo -e "${BLUE}성능 최적화 권장사항:${NC}"
echo "-------------------------------------------"
echo "1. MQTT Broker:"
echo "   - mosquitto.conf에서 max_connections 증가"
echo "   - max_queued_messages 조정"
echo ""
echo "2. WebSocket Server:"
echo "   - Spring Boot의 server.tomcat.max-threads 증가"
echo "   - server.tomcat.accept-count 조정"
echo ""
echo "3. Database:"
echo "   - PostgreSQL connection pool 크기 증가"
echo "   - Redis maxclients 설정 확인"
echo ""
echo "4. System:"
echo "   - ulimit -n (file descriptors) 증가"
echo "   - net.core.somaxconn 커널 파라미터 조정"
echo "==========================================="