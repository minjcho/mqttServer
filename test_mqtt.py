#!/usr/bin/env python3
import paho.mqtt.client as mqtt
import json
import time

def on_connect(client, userdata, flags, rc):
    print(f"Connected with result code {rc}")

def on_publish(client, userdata, mid):
    print(f"Message published with mid: {mid}")

# MQTT 클라이언트 설정
client = mqtt.Client()
client.on_connect = on_connect
client.on_publish = on_publish

# MQTT 브로커에 연결
client.connect("localhost", 1883, 60)

# 루프 시작
client.loop_start()

# 테스트 메시지 전송
test_data = {
    "timestamp": time.time(),
    "sensor_id": "test_sensor_001",
    "coordX": 123.45,
    "coordY": 678.90,
    "motorRPM": 1500
}

# 다양한 토픽에 메시지 전송
topics = [
    "sensors/001/coordX",
    "sensors/001/coordY", 
    "sensors/001/motorRPM",
    "test/message"
]

for topic in topics:
    result = client.publish(topic, json.dumps(test_data))
    print(f"Published to {topic}: {result}")
    time.sleep(0.1)

time.sleep(2)
client.loop_stop()
client.disconnect()
print("Test completed")
