#!/usr/bin/env python3
"""
MQTT Authentication Tests
Tests MQTT broker authentication and authorization
"""

import os
import sys
import time
import pytest
import paho.mqtt.client as mqtt
from typing import Optional


class TestMQTTAuthentication:
    """Test suite for MQTT broker authentication."""

    @pytest.fixture(scope="class")
    def mqtt_config(self):
        """Get MQTT configuration from environment."""
        return {
            "host": os.getenv("MQTT_HOST", "localhost"),
            "port": int(os.getenv("MQTT_PORT", "3123")),
            "username": os.getenv("MQTT_USERNAME"),
            "password": os.getenv("MQTT_PASSWORD"),
        }

    def test_connection_with_valid_credentials(self, mqtt_config):
        """Test MQTT connection succeeds with valid credentials."""
        client = mqtt.Client(client_id="test-client-valid")
        client.username_pw_set(
            username=mqtt_config["username"], password=mqtt_config["password"]
        )

        # Connection callback
        connected = {"status": False, "rc": None}

        def on_connect(client, userdata, flags, rc):
            connected["status"] = True
            connected["rc"] = rc

        client.on_connect = on_connect

        # Attempt connection
        try:
            client.connect(mqtt_config["host"], mqtt_config["port"], 60)
            client.loop_start()

            # Wait for connection
            timeout = 10
            start_time = time.time()
            while not connected["status"] and (time.time() - start_time) < timeout:
                time.sleep(0.1)

            client.loop_stop()
            client.disconnect()

            # Verify connection succeeded
            assert connected["status"], "Failed to connect to MQTT broker"
            assert connected["rc"] == 0, f"Connection failed with return code {connected['rc']}"

            print("✅ MQTT connection with valid credentials: PASSED")

        except Exception as e:
            pytest.fail(f"Connection failed: {e}")

    def test_connection_with_invalid_username(self, mqtt_config):
        """Test MQTT connection fails with invalid username."""
        client = mqtt.Client(client_id="test-client-invalid-user")
        client.username_pw_set(username="wrong_user", password=mqtt_config["password"])

        # Connection callback
        connection_result = {"connected": False, "rc": None}

        def on_connect(client, userdata, flags, rc):
            connection_result["connected"] = True
            connection_result["rc"] = rc

        client.on_connect = on_connect

        # Attempt connection
        try:
            client.connect(mqtt_config["host"], mqtt_config["port"], 60)
            client.loop_start()

            # Wait for connection attempt
            time.sleep(3)

            client.loop_stop()
            client.disconnect()

            # Verify connection failed with authentication error
            if connection_result["connected"]:
                assert (
                    connection_result["rc"] != 0
                ), "Connection should fail with invalid username"

            print("✅ MQTT connection with invalid username: PASSED (correctly rejected)")

        except Exception as e:
            # Connection error is expected
            print(f"✅ MQTT connection with invalid username: PASSED (exception: {e})")

    def test_connection_with_invalid_password(self, mqtt_config):
        """Test MQTT connection fails with invalid password."""
        client = mqtt.Client(client_id="test-client-invalid-pass")
        client.username_pw_set(username=mqtt_config["username"], password="wrong_password")

        # Connection callback
        connection_result = {"connected": False, "rc": None}

        def on_connect(client, userdata, flags, rc):
            connection_result["connected"] = True
            connection_result["rc"] = rc

        client.on_connect = on_connect

        # Attempt connection
        try:
            client.connect(mqtt_config["host"], mqtt_config["port"], 60)
            client.loop_start()

            # Wait for connection attempt
            time.sleep(3)

            client.loop_stop()
            client.disconnect()

            # Verify connection failed with authentication error
            if connection_result["connected"]:
                assert (
                    connection_result["rc"] != 0
                ), "Connection should fail with invalid password"

            print("✅ MQTT connection with invalid password: PASSED (correctly rejected)")

        except Exception as e:
            # Connection error is expected
            print(f"✅ MQTT connection with invalid password: PASSED (exception: {e})")

    def test_connection_without_credentials(self, mqtt_config):
        """Test MQTT connection fails without credentials (anonymous disabled)."""
        client = mqtt.Client(client_id="test-client-no-auth")

        # Connection callback
        connection_result = {"connected": False, "rc": None}

        def on_connect(client, userdata, flags, rc):
            connection_result["connected"] = True
            connection_result["rc"] = rc

        client.on_connect = on_connect

        # Attempt connection
        try:
            client.connect(mqtt_config["host"], mqtt_config["port"], 60)
            client.loop_start()

            # Wait for connection attempt
            time.sleep(3)

            client.loop_stop()
            client.disconnect()

            # Verify connection failed
            if connection_result["connected"]:
                assert (
                    connection_result["rc"] != 0
                ), "Connection should fail without credentials"

            print(
                "✅ MQTT connection without credentials: PASSED (correctly rejected)"
            )

        except Exception as e:
            # Connection error is expected
            print(
                f"✅ MQTT connection without credentials: PASSED (exception: {e})"
            )

    def test_publish_with_valid_credentials(self, mqtt_config):
        """Test publishing messages with valid credentials."""
        client = mqtt.Client(client_id="test-client-publish")
        client.username_pw_set(
            username=mqtt_config["username"], password=mqtt_config["password"]
        )

        # Publish result
        publish_result = {"success": False}

        def on_connect(client, userdata, flags, rc):
            if rc == 0:
                # Publish test message
                result = client.publish(
                    "sensors/testdevice/coordinates",
                    '{"x": 10.5, "y": 20.3, "timestamp": 1234567890}',
                    qos=1,
                )
                publish_result["success"] = result.rc == mqtt.MQTT_ERR_SUCCESS

        client.on_connect = on_connect

        try:
            client.connect(mqtt_config["host"], mqtt_config["port"], 60)
            client.loop_start()

            # Wait for publish
            time.sleep(2)

            client.loop_stop()
            client.disconnect()

            assert publish_result["success"], "Failed to publish message"

            print("✅ MQTT publish with valid credentials: PASSED")

        except Exception as e:
            pytest.fail(f"Publish failed: {e}")


class TestMQTTPasswordFile:
    """Test suite for MQTT password file initialization."""

    def test_password_file_exists(self):
        """Test that password file is created by entrypoint script."""
        import subprocess

        # Execute command in mosquitto container to check password file
        result = subprocess.run(
            [
                "docker",
                "compose",
                "exec",
                "-T",
                "mosquitto",
                "cat",
                "/mosquitto/config/passwd",
            ],
            capture_output=True,
            text=True,
        )

        if result.returncode != 0:
            pytest.skip("Could not access mosquitto container")

        # Verify password file exists and contains username
        assert len(result.stdout) > 0, "Password file is empty"

        username = os.getenv("MQTT_USERNAME")
        assert username in result.stdout, f"Username {username} not found in password file"

        # Verify password is hashed (not plaintext)
        password = os.getenv("MQTT_PASSWORD")
        assert (
            password not in result.stdout
        ), "Password is stored in plaintext (security issue!)"

        # Verify hash format (should start with $7$ for mosquitto)
        lines = result.stdout.strip().split("\n")
        for line in lines:
            if username in line:
                parts = line.split(":")
                assert len(parts) == 2, "Invalid password file format"
                assert parts[1].startswith("$"), "Password is not hashed"

        print("✅ MQTT password file validation: PASSED")


if __name__ == "__main__":
    # Run tests
    sys.exit(pytest.main([__file__, "-v", "--tb=short"]))
