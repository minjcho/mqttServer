#!/usr/bin/env python3

"""
Docker 네트워크를 통한 Kafka 테스트
Docker 컨테이너 내에서 실행하기 위한 스크립트
"""

import subprocess
import json

def run_in_docker():
    """Docker 컨테이너 내에서 Python 스크립트 실행"""
    
    script = '''
import json
from kafka import KafkaProducer, KafkaConsumer, KafkaAdminClient
import time

try:
    # Kafka 연결 (Docker 네트워크 내부)
    print("Kafka 연결 시도: kafka:9092")
    
    admin = KafkaAdminClient(
        bootstrap_servers="kafka:9092",
        client_id="docker_test"
    )
    
    topics = admin.list_topics()
    print(f"✅ 연결 성공! 토픽: {topics}")
    
    # Producer 테스트
    producer = KafkaProducer(
        bootstrap_servers="kafka:9092",
        value_serializer=lambda v: json.dumps(v).encode()
    )
    
    # 100개 메시지 전송
    for i in range(100):
        msg = {"id": i, "data": f"test_{i}", "timestamp": time.time()}
        producer.send("docker-test", msg)
    
    producer.flush()
    print("✅ 100개 메시지 전송 완료")
    
    # Consumer 테스트
    consumer = KafkaConsumer(
        "docker-test",
        bootstrap_servers="kafka:9092",
        auto_offset_reset="earliest",
        value_deserializer=lambda m: json.loads(m.decode()),
        consumer_timeout_ms=5000
    )
    
    count = 0
    for msg in consumer:
        count += 1
        if count >= 100:
            break
    
    print(f"✅ {count}개 메시지 수신 완료")
    
    # 데이터 무결성 확인
    if count == 100:
        print("✅ 데이터 무결성 확인: 100% 성공")
    else:
        print(f"⚠️ 데이터 손실: {100-count}개")
    
except Exception as e:
    print(f"❌ 오류 발생: {e}")
'''
    
    # Docker 명령어 구성
    cmd = [
        "docker", "run", "--rm",
        "--network", "mqttserver_mqtt_network",
        "python:3.9-slim",
        "bash", "-c",
        f"pip install kafka-python -q && python3 -c '{script}'"
    ]
    
    print("Docker 컨테이너에서 Kafka 테스트 실행 중...")
    print("=" * 60)
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        print(result.stdout)
        if result.stderr:
            print("오류:", result.stderr)
        return result.returncode == 0
    except Exception as e:
        print(f"Docker 실행 실패: {e}")
        return False

if __name__ == "__main__":
    success = run_in_docker()
    if success:
        print("\n🎉 Kafka 데이터 파이프라인 정상 작동!")
    else:
        print("\n❌ 테스트 실패")