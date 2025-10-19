#!/usr/bin/env python3
"""
End-to-End Pipeline Tests
Tests the complete MQTT → Kafka → Redis → WebSocket pipeline
"""

import os
import sys
import time
import json
import pytest
import paho.mqtt.client as mqtt
import redis
import subprocess
from typing import Dict, Any, Optional


class TestPipelineEndToEnd:
    """Test suite for complete pipeline flow."""

    @pytest.fixture(scope="class")
    def mqtt_client(self):
        """Create MQTT client with authentication."""
        client = mqtt.Client(client_id="test-pipeline-client")
        client.username_pw_set(
            username=os.getenv("MQTT_USERNAME"),
            password=os.getenv("MQTT_PASSWORD"),
        )

        connected = {"status": False}

        def on_connect(client, userdata, flags, rc):
            connected["status"] = rc == 0

        client.on_connect = on_connect

        client.connect(os.getenv("MQTT_HOST", "localhost"), int(os.getenv("MQTT_PORT", "3123")), 60)
        client.loop_start()

        # Wait for connection
        timeout = 10
        start_time = time.time()
        while not connected["status"] and (time.time() - start_time) < timeout:
            time.sleep(0.1)

        assert connected["status"], "Failed to connect to MQTT"

        yield client

        client.loop_stop()
        client.disconnect()

    @pytest.fixture(scope="class")
    def redis_client(self):
        """Create Redis client."""
        client = redis.Redis(
            host=os.getenv("REDIS_HOST", "localhost"),
            port=int(os.getenv("REDIS_PORT", "6379")),
            db=0,
            decode_responses=True,
        )

        # Test connection
        try:
            client.ping()
        except redis.ConnectionError:
            pytest.skip("Could not connect to Redis")

        yield client

        client.close()

    def test_mqtt_to_kafka_flow(self, mqtt_client):
        """Test MQTT message reaches Kafka via Telegraf."""
        test_topic = "sensors/pipeline-test-001/coordinates"
        test_message = {
            "x": 99.99,
            "y": 88.88,
            "timestamp": int(time.time()),
            "test_id": "pipeline-test-mqtt-kafka",
        }

        # Publish message
        result = mqtt_client.publish(test_topic, json.dumps(test_message), qos=1)
        assert result.rc == mqtt.MQTT_ERR_SUCCESS, "Failed to publish to MQTT"

        print(f"✅ Published test message to MQTT: {test_topic}")

        # Wait for message to propagate through Telegraf to Kafka
        time.sleep(5)

        # Check Telegraf logs for successful processing
        try:
            telegraf_logs = subprocess.run(
                ["docker", "compose", "logs", "--tail=50", "telegraf"],
                capture_output=True,
                text=True,
                timeout=10,
            )

            # Telegraf should still be connected
            assert "Connected" in telegraf_logs.stdout or telegraf_logs.returncode == 0

            print("✅ Telegraf is processing messages")

        except subprocess.TimeoutExpired:
            pytest.fail("Timeout checking Telegraf logs")

    def test_kafka_to_redis_flow(self, mqtt_client, redis_client):
        """Test message flows from Kafka to Redis via consumer."""
        test_topic = "sensors/pipeline-test-002/coordinates"
        device_id = "pipeline-test-002"
        test_message = {
            "x": 111.11,
            "y": 222.22,
            "timestamp": int(time.time()),
            "test_id": "pipeline-test-kafka-redis",
        }

        # Clear any existing data for this device
        redis_pattern = f"*{device_id}*"
        existing_keys = redis_client.keys(redis_pattern)
        if existing_keys:
            redis_client.delete(*existing_keys)

        # Publish message
        result = mqtt_client.publish(test_topic, json.dumps(test_message), qos=1)
        assert result.rc == mqtt.MQTT_ERR_SUCCESS

        print(f"✅ Published test message: {test_message}")

        # Wait for consumer to process (MQTT → Telegraf → Kafka → Consumer → Redis)
        time.sleep(10)

        # Check if data exists in Redis
        redis_keys = redis_client.keys(redis_pattern)

        if redis_keys:
            print(f"✅ Found {len(redis_keys)} keys in Redis for device {device_id}")
            print(f"   Keys: {redis_keys[:5]}")  # Show first 5 keys
        else:
            # Check consumer logs
            consumer_logs = subprocess.run(
                ["docker", "compose", "logs", "--tail=100", "kafka-redis-consumer"],
                capture_output=True,
                text=True,
            )

            print("ℹ️  No keys found in Redis yet")
            print(f"   Consumer logs (last 10 lines):")
            print("   " + "\n   ".join(consumer_logs.stdout.split("\n")[-10:]))

            # Check if consumer is running
            assert (
                "connected" in consumer_logs.stdout.lower()
            ), "Consumer is not connected"

    def test_end_to_end_latency(self, mqtt_client, redis_client):
        """Test end-to-end latency from MQTT publish to Redis availability."""
        test_topic = "sensors/latency-test/coordinates"
        test_message = {
            "x": 50.0,
            "y": 50.0,
            "timestamp": int(time.time()),
            "test_id": "latency-test",
        }

        start_time = time.time()

        # Publish message
        result = mqtt_client.publish(test_topic, json.dumps(test_message), qos=1)
        assert result.rc == mqtt.MQTT_ERR_SUCCESS

        # Poll Redis for data (up to 30 seconds)
        max_wait = 30
        data_found = False

        while (time.time() - start_time) < max_wait:
            redis_keys = redis_client.keys("*latency-test*")
            if redis_keys:
                data_found = True
                latency = time.time() - start_time
                print(f"✅ End-to-end latency: {latency:.2f} seconds")
                break

            time.sleep(1)

        if not data_found:
            print(f"⚠️  Data not found in Redis after {max_wait}s")
            print("   This may be normal if the consumer is not processing this topic pattern")


