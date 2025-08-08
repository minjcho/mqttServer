import os
import paho.mqtt.client as mqtt
import uuid

HOST = os.getenv("MQTT_HOST", "3.36.126.83")
PORT = int(os.getenv("MQTT_PORT", "3123"))
TOPIC = os.getenv("MQTT_TOPIC", "commands/orin123")
CLIENT_ID = os.getenv("MQTT_CLIENT_ID", f"subscriber-{uuid.uuid4().hex[:8]}")

def on_connect(client, userdata, flags, rc, properties=None):
    print(f"✅ Connected to {HOST}:{PORT} (rc={rc})")
    if rc == 0:
        result = client.subscribe(TOPIC)
        print(f"📥 Subscribed: {TOPIC} (result={result})")
    else:
        print(f"❌ Connection failed with code {rc}")

def on_message(client, userdata, msg):
    try:
        payload = msg.payload.decode("utf-8", errors="ignore")
    except Exception:
        payload = msg.payload
    print(f"[{msg.topic}] {payload} (qos={msg.qos}, retain={msg.retain})")

def on_subscribe(client, userdata, mid, granted_qos, properties=None):
    print(f"✅ Subscription confirmed (mid={mid}, qos={granted_qos})")

def on_disconnect(client, userdata, rc, properties=None):
    print(f"❌ Disconnected (rc={rc})")

client = mqtt.Client(client_id=CLIENT_ID)
# client.username_pw_set("", "")  # 익명 설정 제거
client.on_connect = on_connect
client.on_message = on_message
client.on_subscribe = on_subscribe
client.on_disconnect = on_disconnect

try:
    print(f"🔌 Connecting to {HOST}:{PORT}...")
    client.connect(HOST, PORT, 60)
    client.loop_forever()
except Exception as e:
    print(f"❌ Connection error: {e}")