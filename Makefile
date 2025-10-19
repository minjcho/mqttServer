.PHONY: help build up down logs clean mqtt-bridge-logs kafka-logs redis-logs redis-api-logs kafka-redis-consumer-logs websocket-logs
.PHONY: init-topics list-topics test-mqtt consume-messages setup
.PHONY: redis redis-cli redis-api-test test-redis-pipeline
.PHONY: websocket websocket-test test-websocket-pipeline all fclean re
.PHONY: test test-integration test-python test-mqtt-auth test-pipeline-e2e test-all test-setup test-env test-clean test-ci

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
	@echo ""
	@echo "Testing commands:"
	@echo "  test               - 통합 테스트 실행 (기본)"
	@echo "  test-all           - 모든 테스트 실행 (Bash + Python)"
	@echo "  test-integration   - Bash 통합 테스트 실행"
	@echo "  test-python        - Python 테스트 실행"
	@echo "  test-mqtt-auth     - MQTT 인증 테스트만"
	@echo "  test-pipeline-e2e  - 파이프라인 E2E 테스트만"
	@echo "  test-setup         - 테스트 의존성 설치"
	@echo "  test-env           - 테스트 환경 설정"
	@echo "  test-clean         - 테스트 환경 정리"
	@echo "  test-ci            - CI/CD 시뮬레이션"

# 기본 Docker Compose 명령어들
all: build up

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

fclean: down clean

re: fclean all

# 개별 서비스 로그 확인
mqtt-bridge-logs:
	docker compose logs -f mqtt-bridge

kafka-logs:
	docker compose logs -f kafka

redis-logs:
	docker compose logs -f redis

redis-api-logs:
	docker compose logs -f redis-api

kafka-connect-logs:
	docker compose logs -f kafka-connect

connector-status:
	curl -s http://localhost:8083/connectors/redis-sink-connector/status | jq

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
	curl -s http://localhost:8081/api/health | jq .
	@echo ""
	@echo "2. Stats:"
	curl -s http://localhost:8081/api/stats | jq .
	@echo ""
	@echo "3. WebSocket UI: http://localhost:8081"

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
	curl -s http://localhost:8081/api/stats | jq . || echo "Data not yet available"
	@echo ""
	@echo "4. Open WebSocket client: http://localhost:8081"

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
	@echo "  - WebSocket Server: http://localhost:8081"
	@echo "  - WebSocket UI:    http://localhost:8081"
	@echo ""
	@echo "Test the complete pipeline with: make test-websocket-pipeline"

# ===========================================
# 통합 테스트 명령어들
# ===========================================

# 기본 테스트 (빠른 통합 테스트)
test: test-integration
	@echo ""
	@echo "✅ Integration test completed"
	@echo "Run 'make test-all' for full test suite"

# Bash 통합 테스트
test-integration:
	@echo "=== Running Bash Integration Tests ==="
	@chmod +x tests/integration_test.sh
	./tests/integration_test.sh

# Python 테스트
test-python:
	@echo "=== Running Python Tests ==="
	@command -v pytest >/dev/null 2>&1 || { echo "pytest not found. Run 'make test-setup' first"; exit 1; }
	pytest tests/ -v --tb=short

# MQTT 인증 테스트만
test-mqtt-auth:
	@echo "=== Running MQTT Authentication Tests ==="
	@command -v pytest >/dev/null 2>&1 || { echo "pytest not found. Run 'make test-setup' first"; exit 1; }
	pytest tests/test_mqtt_auth.py -v

# 파이프라인 E2E 테스트만
test-pipeline-e2e:
	@echo "=== Running Pipeline E2E Tests ==="
	@command -v pytest >/dev/null 2>&1 || { echo "pytest not found. Run 'make test-setup' first"; exit 1; }
	pytest tests/test_pipeline.py -v

# 모든 테스트 (Bash + Python)
test-all: test-integration test-python
	@echo ""
	@echo "✅ All tests completed successfully!"

# 테스트 의존성 설치
test-setup:
	@echo "=== Installing Test Dependencies ==="
	@command -v pip3 >/dev/null 2>&1 || { echo "pip3 not found. Please install Python 3"; exit 1; }
	pip3 install -r tests/requirements-test.txt
	@echo "✅ Test dependencies installed"

# 테스트 환경 설정
test-env:
	@echo "=== Setting Up Test Environment ==="
	@if [ ! -f .env.test ]; then echo "❌ .env.test not found"; exit 1; fi
	cp .env.test .env
	@echo "✅ Using test environment configuration"
	docker compose down -v
	docker compose up -d
	@echo "⏳ Waiting for services to be ready..."
	@sleep 30
	@echo "✅ Test environment ready"

# 테스트 환경 정리
test-clean:
	@echo "=== Cleaning Up Test Environment ==="
	docker compose down -v
	@echo "✅ Test environment cleaned"

# CI/CD 시뮬레이션
test-ci:
	@echo "=== Running CI/CD Simulation ==="
	@echo "1. Setting up test environment..."
	@$(MAKE) test-env
	@echo ""
	@echo "2. Running all tests..."
	@sleep 10
	@$(MAKE) test-all
	@echo ""
	@echo "3. Cleaning up..."
	@$(MAKE) test-clean
	@echo ""
	@echo "✅ CI/CD simulation completed"
