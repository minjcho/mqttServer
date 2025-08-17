#!/bin/bash

# Docker 네트워크 내에서 Python 스크립트 실행

echo "================================================"
echo "Docker 네트워크 내에서 Kafka 테스트 실행"
echo "================================================"

# Python 스크립트를 Docker 컨테이너로 실행
docker run --rm \
    --network mqttserver_mqtt_network \
    -v $(pwd):/app \
    -w /app \
    python:3.9-slim bash -c "
pip install kafka-python pandas numpy
python3 kafka-quick-test.py kafka:9092
"