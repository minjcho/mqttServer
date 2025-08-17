#!/usr/bin/env python3

"""
Kafka 빠른 연결 테스트
"""

from kafka import KafkaProducer, KafkaConsumer, KafkaAdminClient
from kafka.admin import NewTopic
import json
import time
import sys

def test_connection(bootstrap_servers='localhost:9092'):
    print(f"Kafka 연결 테스트: {bootstrap_servers}")
    
    try:
        # Admin 클라이언트로 연결 테스트
        print("1. Admin 클라이언트 연결 시도...")
        admin = KafkaAdminClient(
            bootstrap_servers=bootstrap_servers,
            client_id='test_client',
            request_timeout_ms=5000,
            connections_max_idle_ms=10000
        )
        
        # 토픽 목록 조회
        print("2. 토픽 목록 조회...")
        topics = admin.list_topics()
        print(f"   현재 토픽: {topics}")
        
        # Producer 테스트
        print("3. Producer 생성...")
        producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            request_timeout_ms=5000,
            api_version_auto_timeout_ms=5000
        )
        
        # 테스트 메시지 전송
        print("4. 테스트 메시지 전송...")
        test_topic = 'connection_test'
        future = producer.send(test_topic, {'test': 'message', 'time': time.time()})
        result = future.get(timeout=5)
        print(f"   전송 성공: partition={result.partition}, offset={result.offset}")
        
        producer.close()
        admin.close()
        
        print("\n✅ Kafka 연결 성공!")
        return True
        
    except Exception as e:
        print(f"\n❌ Kafka 연결 실패: {e}")
        print(f"   에러 타입: {type(e).__name__}")
        
        # 대체 연결 시도
        if 'localhost' in bootstrap_servers:
            print("\n대체 주소로 재시도...")
            alt_servers = [
                '127.0.0.1:9092',
                '172.17.0.1:9092',
                'host.docker.internal:9092'
            ]
            for server in alt_servers:
                print(f"  시도: {server}")
                try:
                    test_admin = KafkaAdminClient(
                        bootstrap_servers=server,
                        request_timeout_ms=2000
                    )
                    test_admin.list_topics()
                    test_admin.close()
                    print(f"  ✅ {server} 연결 성공! 이 주소를 사용하세요.")
                    return server
                except:
                    print(f"  ❌ {server} 연결 실패")
        
        return False

if __name__ == "__main__":
    servers = sys.argv[1] if len(sys.argv) > 1 else 'localhost:9092'
    result = test_connection(servers)
    
    if result and isinstance(result, str):
        print(f"\n사용 가능한 주소: {result}")
        print(f"다음 명령어로 재실행: python3 kafka-data-quality-test.py {result}")