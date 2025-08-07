#!/bin/bash

echo "=== 동시 연결 부하 테스트 ==="

MQTT_HOST="3.36.126.83"
MQTT_PORT="3123"
WEBSOCKET_URL="ws://3.36.126.83:8081/ws/coordinates"
REDIS_API_URL="http://3.36.126.83:8081/api"

# 테스트 파라미터
MQTT_SUBSCRIBERS=50
WEBSOCKET_CLIENTS=100
TEST_DURATION=30

echo "MQTT 구독자 수: $MQTT_SUBSCRIBERS"
echo "WebSocket 클라이언트 수: $WEBSOCKET_CLIENTS"
echo "테스트 지속시간: ${TEST_DURATION}초"
echo ""

# PID 추적을 위한 배열
declare -a mqtt_pids=()
declare -a websocket_pids=()

# MQTT 구독자들 시작
echo "MQTT 구독자 시작 중..."
for i in $(seq 1 $MQTT_SUBSCRIBERS); do
    robot_id=$((i % 10 + 1))
    mosquitto_sub -h $MQTT_HOST -p $MQTT_PORT -t "sensors/robot$robot_id/+" -v > /tmp/mqtt_sub_$i.log 2>&1 &
    mqtt_pids+=($!)
    
    if [ $((i % 10)) -eq 0 ]; then
        echo "  $i/$MQTT_SUBSCRIBERS MQTT 구독자 시작됨"
    fi
done

echo "모든 MQTT 구독자 시작 완료"

# WebSocket 클라이언트들 시작 (wscat 사용)
echo "WebSocket 클라이언트 시작 중..."
for i in $(seq 1 $WEBSOCKET_CLIENTS); do
    if command -v wscat >/dev/null 2>&1; then
        wscat -c $WEBSOCKET_URL > /tmp/ws_client_$i.log 2>&1 &
        websocket_pids+=($!)
    else
        # wscat이 없으면 curl로 대체
        curl -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
             -H "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" \
             -H "Sec-WebSocket-Version: 13" \
             $WEBSOCKET_URL > /tmp/ws_client_$i.log 2>&1 &
        websocket_pids+=($!)
    fi
    
    if [ $((i % 20)) -eq 0 ]; then
        echo "  $i/$WEBSOCKET_CLIENTS WebSocket 클라이언트 시작됨"
    fi
done

echo "모든 WebSocket 클라이언트 시작 완료"
echo ""

# 시스템 리소스 모니터링 시작
echo "시스템 리소스 모니터링 시작..."
{
    echo "시간,CPU사용률,메모리사용률,TCP연결수" > /tmp/system_monitor.csv
    for i in $(seq 1 $TEST_DURATION); do
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        cpu_usage=$(top -l1 -n0 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
        memory_usage=$(top -l1 -n0 | grep "PhysMem" | awk '{print $2}' | sed 's/M//')
        tcp_connections=$(netstat -an | grep -E "(3123|8081|6379|9092)" | wc -l)
        
        echo "$timestamp,$cpu_usage,$memory_usage,$tcp_connections" >> /tmp/system_monitor.csv
        echo "[$i/${TEST_DURATION}s] CPU: ${cpu_usage}%, 메모리: ${memory_usage}M, TCP: $tcp_connections"
        
        sleep 1
    done
} &
monitor_pid=$!

# 메시지 발송으로 부하 생성
echo "메시지 발송으로 부하 생성 중..."
{
    for i in $(seq 1 $TEST_DURATION); do
        for robot_id in {1..10}; do
            coord_x=$((RANDOM % 1000))
            coord_y=$((RANDOM % 1000))
            motor_rpm=$((1000 + RANDOM % 2000))
            
            mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t "sensors/robot$robot_id/coordX" -m "$coord_x" &
            mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t "sensors/robot$robot_id/coordY" -m "$coord_y" &
            mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t "sensors/robot$robot_id/motorRPM" -m "$motor_rpm" &
        done
        sleep 1
    done
} &
publisher_pid=$!

# 테스트 지속 시간 대기
echo "테스트 실행 중... (${TEST_DURATION}초 대기)"
sleep $TEST_DURATION

# 모든 프로세스 정리
echo ""
echo "테스트 종료 중..."

# 발송 프로세스 종료
kill $publisher_pid 2>/dev/null
kill $monitor_pid 2>/dev/null

# MQTT 구독자들 종료
echo "MQTT 구독자들 종료 중..."
for pid in "${mqtt_pids[@]}"; do
    kill $pid 2>/dev/null
done

# WebSocket 클라이언트들 종료
echo "WebSocket 클라이언트들 종료 중..."
for pid in "${websocket_pids[@]}"; do
    kill $pid 2>/dev/null
done

# 정리 대기
sleep 2

# 결과 분석
echo ""
echo "=== 테스트 결과 분석 ==="

# MQTT 구독 성공률 계산
mqtt_success=0
for i in $(seq 1 $MQTT_SUBSCRIBERS); do
    if [ -s "/tmp/mqtt_sub_$i.log" ]; then
        mqtt_success=$((mqtt_success + 1))
    fi
done

# WebSocket 연결 성공률 계산
ws_success=0
for i in $(seq 1 $WEBSOCKET_CLIENTS); do
    if [ -s "/tmp/ws_client_$i.log" ]; then
        ws_success=$((ws_success + 1))
    fi
done

echo "MQTT 구독 성공률: $mqtt_success/$MQTT_SUBSCRIBERS ($(echo "scale=1; $mqtt_success * 100 / $MQTT_SUBSCRIBERS" | bc -l)%)"
echo "WebSocket 연결 성공률: $ws_success/$WEBSOCKET_CLIENTS ($(echo "scale=1; $ws_success * 100 / $WEBSOCKET_CLIENTS" | bc -l)%)"

# 시스템 모니터링 결과 요약
if [ -f "/tmp/system_monitor.csv" ]; then
    echo ""
    echo "시스템 리소스 사용량 요약:"
    echo "평균 CPU 사용률: $(awk -F, 'NR>1 {sum+=$2; count++} END {if(count>0) printf "%.1f%%", sum/count}' /tmp/system_monitor.csv)"
    echo "최대 TCP 연결 수: $(awk -F, 'NR>1 {if($4>max) max=$4} END {print max+0}' /tmp/system_monitor.csv)"
    echo ""
    echo "상세 모니터링 로그: /tmp/system_monitor.csv"
fi

# 로그 파일 정리 (선택사항)
echo ""
echo "로그 파일 정리 중..."
rm -f /tmp/mqtt_sub_*.log /tmp/ws_client_*.log

echo "테스트 완료!"