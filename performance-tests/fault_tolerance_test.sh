#!/bin/bash

echo "=== 장애 복구력 테스트 ==="
echo "시작 시간: $(date)"

MQTT_HOST="3.36.126.83"
MQTT_PORT="3123"
TEST_TOPIC="sensors/fault_test/data"
LOG_DIR="/tmp/fault_test_logs"

# 로그 디렉토리 생성
mkdir -p $LOG_DIR

# 테스트 함수들
check_service_health() {
    local service=$1
    local port=$2
    
    if nc -z 3.36.126.83 $port 2>/dev/null; then
        echo "✓ $service (포트 $port) - 정상"
        return 0
    else
        echo "✗ $service (포트 $port) - 장애"
        return 1
    fi
}

send_test_messages() {
    local test_phase=$1
    local message_count=$2
    
    echo "[$test_phase] $message_count 개 테스트 메시지 발송 중..."
    
    for i in $(seq 1 $message_count); do
        timestamp=$(date +%s%3N)
        message="{\"phase\":\"$test_phase\",\"msg_id\":$i,\"timestamp\":$timestamp,\"data\":\"test_data_$i\"}"
        
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t $TEST_TOPIC -m "$message" 2>>$LOG_DIR/mqtt_errors.log
        
        if [ $? -eq 0 ]; then
            echo "$timestamp,$test_phase,$i,SUCCESS" >> $LOG_DIR/mqtt_send.log
        else
            echo "$timestamp,$test_phase,$i,FAILED" >> $LOG_DIR/mqtt_send.log
        fi
        
        # 메시지 간 간격
        sleep 0.1
    done
}

monitor_message_processing() {
    local duration=$1
    local log_file="$LOG_DIR/processing_monitor.log"
    
    echo "메시지 처리 상황 모니터링 ($duration 초)..."
    echo "시간,Redis키수,Kafka컨슈머그룹" > $log_file
    
    for i in $(seq 1 $duration); do
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Redis 키 개수 확인
        redis_keys=$(docker compose exec -T redis redis-cli DBSIZE 2>/dev/null || echo "0")
        
        # Kafka 컨슈머 그룹 lag 확인
        kafka_lag=$(docker compose exec -T kafka kafka-consumer-groups \
            --bootstrap-server 3.36.126.83:9092 \
            --describe --group mqtt-consumer-group 2>/dev/null | \
            awk 'NR>1 {sum+=$5} END {print sum+0}')
        
        echo "$timestamp,$redis_keys,$kafka_lag" >> $log_file
        echo "  [$i/${duration}s] Redis 키: $redis_keys, Kafka Lag: $kafka_lag"
        
        sleep 1
    done
}

# 1. 시스템 초기 상태 확인
echo ""
echo "=== 1. 초기 시스템 상태 확인 ==="
check_service_health "MQTT Broker" 3123
check_service_health "Kafka" 9092
check_service_health "Redis" 6379
check_service_health "WebSocket Server" 8081

# 초기 로그 파일 생성
echo "timestamp,phase,message_id,status" > $LOG_DIR/mqtt_send.log
echo "timestamp,event,service,status" > $LOG_DIR/service_events.log

# 2. 정상 상태에서 베이스라인 테스트
echo ""
echo "=== 2. 베이스라인 성능 측정 ==="
send_test_messages "BASELINE" 50 &
monitor_message_processing 10

# 처리 완료 대기
wait

# 3. Kafka 장애 시나리오
echo ""
echo "=== 3. Kafka 장애 시나리오 ==="
echo "$(date '+%Y-%m-%d %H:%M:%S'),STOP,Kafka,INITIATED" >> $LOG_DIR/service_events.log

echo "Kafka 서비스 중단..."
docker compose stop kafka
sleep 3

echo "Kafka 중단 상태에서 메시지 발송 (큐잉 테스트)..."
send_test_messages "KAFKA_DOWN" 30 &

# 10초 후 Kafka 복구
sleep 10
echo "$(date '+%Y-%m-%d %H:%M:%S'),START,Kafka,INITIATED" >> $LOG_DIR/service_events.log
echo "Kafka 서비스 복구..."
docker compose start kafka

# Kafka 복구 대기
echo "Kafka 복구 대기 중..."
for i in {1..30}; do
    if check_service_health "Kafka" 9092 >/dev/null; then
        echo "Kafka 복구 완료 (${i}초)"
        break
    fi
    sleep 1
done

echo "$(date '+%Y-%m-%d %H:%M:%S'),RECOVERED,Kafka,CONFIRMED" >> $LOG_DIR/service_events.log

# 복구 후 메시지 처리 확인
echo "복구 후 메시지 처리 모니터링..."
monitor_message_processing 15 &

# 복구 확인을 위한 추가 메시지 발송
send_test_messages "KAFKA_RECOVERED" 20

wait

# 4. Redis 장애 시나리오
echo ""
echo "=== 4. Redis 장애 시나리오 ==="
echo "$(date '+%Y-%m-%d %H:%M:%S'),STOP,Redis,INITIATED" >> $LOG_DIR/service_events.log

echo "Redis 서비스 중단..."
docker compose stop redis
sleep 3

echo "Redis 중단 상태에서 메시지 발송..."
send_test_messages "REDIS_DOWN" 25 &

