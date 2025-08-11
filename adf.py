import os
import paho.mqtt.client as mqtt
import time
import random
import json

# 환경변수 설정
HOST = os.getenv("MQTT_HOST", "3.36.126.83")
PORT = int(os.getenv("MQTT_PORT", "3123"))
CLIENT_ID = os.getenv("MQTT_CLIENT_ID", "combined-client")

# ORIN ID 설정 (환경변수 또는 기본값)
ORIN_IDS_STR = os.getenv("ORIN_IDS", "orin123")
ORIN_IDS = [id.strip() for id in ORIN_IDS_STR.split(",")]

# 좌표 전송 간격 (초)
COORD_INTERVAL = float(os.getenv("COORD_INTERVAL", "1"))

# 각 ORIN의 상태를 저장하는 딕셔너리
orin_states = {orin_id: {"following": False} for orin_id in ORIN_IDS}

# MQTT 콜백 함수들
def on_connect(client, userdata, flags, rc, properties=None):
    print(f"✅ Connected to {HOST}:{PORT} (rc={rc})")
    # 각 ORIN ID에 대한 commands 토픽 구독
    for orin_id in ORIN_IDS:
        topic = f"commands/{orin_id}"
        client.subscribe(topic)
        print(f"📥 Subscribed: {topic}")

def on_message(client, userdata, msg):
    try:
        topic = msg.topic
        payload = msg.payload.decode("utf-8", errors="ignore")
        # 토픽에서 orin_id 추출
        orin_id = topic.split("/")[1]
        
        print(f"📥 [{orin_id}] Command received: {payload} (qos={msg.qos}, retain={msg.retain})")

        # 명령어 처리
        if payload == "tracking":
            orin_states[orin_id]["following"] = True
            print(f"🟢 {orin_id} tracking started")
        elif payload == "none":
            orin_states[orin_id]["following"] = False
            print(f"⚪ {orin_id} tracking stopped")
        elif payload == "slam":
            print(f"🗺️ {orin_id} SLAM mode")
        
    except Exception as e:
        print(f"❌ Message processing error: {e}")

# MQTT 클라이언트 설정
client = mqtt.Client(client_id=CLIENT_ID)
client.on_connect = on_connect
client.on_message = on_message

try:
    client.connect(HOST, PORT, 60)
    client.loop_start()  # 백그라운드에서 MQTT 루프 실행
    
    print(f"🚀 MQTT Combined Client Started")
    print(f"📡 Broker: {HOST}:{PORT}")
    print(f"🎯 ORIN IDs: {', '.join(ORIN_IDS)}")
    print(f"⏱️ Coordinate interval: {COORD_INTERVAL}s")
    print("-" * 50)
    
    message_count = 0
    while True:
        # 각 ORIN ID별로 좌표 데이터 생성 및 전송
        for orin_id in ORIN_IDS:
            coord_x = round(random.uniform(0, 1000), 2)
            coord_y = round(random.uniform(0, 1000), 2)
            
            topic_coords = f"sensors/{orin_id}/coordinates"

            # 통합된 JSON 메시지로 전송
            payload = json.dumps({
                "orinId": orin_id,
                "coordX": coord_x,
                "coordY": coord_y,
                "timestamp": int(time.time() * 1000),  # 밀리초 타임스탬프
                "following": orin_states[orin_id]["following"]  # following 상태
            })
            
            client.publish(topic_coords, payload)
            message_count += 1
            
            # following 상태에 따른 표시
            status = "🟢 FOLLOWING" if orin_states[orin_id]["following"] else "⚪ NORMAL"
            print(f"📍 [{message_count:04d}] {orin_id} {status}: X={coord_x:7.2f}, Y={coord_y:7.2f} -> {topic_coords}")
        
        time.sleep(COORD_INTERVAL)

except KeyboardInterrupt:
    print(f"\n🛑 Interrupted by user (Total {message_count} messages sent)")
except Exception as e:
    print(f"❌ Error: {e}")

finally:
    print("🔌 Disconnecting MQTT...")
    client.loop_stop()
    client.disconnect()
    print("✅ Done")