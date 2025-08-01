#!/usr/bin/env python3
"""
MQTT 테스트 메시지 발행기
"""

import paho.mqtt.client as mqtt
import json
import time
import random
from datetime import datetime

def on_connect(client, userdata, flags, rc):
    print(f"MQTT 연결됨: 결과 코드 {rc}")

def on_publish(client, userdata, mid):
    print(f"메시지 발행됨: {mid}")

def publish_test_messages():
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_publish = on_publish
    
    try:
        # Mosquitto 컨테이너에 연결
        client.connect("localhost", 1883, 60)
        client.loop_start()
        
        # 테스트 메시지들
        test_messages = [
            {
                "topic": "sensors/robot1/coordX",
                "message": f"{random.uniform(50, 150):.2f}"
            },
            {
                "topic": "sensors/robot1/coordY", 
                "message": f"{random.uniform(100, 200):.2f}"
            },
            {
                "topic": "sensors/robot1/motorRPM",
                "message": f"{random.randint(1500, 2000)}"
            },
            {
                "topic": "sensors/robot1/status",
                "message": json.dumps({
                    "status": "active",
                    "battery": random.randint(70, 100),
                    "timestamp": datetime.now().isoformat()
                })
            },
            {
                "topic": "alerts/temperature",
                "message": json.dumps({
                    "type": "warning",
                    "value": random.uniform(75, 85),
                    "threshold": 80,
                    "timestamp": datetime.now().isoformat()
                })
            }
        ]
        
        print("🚀 테스트 메시지 발행 시작...")
        
        for i, msg in enumerate(test_messages, 1):
            result = client.publish(msg["topic"], msg["message"])
            print(f"📤 메시지 {i}: {msg['topic']} = {msg['message']}")
            time.sleep(0.5)  # 0.5초 간격
        
        time.sleep(2)  # 메시지 전송 완료 대기
        print("✅ 모든 테스트 메시지 발행 완료")
        
    except Exception as e:
        print(f"❌ 오류 발생: {e}")
    finally:
        client.loop_stop()
        client.disconnect()

if __name__ == "__main__":
    publish_test_messages()