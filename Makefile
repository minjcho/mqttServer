.PHONY: help build up down logs clean mqtt-bridge-logs kafka-logs redis-logs redis-api-logs kafka-redis-consumer-logs websocket-logs
.PHONY: init-topics list-topics test-mqtt consume-messages setup
.PHONY: redis redis-cli redis-api-test test-redis-pipeline
.PHONY: websocket websocket-test test-websocket-pipeline

help:
	@echo "Available commands:"
	@echo "  build              - 모든 서비스 빌드"
	@echo "  up                 - 모든 서비스 시작"
	@echo "  down               - 모든 서비스 중지"
	@echo "  logs               - 모든 서비스 로그 확인"
	@echo "  clean              - 모든 컨테이너, 이미지, 볼륨 제거"
	@echo ""
	@echo "  mqtt-bridge-logs   - MQTT 브릿지 로그 확인"
	@echo "  kafka-logs         - Kafka 로그 확인"
	@echo "  redis-logs         - Redis 로그 확인"
	@echo "  redis-api-logs     - Redis API 로그 확인"
	@echo "  kafka-redis-consumer-logs - Kafka-Redis 컨슈머 로그 확인"
	@echo "  websocket-logs     - WebSocket 서버 로그 확인"
	@echo ""
	@echo "  redis              - Redis 서비스 시작"
	@echo "  redis-cli          - Redis CLI 접속"
	@echo "  redis-api-test     - Redis API 테스트"
	@echo ""
	@echo "  websocket          - WebSocket 서버 시작"
	@echo "  websocket-test     - WebSocket API 테스트"
	@echo ""
	@echo "  init-topics        - Kafka 토픽 초기화"
	@echo "  list-topics        - Kafka 토픽 목록 확인"
	@echo "  test-mqtt          - MQTT 테스트 메시지 발행"
	@echo "  consume-messages   - Kafka 메시지 소비"
	@echo ""
	@echo "  test-redis-pipeline - 전체 MQTT → Kafka → Redis 파이프라인 테스트"
	@echo "  test-websocket-pipeline - 전체 MQTT → Kafka → Redis → WebSocket 파이프라인 테스트"
	@echo "  setup              - 전체 시스템 설정 및 시작"

# 기본 Docker Compose 명령어들
build:
	docker compose build

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f

clean:
	docker compose down -v --rmi all --remove-orphans
	docker system prune -af

# 개별 서비스 로그 확인
mqtt-bridge-logs:
	docker compose logs -f mqtt-bridge

kafka-logs:
	docker compose logs -f kafka

redis-logs:
	docker compose logs -f redis

redis-api-logs:
	docker compose logs -f redis-api

kafka-redis-consumer-logs:
	docker compose logs -f kafka-redis-consumer

websocket-logs:
	docker compose logs -f websocket-server

# Redis 관련 명령어들
redis:
	docker compose up -d redis

redis-cli:
	docker compose exec redis redis-cli

redis-api-test:
	@echo "Testing Redis API endpoints..."
	@echo "1. Health check:"
	curl -s http://localhost:8000/health | jq .
	@echo ""
	@echo "2. All topics:"
	curl -s http://localhost:8000/topics | jq .
	@echo ""
	@echo "3. All latest data:"
	curl -s http://localhost:8000/all-latest | jq .

# WebSocket 관련 명령어들
websocket:
	docker compose up -d websocket-server

websocket-test:
	@echo "Testing WebSocket API endpoints..."
	@echo "1. Health check:"
	curl -s http://localhost:8080/api/health | jq .
	@echo ""
	@echo "2. Stats:"
	curl -s http://localhost:8080/api/stats | jq .
	@echo ""
	@echo "3. WebSocket UI: http://localhost:8080"

# Kafka 관련 명령어들
init-topics:
	docker compose run --rm kafka-topics-init

list-topics:
	docker compose exec kafka kafka-topics --bootstrap-server localhost:9092 --list

test-mqtt:
	@echo "Publishing test MQTT messages..."
	docker compose exec mosquitto mosquitto_pub -h localhost -t "sensors/robot1/coordX" -m "100.5"
	docker compose exec mosquitto mosquitto_pub -h localhost -t "sensors/robot1/coordY" -m "200.7"
	docker compose exec mosquitto mosquitto_pub -h localhost -t "sensors/robot1/motorRPM" -m "1800"
	@echo "Test messages published!"

consume-messages:
	docker compose exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic mqtt-messages --from-beginning --max-messages 10

# 전체 파이프라인 테스트
test-redis-pipeline:
	@echo "=== Testing complete MQTT → Kafka → Redis pipeline ==="
	@echo ""
	@echo "1. Publishing MQTT messages..."
	docker compose exec mosquitto mosquitto_pub -h localhost -t "sensors/robot1/coordX" -m "150.5"
	docker compose exec mosquitto mosquitto_pub -h localhost -t "sensors/robot1/coordY" -m "250.7"
	@echo ""
	@echo "2. Waiting for processing..."
	sleep 3
	@echo ""
	@echo "3. Checking Redis data via API:"
	curl -s http://localhost:8000/all-latest | jq . || echo "Data not yet available"
	@echo ""
	@echo "4. Checking Redis directly:"
	docker compose exec redis redis-cli KEYS "*" || echo "No data in Redis"

test-websocket-pipeline:
	@echo "=== Testing complete MQTT → Kafka → Redis → WebSocket pipeline ==="
	@echo ""
	@echo "1. Publishing MQTT messages..."
	docker compose exec mosquitto mosquitto_pub -h localhost -t "sensors/robot1/coordX" -m "300.5"
	docker compose exec mosquitto mosquitto_pub -h localhost -t "sensors/robot1/coordY" -m "400.7"
	@echo ""
	@echo "2. Waiting for processing..."
	sleep 5
	@echo ""
	@echo "3. Checking WebSocket API:"
	curl -s http://localhost:8080/api/stats | jq . || echo "Data not yet available"
	@echo ""
	@echo "4. Open WebSocket client: http://localhost:8080"

# 전체 시스템 설정
setup:
	@echo "=== Setting up complete IoT server system with WebSocket ==="
	@echo "Building all services..."
	docker compose build
	@echo ""
	@echo "Starting all services..."
	docker compose up -d
	@echo ""
	@echo "Waiting for services to be ready..."
	sleep 15
	@echo ""
	@echo "Initializing Kafka topics..."
	docker compose run --rm kafka-topics-init
	@echo ""
	@echo "=== System ready! ==="
	@echo ""
	@echo "Available services:"
	@echo "  - MQTT Broker:     localhost:3123"
	@echo "  - Kafka:          localhost:9092"
	@echo "  - Redis:          localhost:6379"
	@echo "  - Redis API:      http://localhost:8000"
	@echo "  - WebSocket Server: http://localhost:8080"
	@echo "  - WebSocket UI:    http://localhost:8080"
	@echo ""
	@echo "Test the complete pipeline with: make test-websocket-pipeline"
