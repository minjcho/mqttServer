# Integration Tests

This directory contains integration tests for the MQTT Server pipeline.

## 🎯 Purpose

Test the complete MQTT → Kafka → Redis → WebSocket pipeline before creating pull requests.

## 📁 Files

- **`integration_test.sh`** - Main integration test script (Bash)
- **`test_mqtt_auth.py`** - MQTT authentication tests (pytest)
- **`test_pipeline.py`** - End-to-end pipeline tests (pytest)
- **`requirements-test.txt`** - Python test dependencies

## 🚀 Running Tests Locally

### Prerequisites

```bash
# Install Python test dependencies
pip install -r tests/requirements-test.txt

# Ensure services are running
docker compose up -d

# Wait for services to be ready (~30-60 seconds)
```

### Run All Tests

```bash
# Option 1: Bash integration test (comprehensive)
./tests/integration_test.sh

# Option 2: Python tests only
pytest tests/ -v

# Option 3: Specific test file
pytest tests/test_mqtt_auth.py -v
pytest tests/test_pipeline.py -v
```

### Run with Test Environment

```bash
# Use test configuration
cp .env.test .env
docker compose up -d
./tests/integration_test.sh
```

## 📊 Test Coverage

### 1. Container Health Checks (`integration_test.sh`)
- ✅ All services running
- ✅ Health checks passing
- ✅ No FATAL errors in logs

### 2. MQTT Authentication (`test_mqtt_auth.py`)
- ✅ Connection with valid credentials succeeds
- ✅ Connection with invalid credentials fails
- ✅ Connection without credentials fails (anonymous disabled)
- ✅ Password file properly initialized
- ✅ Passwords are hashed (not plaintext)

### 3. Pipeline Flow (`test_pipeline.py`)
- ✅ MQTT → Telegraf → Kafka
- ✅ Kafka → Consumer → Redis
- ✅ End-to-end latency measurement
- ✅ Error handling (invalid JSON)

### 4. Service Health (`test_pipeline.py`)
- ✅ Telegraf connected to MQTT
- ✅ Telegraf connected to Kafka
- ✅ Consumer connected to Kafka
- ✅ Consumer connected to Redis
- ✅ WebSocket server running
- ✅ QR Login app health check

## 🔄 CI/CD Integration

Tests run automatically on:
- Pull requests to `main`, `master`, `develop`
- Pushes to `main`, `master`, `develop`
- Manual workflow dispatch

See `.github/workflows/integration-test.yml` for details.

## 📝 Test Results

### Successful Test Output
```
╔═══════════════════════════════════════════════╗
║   MQTT Server Integration Test Suite         ║
╚═══════════════════════════════════════════════╝

✅ Loaded environment variables from .env

==================================
Test 1: Container Health Checks
==================================
✅ mosquitto is running
✅ kafka is running
✅ telegraf is running
✅ redis is running
✅ All containers are running and healthy

==================================
Test 2: MQTT Authentication
==================================
✅ MQTT authentication works with valid credentials
✅ MQTT correctly rejects connections without credentials

... (more tests)

==================================
Test Summary
==================================
Passed: 7/7
Failed: 0/7

🎉 All tests passed! Pipeline is working correctly.
```

## 🐛 Troubleshooting

### Test Failures

1. **MQTT Authentication Fails**
   - Check `.env` has correct `MQTT_USERNAME` and `MQTT_PASSWORD`
   - Verify mosquitto container is running: `docker compose ps mosquitto`
   - Check mosquitto logs: `docker compose logs mosquitto`

2. **Services Not Ready**
   - Increase wait time: `sleep 60` before running tests
   - Check service logs: `docker compose logs <service-name>`
   - Verify `.env` file exists and is loaded

3. **Python Tests Fail**
   - Install dependencies: `pip install -r tests/requirements-test.txt`
   - Check Python version: `python --version` (requires 3.7+)
   - Verify Docker is running: `docker compose ps`

### Common Issues

**"MQTT not authorized"**
- Regenerate credentials in `.env`
- Rebuild mosquitto: `docker compose build mosquitto`
- Remove volumes: `docker compose down -v`

**"Kafka not available"**
- Kafka takes 30-60 seconds to start
- Check health: `docker compose exec kafka kafka-topics --bootstrap-server localhost:9092 --list`

**"Redis connection refused"**
- Check Redis is running: `docker compose exec redis redis-cli ping`
- Verify port 6379 is not in use: `lsof -i :6379`

## 📚 Adding New Tests

### Bash Test (integration_test.sh)

```bash
test_new_feature() {
    print_header "Test X: New Feature"

    # Your test logic here
    if [ condition ]; then
        print_success "Feature works"
        return 0
    else
        print_error "Feature failed"
        return 1
    fi
}

# Add to main()
test_new_feature || failed_tests=$((failed_tests + 1))
```

### Python Test

```python
# tests/test_new_feature.py
import pytest

class TestNewFeature:
    def test_feature_works(self):
        """Test new feature works correctly."""
        result = do_something()
        assert result == expected
        print("✅ New feature test passed")

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
```

## 🔗 Related Issues

- #42: Add test coverage for authentication and security features
- #10: Achieve 60%+ unit test coverage

## 📞 Support

For issues with tests:
1. Check logs: `docker compose logs`
2. Review test output carefully
3. Open an issue with:
   - Test command run
   - Full error output
   - `docker compose ps` output
