#!/bin/sh
set -e

echo "🚀 Mosquitto MQTT Broker - Starting initialization..."

# Validate required environment variables
if [ -z "$MQTT_USERNAME" ] || [ -z "$MQTT_PASSWORD" ]; then
    echo "❌ ERROR: MQTT_USERNAME and MQTT_PASSWORD must be set in environment variables"
    echo "Please create .env file with these variables"
    exit 1
fi

# Check for insecure defaults (case-insensitive)
USERNAME_LOWER=$(echo "$MQTT_USERNAME" | tr '[:upper:]' '[:lower:]')
PASSWORD_LOWER=$(echo "$MQTT_PASSWORD" | tr '[:upper:]' '[:lower:]')

if [ "$USERNAME_LOWER" = "mqttuser" ] || [ "$USERNAME_LOWER" = "mqtt" ] || [ "$USERNAME_LOWER" = "admin" ] || [ "$USERNAME_LOWER" = "test" ]; then
    echo "❌ ERROR: Insecure MQTT username detected: $MQTT_USERNAME"
    echo "Please use a unique username in .env file"
    exit 1
fi

if [ "$PASSWORD_LOWER" = "mqttpass" ] || [ "$PASSWORD_LOWER" = "password" ] || [ "$PASSWORD_LOWER" = "admin" ] || [ "$PASSWORD_LOWER" = "test" ] || [ "$PASSWORD_LOWER" = "123456" ]; then
    echo "❌ ERROR: Insecure MQTT password detected"
    echo "Please use a strong password: openssl rand -base64 24"
    exit 1
fi

# Check password length
if [ ${#MQTT_PASSWORD} -lt 12 ]; then
    echo "❌ ERROR: MQTT password too short (${#MQTT_PASSWORD} characters)"
    echo "Password must be at least 12 characters"
    echo "Generate strong password: openssl rand -base64 24"
    exit 1
fi

echo "✅ Environment variables validated"

# Create password file
echo "🔐 Creating Mosquitto password file..."
PASSWORD_FILE="/mosquitto/config/passwd"

# Create password file with mosquitto_passwd utility
# mosquitto_passwd -b creates or updates password file
mosquitto_passwd -c -b "$PASSWORD_FILE" "$MQTT_USERNAME" "$MQTT_PASSWORD"

# Set proper permissions
chmod 0600 "$PASSWORD_FILE"

echo "✅ Password file created successfully for user: $MQTT_USERNAME"
echo "✅ Mosquitto initialization complete"
echo ""
echo "Starting Mosquitto MQTT Broker..."

# Execute the CMD from Dockerfile
exec "$@"
