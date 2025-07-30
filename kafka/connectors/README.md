# Kafka Connect MQTT Connector

이 디렉토리는 Confluent의 MQTT Source Connector를 포함하고 있습니다.

## 설치된 커넥터

- **confluentinc-kafka-connect-mqtt**: MQTT 브로커에서 Kafka로 메시지를 전송하는 소스 커넥터

## 사용법

### 1. 커넥터 등록

```bash
curl -X POST -H "Content-Type: application/json" \
  --data @../../mqtt-source-connector.json \
  http://localhost:8083/connectors
```

### 2. 커넥터 상태 확인

```bash
curl -s http://localhost:8083/connectors/mqtt-source-connector/status | jq .
```

### 3. 커넥터 삭제

```bash
curl -X DELETE http://localhost:8083/connectors/mqtt-source-connector
```

## 설정 옵션

현재 설정된 토픽 패턴:
- `sensors/+/coordX`: X 좌표 데이터
- `sensors/+/coordY`: Y 좌표 데이터
- `sensors/+/motorRPM`: 모터 RPM 데이터
- `test/+`: 테스트 메시지

## 테스트

MQTT 메시지 발행:
```bash
mosquitto_pub -h localhost -t "sensors/robot1/coordX" -m "123.45"
mosquitto_pub -h localhost -t "sensors/robot1/coordY" -m "67.89"
mosquitto_pub -h localhost -t "sensors/robot1/motorRPM" -m "1500"
```

Kafka에서 메시지 확인:
```bash
kafka-console-consumer --bootstrap-server localhost:9092 --topic mqtt-messages --from-beginning
``` 