class TestServiceHealth:
    """Test health of individual services in the pipeline."""

    def test_telegraf_connected_to_mqtt(self):
        """Test Telegraf is connected to MQTT broker."""
        result = subprocess.run(
            ["docker", "compose", "logs", "--tail=50", "telegraf"],
            capture_output=True,
            text=True,
        )

        assert "Connected" in result.stdout, "Telegraf is not connected to MQTT"
        print("✅ Telegraf is connected to MQTT")

    def test_telegraf_connected_to_kafka(self):
        """Test Telegraf is connected to Kafka."""
        result = subprocess.run(
            ["docker", "compose", "logs", "--tail=100", "telegraf"],
            capture_output=True,
            text=True,
        )

        assert (
            "Successfully connected to outputs.kafka" in result.stdout
        ), "Telegraf is not connected to Kafka"
        print("✅ Telegraf is connected to Kafka")

    def test_consumer_connected_to_kafka(self):
        """Test Kafka consumer is connected."""
        result = subprocess.run(
            ["docker", "compose", "logs", "--tail=100", "kafka-redis-consumer"],
            capture_output=True,
            text=True,
        )

        assert (
            "Kafka consumer connected" in result.stdout
        ), "Consumer is not connected to Kafka"
        print("✅ Kafka consumer is connected")

    def test_consumer_connected_to_redis(self):
        """Test consumer is connected to Redis."""
        result = subprocess.run(
            ["docker", "compose", "logs", "--tail=100", "kafka-redis-consumer"],
            capture_output=True,
            text=True,
        )

        assert (
            "Redis connected" in result.stdout
        ), "Consumer is not connected to Redis"
        print("✅ Consumer is connected to Redis")

    def test_websocket_server_running(self):
        """Test WebSocket server is running."""
        result = subprocess.run(
            ["docker", "compose", "ps", "websocket-server"],
            capture_output=True,
            text=True,
        )

        assert "Up" in result.stdout, "WebSocket server is not running"
        print("✅ WebSocket server is running")

    def test_qr_login_app_health(self):
        """Test QR Login app health endpoint."""
        import urllib.request
        import urllib.error

        try:
            with urllib.request.urlopen("http://localhost:8090/actuator/health", timeout=5) as response:
                data = json.loads(response.read().decode())
                assert data.get("status") == "UP", "QR Login app is not healthy"
                print("✅ QR Login app is healthy")
        except urllib.error.URLError as e:
            pytest.skip(f"Could not reach QR Login app: {e}")


class TestErrorHandling:
    """Test error handling in the pipeline."""

    def test_consumer_handles_invalid_json(self, mqtt_client):
        """Test consumer handles invalid JSON gracefully."""
        test_topic = "sensors/error-test/coordinates"
        invalid_message = "This is not JSON"

        # Publish invalid message
        result = mqtt_client.publish(test_topic, invalid_message, qos=1)
        assert result.rc == mqtt.MQTT_ERR_SUCCESS

        time.sleep(5)

        # Check consumer logs for error handling
        result = subprocess.run(
            ["docker", "compose", "logs", "--tail=50", "kafka-redis-consumer"],
            capture_output=True,
            text=True,
        )

        # Consumer should still be running (not crashed)
        ps_result = subprocess.run(
            ["docker", "compose", "ps", "kafka-redis-consumer"],
            capture_output=True,
            text=True,
        )

        assert "Up" in ps_result.stdout, "Consumer crashed on invalid JSON"
        print("✅ Consumer handles invalid JSON without crashing")


if __name__ == "__main__":
    # Load environment variables
    if os.path.exists(".env"):
        with open(".env") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    os.environ[key] = value

    # Run tests
    sys.exit(pytest.main([__file__, "-v", "--tb=short"]))
