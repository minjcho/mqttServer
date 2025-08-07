#!/bin/bash

echo "=== MQTT 대량 메시지 처리량 테스트 ==="
echo "시작 시간: $(date)"

# 테스트 파라미터
ROBOT_COUNT=10
MESSAGES_PER_ROBOT=1000
MQTT_HOST="3.36.126.83"
MQTT_PORT="3123"

echo "로봇 수: $ROBOT_COUNT"
echo "로봇당 메시지 수: $MESSAGES_PER_ROBOT"
echo "총 메시지 수: $((ROBOT_COUNT * MESSAGES_PER_ROBOT * 3))"
echo ""

# 시작 시간 기록
start_time=$(date +%s%3N)

echo "메시지 발송 시작..."
for robot_id in $(seq 1 $ROBOT_COUNT); do
    echo "Robot $robot_id 메시지 발송 중..."
    
    for msg_id in $(seq 1 $MESSAGES_PER_ROBOT); do
        # 랜덤 좌표 생성
        coord_x=$((RANDOM % 1000))
        coord_y=$((RANDOM % 1000))
        motor_rpm=$((1000 + RANDOM % 2000))
        
        # 병렬로 메시지 발송
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t "sensors/robot$robot_id/coordX" -m "$coord_x" &
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t "sensors/robot$robot_id/coordY" -m "$coord_y" &
        mosquitto_pub -h $MQTT_HOST -p $MQTT_PORT -t "sensors/robot$robot_id/motorRPM" -m "$motor_rpm" &
        
        # 100개마다 대기 (과부하 방지)
        if [ $((msg_id % 100)) -eq 0 ]; then
            wait
            echo "  Robot $robot_id: $msg_id/$MESSAGES_PER_ROBOT 메시지 발송 완료"
        fi
    done
done

# 모든 백그라운드 작업 완료 대기
wait

# 종료 시간 기록
end_time=$(date +%s%3N)
duration=$((end_time - start_time))
total_messages=$((ROBOT_COUNT * MESSAGES_PER_ROBOT * 3))
messages_per_second=$(echo "scale=2; $total_messages * 1000 / $duration" | bc -l)

echo ""
echo "=== 테스트 결과 ==="
echo "총 처리 시간: ${duration}ms"
echo "총 메시지 수: $total_messages"
echo "초당 메시지 처리량: ${messages_per_second} msg/sec"
echo "평균 메시지 지연시간: $(echo "scale=2; $duration / $total_messages" | bc -l)ms"
echo ""
echo "종료 시간: $(date)"