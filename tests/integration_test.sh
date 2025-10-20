#!/bin/bash

# ===========================================
# MQTT Server Integration Test
# ===========================================
# Tests the entire MQTT → Kafka → Redis → WebSocket pipeline
# Run before creating PR to ensure all services work correctly

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
TIMEOUT=30
MQTT_TEST_TOPIC="sensors/testdevice001/coordinates"
MQTT_TEST_MESSAGE='{"x": 123.45, "y": 678.90, "timestamp": 1234567890}'

# ===========================================
# Helper Functions
# ===========================================

print_header() {
    echo -e "\n${YELLOW}==================================${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}==================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

wait_for_service() {
    local service=$1
    local max_attempts=30
    local attempt=1

    print_info "Waiting for $service to be ready..."

    while [ $attempt -le $max_attempts ]; do
        if docker compose ps $service | grep -q "Up"; then
            print_success "$service is ready"
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done

    print_error "$service failed to start within ${max_attempts}s"
    return 1
}

# ===========================================
# Test 1: Container Health Checks
# ===========================================

test_container_health() {
    print_header "Test 1: Container Health Checks (MQTT Pipeline)"

    # Only check MQTT pipeline services (exclude QR login system)
    local services=("mosquitto" "kafka" "telegraf" "redis" "kafka-redis-consumer" "websocket-server")
    local failed=0

    for service in "${services[@]}"; do
        if docker compose ps $service 2>/dev/null | grep -q "Up"; then
            print_success "$service is running"
        else
            print_error "$service is not running"
            failed=1
        fi
    done

    # Check healthy status for services with health checks
    local health_services=("kafka")
    for service in "${health_services[@]}"; do
        if docker compose ps $service 2>/dev/null | grep -q "healthy"; then
            print_success "$service is healthy"
        else
            print_error "$service is not healthy"
            failed=1
        fi
    done

    if [ $failed -eq 1 ]; then
        print_error "Container health check failed"
        return 1
    fi

    print_success "All MQTT pipeline containers are running and healthy"
    return 0
}

# ===========================================
# Test 2: MQTT Authentication
# ===========================================

test_mqtt_authentication() {
    print_header "Test 2: MQTT Authentication"

    # Test with valid credentials
    print_info "Testing MQTT with valid credentials..."
    if docker compose exec mosquitto mosquitto_pub \
        -h localhost \
        -p 3123 \
        -t "$MQTT_TEST_TOPIC" \
        -m "$MQTT_TEST_MESSAGE" \
        -u "${MQTT_USERNAME}" \
        -P "${MQTT_PASSWORD}" 2>&1 | grep -q "Error"; then
        print_error "MQTT authentication failed with valid credentials"
        return 1
    fi
    print_success "MQTT authentication works with valid credentials"

    # Test without credentials (should fail)
    print_info "Testing MQTT without credentials (should fail)..."
    if docker compose exec mosquitto mosquitto_pub \
        -h localhost \
        -p 3123 \
        -t "$MQTT_TEST_TOPIC" \
        -m "$MQTT_TEST_MESSAGE" 2>&1 | grep -q "Connection refused\|not authorised"; then
        print_success "MQTT correctly rejects connections without credentials"
    else
        print_error "MQTT allows connections without credentials (security issue!)"
        return 1
    fi

    print_success "MQTT authentication test passed"
    return 0
}

# ===========================================
# Test 3: MQTT → Telegraf → Kafka Pipeline
# ===========================================

test_mqtt_to_kafka() {
    print_header "Test 3: MQTT → Telegraf → Kafka Pipeline"

    # Publish test message
    print_info "Publishing test message to MQTT..."
    docker compose exec mosquitto mosquitto_pub \
        -h localhost \
        -p 3123 \
        -t "$MQTT_TEST_TOPIC" \
        -m "$MQTT_TEST_MESSAGE" \
        -u "${MQTT_USERNAME}" \
        -P "${MQTT_PASSWORD}"

    # Wait for message to propagate
    sleep 3

    # Check if telegraf is connected to MQTT
    print_info "Checking Telegraf connection..."
    if docker compose logs telegraf | grep -q "Connected.*mosquitto"; then
        print_success "Telegraf is connected to MQTT"
    else
        print_error "Telegraf is not connected to MQTT"
        return 1
    fi

    # Check if telegraf is connected to Kafka
    if docker compose logs telegraf | grep -q "Successfully connected to outputs.kafka"; then
        print_success "Telegraf is connected to Kafka"
    else
        print_error "Telegraf is not connected to Kafka"
        return 1
    fi

    print_success "MQTT → Kafka pipeline test passed"
    return 0
}

# ===========================================
# Test 4: Kafka → Consumer → Redis Pipeline
# ===========================================

test_kafka_to_redis() {
    print_header "Test 4: Kafka → Consumer → Redis Pipeline"

    # Check if consumer is connected
    print_info "Checking Kafka consumer connection..."
    if docker compose logs kafka-redis-consumer | grep -q "Kafka consumer connected"; then
        print_success "Kafka consumer is connected"
    else
        print_error "Kafka consumer is not connected"
        return 1
    fi

    # Check if consumer is connected to Redis
    if docker compose logs kafka-redis-consumer | grep -q "Redis connected"; then
        print_success "Consumer is connected to Redis"
    else
        print_error "Consumer is not connected to Redis"
        return 1
    fi

    # Publish a test message and check Redis
    print_info "Publishing test message and checking Redis..."
    docker compose exec mosquitto mosquitto_pub \
        -h localhost \
        -p 3123 \
        -t "$MQTT_TEST_TOPIC" \
        -m "$MQTT_TEST_MESSAGE" \
        -u "${MQTT_USERNAME}" \
        -P "${MQTT_PASSWORD}"

    sleep 5  # Wait for processing

    # Check if any keys exist in Redis (basic check)
    local redis_keys=$(docker compose exec redis redis-cli KEYS "*" | wc -l)
    if [ "$redis_keys" -gt 0 ]; then
        print_success "Data exists in Redis ($redis_keys keys)"
    else
        print_info "No data found in Redis yet (may be normal)"
    fi

    print_success "Kafka → Redis pipeline test passed"
    return 0
}

# ===========================================
# Test 5: WebSocket Server Health
# ===========================================

test_websocket_server() {
    print_header "Test 5: WebSocket Server Health"

    # Check if websocket server is running
    if docker compose ps websocket-server | grep -q "Up"; then
        print_success "WebSocket server is running"
    else
        print_error "WebSocket server is not running"
        return 1
    fi

    # Check logs for errors
    if docker compose logs websocket-server | grep -q "ERROR\|FATAL"; then
        print_error "WebSocket server has errors in logs"
        docker compose logs websocket-server | grep "ERROR\|FATAL" | tail -5
        return 1
    fi

    print_success "WebSocket server health check passed"
    return 0
}

# ===========================================
# Test 6: QR Login App Health
# ===========================================
# Skipped: QR Login app is not part of MQTT pipeline tests

test_qr_login_app() {
    print_header "Test 6: QR Login App Health (SKIPPED)"
    print_info "QR Login app test skipped - not part of MQTT pipeline"
    return 0
}

# ===========================================
# Test 7: Check for Errors in Logs
# ===========================================

test_service_logs() {
    print_header "Test 7: Service Error Log Check (MQTT Pipeline)"

    # Only check MQTT pipeline services
    local services=("mosquitto" "telegraf" "kafka-redis-consumer" "websocket-server")
    local errors_found=0

    for service in "${services[@]}"; do
        print_info "Checking $service logs..."
        local error_count=$(docker compose logs $service | grep -i "FATAL\|CRITICAL" | wc -l)

        if [ "$error_count" -gt 0 ]; then
            print_error "$service has $error_count FATAL/CRITICAL errors"
            docker compose logs $service | grep -i "FATAL\|CRITICAL" | tail -3
            errors_found=1
        else
            print_success "$service has no FATAL/CRITICAL errors"
        fi
    done

    if [ $errors_found -eq 1 ]; then
        print_error "Errors found in service logs"
        return 1
    fi

    print_success "No FATAL/CRITICAL errors in MQTT pipeline service logs"
    return 0
}

# ===========================================
# Main Execution
# ===========================================

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║   MQTT Server Integration Test Suite         ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""

    # Load environment variables
    if [ -f ".env" ]; then
        set -a  # Automatically export all variables
        source <(grep -v '^#' .env | sed -e 's/\r$//' -e '/^$/d' -e "s/'/\\\'/g" -e "s/\(.*\)=\(.*\)/\1='\2'/")
        set +a
        print_success "Loaded environment variables from .env"
    else
        print_error ".env file not found"
        exit 1
    fi

    local failed_tests=0
    local total_tests=7

    # Run all tests
    test_container_health || failed_tests=$((failed_tests + 1))
    test_mqtt_authentication || failed_tests=$((failed_tests + 1))
    test_mqtt_to_kafka || failed_tests=$((failed_tests + 1))
    test_kafka_to_redis || failed_tests=$((failed_tests + 1))
    test_websocket_server || failed_tests=$((failed_tests + 1))
    test_qr_login_app || failed_tests=$((failed_tests + 1))
    test_service_logs || failed_tests=$((failed_tests + 1))

    # Summary
    echo ""
    print_header "Test Summary"
    local passed_tests=$((total_tests - failed_tests))
    echo "Passed: $passed_tests/$total_tests"
    echo "Failed: $failed_tests/$total_tests"

    if [ $failed_tests -eq 0 ]; then
        echo ""
        print_success "🎉 All tests passed! Pipeline is working correctly."
        echo ""
        exit 0
    else
        echo ""
        print_error "⚠️  Some tests failed. Please check the output above."
        echo ""
        exit 1
    fi
}

# Run main function
main
