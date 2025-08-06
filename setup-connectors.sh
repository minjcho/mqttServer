#!/bin/bash

echo "Waiting for Kafka Connect to be ready..."
until curl -s http://localhost:8083/connectors; do
  echo "Waiting for Kafka Connect..."
  sleep 5
done

echo "Creating Redis Sink Connector..."
curl -X POST \
  http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d '{
    "name": "redis-sink-connector",
    "config": {
      "connector.class": "com.github.jcustenborder.kafka.connect.redis.RedisSinkConnector",
      "tasks.max": "1",
      "topics": "mqtt-messages",
      "redis.hosts": "redis:6379",
      "redis.database": "0",
      "key.converter": "org.apache.kafka.connect.storage.StringConverter",
      "value.converter": "org.apache.kafka.connect.storage.StringConverter",
      "redis.key": "message:${topic}:${partition}:${offset}",
      "redis.value": "${value}"
    }
  }'

echo ""
echo "Checking connector status..."
curl -s http://localhost:8083/connectors/redis-sink-connector/status | jq

echo ""
echo "Redis Sink Connector created successfully!"