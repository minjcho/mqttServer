#!/usr/bin/env python3

"""
데이터 엔지니어링 관점의 Kafka 품질 검증
- 데이터 무결성, 중복, 순서, 스키마 검증
"""

import json
import time
import hashlib
from datetime import datetime, timedelta
from collections import defaultdict
from kafka import KafkaProducer, KafkaConsumer
from kafka.structs import TopicPartition
import pandas as pd
import numpy as np

class DataQualityTest:
    def __init__(self, bootstrap_servers='localhost:9092'):
        self.bootstrap_servers = bootstrap_servers
        self.test_results = {
            'duplicates': [],
            'out_of_order': [],
            'data_loss': [],
            'schema_violations': [],
            'latency_issues': []
        }
        
    def test_exactly_once_semantics(self):
        """Exactly-Once 시맨틱 검증"""
        print("\n[검증] Exactly-Once Delivery 테스트...")
        
        topic = 'exactly_once_test'
        
        # Idempotent Producer 설정
        producer = KafkaProducer(
            bootstrap_servers=self.bootstrap_servers,
            enable_idempotence=True,  # 중요: 중복 방지
            acks='all',
            max_in_flight_requests_per_connection=5,
            retries=10,
            value_serializer=lambda v: json.dumps(v).encode()
        )
        
        # 트랜잭션 ID로 중복 체크
        sent_ids = set()
        for i in range(1000):
            msg_id = f"msg_{i}_{time.time()}"
            sent_ids.add(msg_id)
            
            producer.send(topic, {
                'id': msg_id,
                'sequence': i,
                'timestamp': time.time()
            })
        
        producer.flush()
        
        # Consumer로 검증
        consumer = KafkaConsumer(
            topic,
            bootstrap_servers=self.bootstrap_servers,
            auto_offset_reset='earliest',
            value_deserializer=lambda m: json.loads(m.decode())
        )
        
        received_ids = []
        start = time.time()
        while time.time() - start < 5:
            msgs = consumer.poll(timeout_ms=1000)
            for tp, records in msgs.items():
                for record in records:
                    received_ids.append(record.value['id'])
        
        # 중복 검사
        duplicates = [x for x in received_ids if received_ids.count(x) > 1]
        if duplicates:
            print(f"  ❌ 중복 발견: {len(set(duplicates))}개")
            self.test_results['duplicates'] = duplicates[:10]
        else:
            print(f"  ✅ 중복 없음 (전송: {len(sent_ids)}, 수신: {len(received_ids)})")
        
        consumer.close()
        return len(duplicates) == 0
    
    def test_message_ordering(self):
        """파티션 내 메시지 순서 보장 검증"""
        print("\n[검증] 메시지 순서 보장 테스트...")
        
        topic = 'order_test'
        
        producer = KafkaProducer(
            bootstrap_servers=self.bootstrap_servers,
            value_serializer=lambda v: json.dumps(v).encode(),
            key_serializer=lambda k: k.encode()
        )
        
        # 같은 키로 전송 (같은 파티션 보장)
        key = 'order_key_1'
        for i in range(100):
            producer.send(topic, key=key, value={
                'sequence': i,
                'timestamp': time.time()
            })
        
        producer.flush()
        
        # 순서 검증
        consumer = KafkaConsumer(
            topic,
            bootstrap_servers=self.bootstrap_servers,
            auto_offset_reset='earliest',
            value_deserializer=lambda m: json.loads(m.decode())
        )
        
        sequences = []
        start = time.time()
        while time.time() - start < 3:
            msgs = consumer.poll(timeout_ms=500)
            for tp, records in msgs.items():
                for record in records:
                    if record.key and record.key.decode() == key:
                        sequences.append(record.value['sequence'])
        
        # 순서 확인
        out_of_order = []
        for i in range(1, len(sequences)):
            if sequences[i] < sequences[i-1]:
                out_of_order.append((sequences[i-1], sequences[i]))
        
        if out_of_order:
            print(f"  ❌ 순서 깨짐: {len(out_of_order)}건")
            self.test_results['out_of_order'] = out_of_order[:5]
        else:
            print(f"  ✅ 순서 보장됨 ({len(sequences)}개 메시지)")
        
        consumer.close()
        return len(out_of_order) == 0
    
    def test_partition_distribution(self):
        """파티션 분산 균형 테스트"""
        print("\n[검증] 파티션 분산 테스트...")
        
        topic = 'partition_test'
        
        producer = KafkaProducer(
            bootstrap_servers=self.bootstrap_servers,
            value_serializer=lambda v: json.dumps(v).encode()
        )
        
        # 다양한 키로 전송
        partition_count = defaultdict(int)
        
        for i in range(1000):
            key = f"key_{i % 100}"  # 100개의 다른 키
            
            metadata = producer.send(
                topic,
                key=key.encode(),
                value={'data': f'message_{i}'}
            ).get(timeout=10)
            
            partition_count[metadata.partition] += 1
        
        producer.flush()
        
        # 분산 분석
        total = sum(partition_count.values())
        print(f"  파티션별 분포:")
        for partition, count in sorted(partition_count.items()):
            percentage = (count / total) * 100
            print(f"    파티션 {partition}: {count}개 ({percentage:.1f}%)")
        
        # 표준편차 계산
        counts = list(partition_count.values())
        if counts:
            std_dev = np.std(counts)
            mean = np.mean(counts)
            cv = (std_dev / mean) * 100 if mean > 0 else 0
            
            print(f"  변동계수: {cv:.2f}%")
            
            if cv < 20:
                print(f"  ✅ 균등 분산 (CV < 20%)")
                return True
            else:
                print(f"  ⚠️ 불균등 분산 (CV = {cv:.2f}%)")
                return False
        
        return True
    
    def test_consumer_lag(self):
        """Consumer LAG 모니터링"""
        print("\n[검증] Consumer LAG 테스트...")
        
        topic = 'lag_test'
        group_id = 'lag_test_group'
        
        # Producer로 대량 메시지 전송
        producer = KafkaProducer(
            bootstrap_servers=self.bootstrap_servers,
            value_serializer=lambda v: json.dumps(v).encode()
        )
        
        print("  대량 메시지 전송 중...")
        for i in range(5000):
            producer.send(topic, {'seq': i})
        producer.flush()
        
        # Consumer 시작 (느리게 처리)
        consumer = KafkaConsumer(
            topic,
            bootstrap_servers=self.bootstrap_servers,
            group_id=group_id,
            auto_offset_reset='earliest',
            value_deserializer=lambda m: json.loads(m.decode())
        )
        
        # LAG 측정
        processed = 0
        max_lag = 0
        
        for _ in range(10):  # 10번만 폴링
            msgs = consumer.poll(timeout_ms=1000, max_records=100)
            
            for tp, records in msgs.items():
                processed += len(records)
                
                # 현재 오프셋과 최신 오프셋 비교
                committed = consumer.committed(tp) or 0
                highwater = consumer.highwater(tp)
                lag = highwater - committed
                max_lag = max(max_lag, lag)
                
            time.sleep(0.5)  # 의도적 지연
        
        print(f"  처리: {processed}개")
        print(f"  최대 LAG: {max_lag}")
        
        if max_lag > 1000:
            print(f"  ⚠️ 높은 LAG 감지 (> 1000)")
            self.test_results['latency_issues'].append(f"LAG: {max_lag}")
        else:
            print(f"  ✅ LAG 정상 범위")
        
        consumer.close()
        return max_lag < 1000
    
    def test_schema_evolution(self):
        """스키마 진화 호환성 테스트"""
        print("\n[검증] 스키마 호환성 테스트...")
        
        topic = 'schema_test'
        
        producer = KafkaProducer(
            bootstrap_servers=self.bootstrap_servers,
            value_serializer=lambda v: json.dumps(v).encode()
        )
        
        # V1 스키마
        v1_messages = [
            {'version': 1, 'id': i, 'name': f'item_{i}'} 
            for i in range(10)
        ]
        
        # V2 스키마 (필드 추가)
        v2_messages = [
            {'version': 2, 'id': i, 'name': f'item_{i}', 'category': 'new'} 
            for i in range(10, 20)
        ]
        
        # V3 스키마 (필드 타입 변경 시도)
        v3_messages = [
            {'version': 3, 'id': str(i), 'name': f'item_{i}', 'category': 'new'} 
            for i in range(20, 30)
        ]
        
        # 전송
        for msg in v1_messages + v2_messages + v3_messages:
            producer.send(topic, msg)
        producer.flush()
        
        # 수신 및 검증
        consumer = KafkaConsumer(
            topic,
            bootstrap_servers=self.bootstrap_servers,
            auto_offset_reset='earliest',
            value_deserializer=lambda m: json.loads(m.decode())
        )
        
        schema_issues = []
        messages_by_version = defaultdict(list)
        
        start = time.time()
        while time.time() - start < 3:
            msgs = consumer.poll(timeout_ms=500)
            for tp, records in msgs.items():
                for record in records:
                    msg = record.value
                    version = msg.get('version', 0)
                    messages_by_version[version].append(msg)
                    
                    # 스키마 검증
                    if version == 1 and 'category' in msg:
                        schema_issues.append(f"V1에 예상치 못한 필드: category")
                    if version >= 2 and 'category' not in msg:
                        schema_issues.append(f"V{version}에 필수 필드 누락: category")
                    if version == 3 and not isinstance(msg.get('id'), str):
                        schema_issues.append(f"V3 타입 불일치: id는 string이어야 함")
        
        print(f"  버전별 메시지 수신:")
        for v, msgs in sorted(messages_by_version.items()):
            print(f"    V{v}: {len(msgs)}개")
        
        if schema_issues:
            print(f"  ❌ 스키마 문제: {len(schema_issues)}건")
            self.test_results['schema_violations'] = schema_issues[:5]
        else:
            print(f"  ✅ 스키마 호환성 유지")
        
        consumer.close()
        return len(schema_issues) == 0
    
    def test_data_completeness(self):
        """데이터 완전성 검증 (NULL, 누락 필드)"""
        print("\n[검증] 데이터 완전성 테스트...")
        
        topic = 'completeness_test'
        
        producer = KafkaProducer(
            bootstrap_servers=self.bootstrap_servers,
            value_serializer=lambda v: json.dumps(v).encode()
        )
        
        # 다양한 품질의 데이터 전송
        test_data = [
            {'id': 1, 'value': 100, 'timestamp': time.time()},  # 정상
            {'id': 2, 'value': None, 'timestamp': time.time()},  # NULL 값
            {'id': 3, 'timestamp': time.time()},  # 필드 누락
            {'id': None, 'value': 100, 'timestamp': time.time()},  # NULL ID
            {},  # 빈 객체
            {'id': 5, 'value': 'invalid', 'timestamp': 'invalid'},  # 타입 오류
        ]
        
        for data in test_data:
            producer.send(topic, data)
        producer.flush()
        
        # 데이터 품질 검증
        consumer = KafkaConsumer(
            topic,
            bootstrap_servers=self.bootstrap_servers,
            auto_offset_reset='earliest',
            value_deserializer=lambda m: json.loads(m.decode())
        )
        
        quality_issues = {
            'null_values': 0,
            'missing_fields': 0,
            'type_errors': 0,
            'empty_records': 0
        }
        
        required_fields = ['id', 'value', 'timestamp']
        
        start = time.time()
        while time.time() - start < 3:
            msgs = consumer.poll(timeout_ms=500)
            for tp, records in msgs.items():
                for record in records:
                    msg = record.value
                    
                    # 빈 레코드
                    if not msg:
                        quality_issues['empty_records'] += 1
                        continue
                    
                    # 필수 필드 체크
                    for field in required_fields:
                        if field not in msg:
                            quality_issues['missing_fields'] += 1
                        elif msg[field] is None:
                            quality_issues['null_values'] += 1
                    
                    # 타입 체크
                    if 'value' in msg and msg['value'] is not None:
                        if not isinstance(msg['value'], (int, float)):
                            quality_issues['type_errors'] += 1
        
        print(f"  데이터 품질 이슈:")
        total_issues = 0
        for issue_type, count in quality_issues.items():
            if count > 0:
                print(f"    {issue_type}: {count}건")
                total_issues += count
        
        if total_issues > 0:
            print(f"  ⚠️ 데이터 품질 이슈 발견: 총 {total_issues}건")
        else:
            print(f"  ✅ 데이터 완전성 확인")
        
        consumer.close()
        return total_issues == 0
    
    def generate_report(self):
        """종합 리포트 생성"""
        print("\n" + "="*60)
        print("데이터 품질 검증 리포트")
        print("="*60)
        
        # 이슈 요약
        total_issues = sum(len(v) for v in self.test_results.values())
        
        if total_issues == 0:
            print("✅ 모든 데이터 품질 테스트 통과!")
        else:
            print(f"⚠️ 총 {total_issues}개 이슈 발견:")
            
            if self.test_results['duplicates']:
                print(f"\n[중복 데이터]")
                for dup in self.test_results['duplicates'][:3]:
                    print(f"  - {dup}")
            
            if self.test_results['out_of_order']:
                print(f"\n[순서 오류]")
                for oo in self.test_results['out_of_order'][:3]:
                    print(f"  - {oo[0]} → {oo[1]}")
            
            if self.test_results['schema_violations']:
                print(f"\n[스키마 위반]")
                for sv in self.test_results['schema_violations'][:3]:
                    print(f"  - {sv}")
            
            if self.test_results['latency_issues']:
                print(f"\n[지연 이슈]")
                for li in self.test_results['latency_issues'][:3]:
                    print(f"  - {li}")
        
        # 권장사항
        print("\n[권장사항]")
        if self.test_results['duplicates']:
            print("  • Idempotent Producer 설정 활성화")
            print("  • Exactly-Once 시맨틱 적용")
        
        if self.test_results['out_of_order']:
            print("  • 단일 파티션 사용 또는 키 기반 파티셔닝")
            print("  • max.in.flight.requests.per.connection=1 설정")
        
        if self.test_results['schema_violations']:
            print("  • Schema Registry 도입 검토")
            print("  • Avro/Protobuf 등 스키마 진화 지원 포맷 사용")
        
        if self.test_results['latency_issues']:
            print("  • Consumer 병렬 처리 증가")
            print("  • 배치 크기 및 폴링 간격 최적화")
        
        print("="*60)

def main():
    tester = DataQualityTest('localhost:9092')
    
    # 모든 테스트 실행
    tests = [
        tester.test_exactly_once_semantics,
        tester.test_message_ordering,
        tester.test_partition_distribution,
        tester.test_consumer_lag,
        tester.test_schema_evolution,
        tester.test_data_completeness
    ]
    
    results = []
    for test in tests:
        try:
            results.append(test())
        except Exception as e:
            print(f"  테스트 실패: {e}")
            results.append(False)
    
    # 최종 리포트
    tester.generate_report()
    
    # 성공/실패 판정
    if all(results):
        print("\n🎉 데이터 파이프라인 품질 검증 완료!")
        return 0
    else:
        print("\n❌ 일부 품질 테스트 실패")
        return 1

if __name__ == "__main__":
    exit(main())