# 10초 후 Redis 복구
sleep 10
echo "$(date '+%Y-%m-%d %H:%M:%S'),START,Redis,INITIATED" >> $LOG_DIR/service_events.log
echo "Redis 서비스 복구..."
docker compose start redis

# Redis 복구 대기
echo "Redis 복구 대기 중..."
for i in {1..15}; do
    if check_service_health "Redis" 6379 >/dev/null; then
        echo "Redis 복구 완료 (${i}초)"
        break
    fi
    sleep 1
done

echo "$(date '+%Y-%m-%d %H:%M:%S'),RECOVERED,Redis,CONFIRMED" >> $LOG_DIR/service_events.log

# 복구 후 테스트
send_test_messages "REDIS_RECOVERED" 20
monitor_message_processing 10

# 5. WebSocket 서버 장애 시나리오
echo ""
echo "=== 5. WebSocket 서버 장애 시나리오 ==="
echo "$(date '+%Y-%m-%d %H:%M:%S'),STOP,WebSocket,INITIATED" >> $LOG_DIR/service_events.log

echo "WebSocket 서버 중단..."
docker compose stop websocket-server
sleep 3

echo "WebSocket 중단 상태에서 메시지 발송 (백엔드 처리 테스트)..."
send_test_messages "WEBSOCKET_DOWN" 30

# WebSocket 서버 복구
echo "$(date '+%Y-%m-%d %H:%M:%S'),START,WebSocket,INITIATED" >> $LOG_DIR/service_events.log
echo "WebSocket 서버 복구..."
docker compose start websocket-server

# 복구 대기
echo "WebSocket 서버 복구 대기 중..."
for i in {1..20}; do
    if check_service_health "WebSocket Server" 8081 >/dev/null; then
        echo "WebSocket 서버 복구 완료 (${i}초)"
        break
    fi
    sleep 1
done

echo "$(date '+%Y-%m-%d %H:%M:%S'),RECOVERED,WebSocket,CONFIRMED" >> $LOG_DIR/service_events.log

# 6. 다중 서비스 장애 시나리오
echo ""
echo "=== 6. 다중 서비스 장애 시나리오 ==="
echo "Kafka와 Redis 동시 중단..."
docker compose stop kafka redis
sleep 3

echo "다중 장애 상태에서 메시지 발송..."
send_test_messages "MULTI_FAILURE" 20

# 단계적 복구
echo "Kafka 먼저 복구..."
docker compose start kafka
sleep 10

echo "Redis 복구..."
docker compose start redis
sleep 10

echo "복구 완료 후 메시지 발송..."
send_test_messages "MULTI_RECOVERED" 25
monitor_message_processing 15

# 7. 최종 시스템 상태 확인
echo ""
echo "=== 7. 최종 시스템 상태 확인 ==="
check_service_health "MQTT Broker" 3123
check_service_health "Kafka" 9092  
check_service_health "Redis" 6379
check_service_health "WebSocket Server" 8081

# 8. 테스트 결과 분석
echo ""
echo "=== 8. 테스트 결과 분석 ==="

if [ -f "$LOG_DIR/mqtt_send.log" ]; then
    total_messages=$(grep -c "," $LOG_DIR/mqtt_send.log)
    successful_messages=$(grep -c "SUCCESS" $LOG_DIR/mqtt_send.log)
    failed_messages=$(grep -c "FAILED" $LOG_DIR/mqtt_send.log)
    success_rate=$(echo "scale=2; $successful_messages * 100 / $total_messages" | bc -l)
    
    echo "총 발송 메시지: $total_messages"
    echo "성공한 메시지: $successful_messages"
    echo "실패한 메시지: $failed_messages"
    echo "성공률: ${success_rate}%"
fi

# 페이즈별 성공률 분석
echo ""
echo "=== 페이즈별 분석 ==="
for phase in BASELINE KAFKA_DOWN KAFKA_RECOVERED REDIS_DOWN REDIS_RECOVERED WEBSOCKET_DOWN MULTI_FAILURE MULTI_RECOVERED; do
    if grep -q "$phase" $LOG_DIR/mqtt_send.log; then
        phase_total=$(grep "$phase" $LOG_DIR/mqtt_send.log | wc -l)
        phase_success=$(grep "$phase" $LOG_DIR/mqtt_send.log | grep -c "SUCCESS")
        phase_rate=$(echo "scale=1; $phase_success * 100 / $phase_total" | bc -l)
        echo "$phase: $phase_success/$phase_total (${phase_rate}%)"
    fi
done

# 복구 시간 분석
echo ""
echo "=== 서비스 복구 시간 분석 ==="
if [ -f "$LOG_DIR/service_events.log" ]; then
    echo "서비스별 중단/복구 이벤트:"
    cat $LOG_DIR/service_events.log | grep -v "timestamp" | while IFS=',' read timestamp event service status; do
        echo "  $service $event: $timestamp"
    done
fi

echo ""
echo "=== 로그 파일 위치 ==="
echo "MQTT 발송 로그: $LOG_DIR/mqtt_send.log"
echo "서비스 이벤트 로그: $LOG_DIR/service_events.log" 
echo "처리 모니터링 로그: $LOG_DIR/processing_monitor.log"
echo "MQTT 에러 로그: $LOG_DIR/mqtt_errors.log"

echo ""
echo "장애 복구력 테스트 완료: $(date)"