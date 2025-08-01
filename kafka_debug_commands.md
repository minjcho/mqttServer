# 카프카 데이터 확인 명령어 모음

## 🔍 기본 확인 명령어들

### 토픽 관련
```bash
# 토픽 목록
docker compose exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# 토픽 상세 정보 (메시지 수, 파티션 등)
docker compose exec kafka kafka-topics --bootstrap-server localhost:9092 --describe --topic mqtt-messages

# 새 토픽 생성
docker compose exec kafka kafka-topics --bootstrap-server localhost:9092 --create --topic test-topic --partitions 1 --replication-factor 1
```

### 메시지 소비
```bash
# 처음부터 모든 메시지 (최대 10개)
docker compose exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic mqtt-messages --from-beginning --max-messages 10

# 실시간 새 메시지만
docker compose exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic mqtt-messages

# 타임아웃 설정 (5초 후 종료)
docker compose exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic mqtt-messages --from-beginning --timeout-ms 5000

# JSON 형태로 상세 정보 출력
docker compose exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic mqtt-messages --from-beginning --property print.timestamp=true --property print.partition=true --property print.offset=true
```

### 컨슈머 그룹 관리
```bash
# 컨슈머 그룹 목록
docker compose exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --list

# 특정 그룹 상세 정보
docker compose exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group [그룹명]

# 오프셋 리셋 (처음부터 다시 읽기)
docker compose exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --group [그룹명] --reset-offsets --to-earliest --topic mqtt-messages --execute
```

## 📊 Redis 데이터 확인

### 기본 명령어
```bash
# 모든 키 목록
docker compose exec redis redis-cli KEYS "*"

# 특정 패턴 키 검색
docker compose exec redis redis-cli KEYS "message:*"
docker compose exec redis redis-cli KEYS "latest:*"

# 키 개수
docker compose exec redis redis-cli DBSIZE

# 메모리 사용량
docker compose exec redis redis-cli INFO memory
```

### 데이터 조회
```bash
# 단순 문자열 값
docker compose exec redis redis-cli GET message_count

# 해시 데이터 전체
docker compose exec redis redis-cli HGETALL "latest:mqtt-messages"

# 해시 특정 필드
docker compose exec redis redis-cli HGET "latest:mqtt-messages" message

# 리스트 데이터 (최근 10개)
docker compose exec redis redis-cli LRANGE "timeseries:mqtt-messages" 0 9

# 집합 데이터
docker compose exec redis redis-cli SMEMBERS "active_alerts"
```

## 🧪 테스트 및 디버깅

### MQTT 메시지 전송
```bash
# 단일 메시지
docker compose exec mosquitto mosquitto_pub -h localhost -t "sensors/test" -m "hello world"

# JSON 메시지
docker compose exec mosquitto mosquitto_pub -h localhost -t "sensors/data" -m '{"temperature": 25.5, "humidity": 60}'

# 여러 메시지 연속 전송
for i in {1..5}; do
  docker compose exec mosquitto mosquitto_pub -h localhost -t "sensors/counter" -m "$i"
  sleep 1
done
```

### MQTT 구독 테스트
```bash
# 모든 메시지 구독
docker compose exec mosquitto mosquitto_sub -h localhost -t "#"

# 특정 토픽 구독
docker compose exec mosquitto mosquitto_sub -h localhost -t "sensors/+"

# 패턴 구독
docker compose exec mosquitto mosquitto_sub -h localhost -t "sensors/robot1/+"
```

## 📈 모니터링 및 감시

### 실시간 로그 감시
```bash
# 전체 시스템 로그
docker compose logs -f

# 특정 서비스 로그
docker compose logs -f mqtt-bridge
docker compose logs -f kafka-redis-consumer
docker compose logs -f kafka

# 로그 필터링
docker compose logs -f kafka-redis-consumer | grep "MESSAGE RECEIVED"
docker compose logs -f mqtt-bridge | grep "Published"
```

### 성능 모니터링
```bash
# Redis 메모리 사용량 감시
watch "docker compose exec redis redis-cli INFO memory | grep used_memory_human"

# 메시지 카운트 감시
watch "docker compose exec redis redis-cli GET message_count"

# Kafka 토픽 상태 감시
watch "docker compose exec kafka kafka-topics --bootstrap-server localhost:9092 --describe --topic mqtt-messages"
```

## 🔧 문제 해결

### 서비스 재시작
```bash
# 전체 재시작
docker compose restart

# 특정 서비스만 재시작
docker compose restart kafka-redis-consumer
docker compose restart mqtt-bridge

# 컨테이너 재빌드
docker compose build kafka-redis-consumer
docker compose up -d kafka-redis-consumer
```

### 데이터 초기화
```bash
# Redis 데이터 초기화
docker compose exec redis redis-cli FLUSHALL

# Kafka 데이터 초기화 (컨테이너 재생성)
docker compose down
docker volume rm mqttserver_kafka_data
docker compose up -d
```

### 네트워크 연결 확인
```bash
# 컨테이너 간 네트워크 확인
docker compose exec mqtt-bridge ping kafka
docker compose exec kafka-redis-consumer ping redis
docker compose exec mqtt-bridge ping mosquitto

# 포트 연결 확인
docker compose exec mqtt-bridge nc -zv kafka 9092
docker compose exec kafka-redis-consumer nc -zv redis 6379
```

## 🎯 실용적인 사용 예시

### 전체 데이터 플로우 테스트
```bash
# 1. 메시지 전송
docker compose exec mosquitto mosquitto_pub -h localhost -t "sensors/robot1/coordX" -m "123.45"

# 2. 로그에서 처리 과정 확인
docker compose logs mqtt-bridge --tail=5
docker compose logs kafka-redis-consumer --tail=5

# 3. Redis에서 결과 확인
docker compose exec redis redis-cli HGETALL "latest:coordX"
docker compose exec redis redis-cli GET message_count
```

### 대량 데이터 테스트
```bash
# 100개 메시지 전송
for i in {1..100}; do
  docker compose exec mosquitto mosquitto_pub -h localhost -t "test/bulk" -m "message_$i"
done

# 처리 결과 확인
docker compose exec redis redis-cli GET message_count
docker compose exec kafka kafka-run-class kafka.tools.GetOffsetShell --broker-list localhost:9092 --topic mqtt-messages
```