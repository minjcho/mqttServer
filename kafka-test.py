#!/usr/bin/env python3

"""
Kafka 데이터 파이프라인 테스트 스크립트
목적: 데이터가 Kafka에 정상적으로 저장되고 소비되는지 검증
"""

import json
import time
import uuid
import threading
from datetime import datetime
from kafka import KafkaProducer, KafkaConsumer, KafkaAdminClient
from kafka.admin import NewTopic
from kafka.errors import KafkaError
import argparse
import sys

class KafkaDataPipelineTest:
    def __init__(self, bootstrap_servers='localhost:9092'):
        self.bootstrap_servers = bootstrap_servers
        self.test_topic = f'test_topic_{uuid.uuid4().hex[:8]}'
        self.messages_sent = []
        self.messages_received = []
        self.producer = None
        self.consumer = None
        
    def setup(self):
        """Kafka 연결 설정 및 토픽 생성"""
        print(f"[설정] Kafka 서버 연결: {self.bootstrap_servers}")
        
        try:
            # Admin 클라이언트로 토픽 생성
            admin = KafkaAdminClient(
                bootstrap_servers=self.bootstrap_servers,
                client_id='test_admin'
            )
            
            topic = NewTopic(
                name=self.test_topic,
                num_partitions=3,
                replication_factor=1
            )
            
            admin.create_topics([topic])
            print(f"[설정] 테스트 토픽 생성: {self.test_topic}")
            
            # Producer 설정
            self.producer = KafkaProducer(
                bootstrap_servers=self.bootstrap_servers,
                value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                acks='all',  # 모든 레플리카 확인
                retries=3,
                max_in_flight_requests_per_connection=1,
                compression_type='gzip'
            )
            
            # Consumer 설정
            self.consumer = KafkaConsumer(
                self.test_topic,
                bootstrap_servers=self.bootstrap_servers,
                value_deserializer=lambda m: json.loads(m.decode('utf-8')),
                auto_offset_reset='earliest',
                enable_auto_commit=True,
                group_id=f'test_group_{uuid.uuid4().hex[:8]}'
            )
            
            print("[설정] Producer/Consumer 초기화 완료")
            return True
            
        except Exception as e:
            print(f"[오류] Kafka 설정 실패: {e}")
            return False
    
    def produce_messages(self, count=100, interval=0.01):
        """테스트 메시지 생성 및 전송"""
        print(f"\n[Producer] {count}개 메시지 전송 시작...")
        
        success_count = 0
        error_count = 0
        
        for i in range(count):
            message = {
                'id': str(uuid.uuid4()),
                'sequence': i,
                'timestamp': datetime.now().isoformat(),
                'data': {
                    'sensor_id': f'sensor_{i % 10}',
                    'value': 20.0 + (i % 10),
                    'unit': 'celsius'
                },
                'test_run': self.test_topic
            }
            
            try:
                future = self.producer.send(
                    self.test_topic,
                    value=message,
                    key=str(i % 3).encode('utf-8')  # 파티션 분산
                )
                
                # 동기 전송 확인
                record_metadata = future.get(timeout=10)
                
                self.messages_sent.append(message)
                success_count += 1
                
                if (i + 1) % 10 == 0:
                    print(f"  전송 진행: {i + 1}/{count}")
                
                time.sleep(interval)
                
            except KafkaError as e:
                print(f"  [오류] 메시지 {i} 전송 실패: {e}")
                error_count += 1
        
        self.producer.flush()
        print(f"[Producer] 완료 - 성공: {success_count}, 실패: {error_count}")
        return success_count
    
    def consume_messages(self, timeout=30):
        """메시지 소비 및 검증"""
        print(f"\n[Consumer] 메시지 수신 시작 (최대 {timeout}초)...")
        
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            msg_pack = self.consumer.poll(timeout_ms=1000)
            
            if not msg_pack:
                continue
                
            for tp, messages in msg_pack.items():
                for message in messages:
                    self.messages_received.append(message.value)
                    
                    if len(self.messages_received) % 10 == 0:
                        print(f"  수신 진행: {len(self.messages_received)}개")
            
            # 모든 메시지 수신 완료 확인
            if len(self.messages_received) >= len(self.messages_sent):
                break
        
        print(f"[Consumer] 완료 - 수신: {len(self.messages_received)}개")
        return len(self.messages_received)
    
    def verify_data_integrity(self):
        """데이터 무결성 검증"""
        print(f"\n[검증] 데이터 무결성 확인...")
        
        # 1. 수량 확인
        sent_count = len(self.messages_sent)
        received_count = len(self.messages_received)
        
        print(f"  전송: {sent_count}, 수신: {received_count}")
        
        if sent_count != received_count:
            print(f"  ⚠️ 메시지 손실 감지: {sent_count - received_count}개")
            return False
        
        # 2. 순서 및 내용 확인
        sent_ids = {msg['id'] for msg in self.messages_sent}
        received_ids = {msg['id'] for msg in self.messages_received}
        
        missing = sent_ids - received_ids
        if missing:
            print(f"  ⚠️ 누락된 메시지 ID: {list(missing)[:5]}...")
            return False
        
        duplicate = [msg['id'] for msg in self.messages_received 
                    if self.messages_received.count(msg) > 1]
        if duplicate:
            print(f"  ⚠️ 중복 메시지 감지: {len(duplicate)}개")
            return False
        
        print("  ✅ 데이터 무결성 확인 완료")
        return True
    
    def measure_latency(self):
        """지연 시간 측정"""
        print(f"\n[성능] 지연 시간 측정...")
        
        latencies = []
        
        for i in range(10):
            start = time.time()
            
            test_msg = {
                'latency_test': i,
                'timestamp': time.time()
            }
            
            future = self.producer.send(self.test_topic, value=test_msg)
            future.get(timeout=10)
            
            end = time.time()
            latency = (end - start) * 1000  # ms
            latencies.append(latency)
        
        avg_latency = sum(latencies) / len(latencies)
        min_latency = min(latencies)
        max_latency = max(latencies)
        
        print(f"  평균: {avg_latency:.2f}ms")
        print(f"  최소: {min_latency:.2f}ms")
        print(f"  최대: {max_latency:.2f}ms")
        
        return avg_latency
    
    def test_throughput(self, duration=10):
        """처리량 테스트"""
        print(f"\n[성능] 처리량 테스트 ({duration}초)...")
        
        count = 0
        start_time = time.time()
        message_size = 1024  # 1KB 메시지
        
        dummy_data = 'x' * message_size
        
        while time.time() - start_time < duration:
            try:
                self.producer.send(
                    self.test_topic,
                    value={'data': dummy_data, 'seq': count}
                )
                count += 1
            except Exception as e:
                print(f"  오류: {e}")
                break
        
        self.producer.flush()
        
        elapsed = time.time() - start_time
        throughput = count / elapsed
        data_rate = (count * message_size) / (1024 * 1024) / elapsed  # MB/s
        
        print(f"  메시지 처리량: {throughput:.2f} msgs/sec")
        print(f"  데이터 처리량: {data_rate:.2f} MB/s")
        print(f"  총 전송: {count}개 메시지")
        
        return throughput
    
    def cleanup(self):
        """리소스 정리"""
        print(f"\n[정리] 테스트 리소스 정리...")
        
        if self.producer:
            self.producer.close()
        if self.consumer:
            self.consumer.close()
        
        # 테스트 토픽 삭제
        try:
            admin = KafkaAdminClient(
                bootstrap_servers=self.bootstrap_servers,
                client_id='test_admin_cleanup'
            )
            admin.delete_topics([self.test_topic])
            print(f"  테스트 토픽 삭제: {self.test_topic}")
        except:
            pass
    
    def run_all_tests(self):
        """전체 테스트 실행"""
        print("=" * 60)
        print("Kafka 데이터 파이프라인 테스트 시작")
        print("=" * 60)
        
        results = {
            'setup': False,
            'produce': 0,
            'consume': 0,
            'integrity': False,
            'latency': 0,
            'throughput': 0
        }
        
        # 1. 설정
        if not self.setup():
            print("\n[실패] Kafka 연결 실패")
            return results
        results['setup'] = True
        
        # 2. 메시지 전송
        results['produce'] = self.produce_messages(100)
        
        # 3. 메시지 수신
        results['consume'] = self.consume_messages()
        
        # 4. 데이터 무결성
        results['integrity'] = self.verify_data_integrity()
        
        # 5. 지연 시간
        results['latency'] = self.measure_latency()
        
        # 6. 처리량
        results['throughput'] = self.test_throughput(10)
        
        # 7. 정리
        self.cleanup()
        
        # 결과 요약
        print("\n" + "=" * 60)
        print("테스트 결과 요약")
        print("=" * 60)
        print(f"✅ Kafka 연결: {'성공' if results['setup'] else '실패'}")
        print(f"✅ 메시지 전송: {results['produce']}개")
        print(f"✅ 메시지 수신: {results['consume']}개")
        print(f"✅ 데이터 무결성: {'통과' if results['integrity'] else '실패'}")
        print(f"✅ 평균 지연시간: {results['latency']:.2f}ms")
        print(f"✅ 처리량: {results['throughput']:.2f} msgs/sec")
        
        # 전체 평가
        if results['setup'] and results['integrity'] and results['produce'] > 0:
            print("\n🎉 전체 테스트: 성공")
        else:
            print("\n❌ 전체 테스트: 실패")
        
        return results

def main():
    parser = argparse.ArgumentParser(description='Kafka 데이터 파이프라인 테스트')
    parser.add_argument('--bootstrap-servers', default='localhost:9092',
                       help='Kafka 브로커 주소 (기본: localhost:9092)')
    parser.add_argument('--simple', action='store_true',
                       help='간단한 연결 테스트만 수행')
    
    args = parser.parse_args()
    
    tester = KafkaDataPipelineTest(args.bootstrap_servers)
    
    if args.simple:
        # 간단한 테스트
        if tester.setup():
            print("✅ Kafka 연결 성공!")
            tester.cleanup()
        else:
            print("❌ Kafka 연결 실패!")
    else:
        # 전체 테스트
        tester.run_all_tests()

if __name__ == "__main__":
    main()