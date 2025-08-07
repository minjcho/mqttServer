#!/usr/bin/env python3

import time
import json
from kafka import KafkaProducer, KafkaConsumer, KafkaAdminClient
from kafka.admin.new_partitions import NewPartitions
from kafka.errors import TopicAlreadyExistsError
import threading
import argparse
from collections import defaultdict
import statistics

class KafkaPerformanceTester:
    def __init__(self, bootstrap_servers='3.36.126.83:9092'):
        self.bootstrap_servers = bootstrap_servers
        self.admin_client = KafkaAdminClient(
            bootstrap_servers=bootstrap_servers,
            client_id='performance_tester'
        )
        
    def test_partition_performance(self, topic_name='performance_test', partitions=[1, 3, 6, 9]):
        """파티션 수에 따른 성능 테스트"""
        print("=== Kafka 파티션 성능 테스트 ===")
        
        results = {}
        
        for partition_count in partitions:
            print(f"\n--- {partition_count}개 파티션 테스트 ---")
            
            # 토픽 생성/수정
            test_topic = f"{topic_name}_{partition_count}p"
            self._create_or_update_topic(test_topic, partition_count)
            
            # 프로듀서 성능 테스트
            producer_tps = self._test_producer_performance(test_topic, num_messages=10000)
            
            # 컨슈머 성능 테스트  
            consumer_tps = self._test_consumer_performance(test_topic, num_consumers=partition_count)
            
            results[partition_count] = {
                'producer_tps': producer_tps,
                'consumer_tps': consumer_tps
            }
            
            print(f"프로듀서 TPS: {producer_tps:.2f} msg/sec")
            print(f"컨슈머 TPS: {consumer_tps:.2f} msg/sec")
        
        self._print_partition_results(results)
        
    def _create_or_update_topic(self, topic_name, partitions):
        """토픽 생성 또는 파티션 수 업데이트"""
        from kafka.admin.new_topic import NewTopic
        
        try:
            # 새 토픽 생성
            topic = NewTopic(
                name=topic_name,
                num_partitions=partitions,
                replication_factor=1
            )
            self.admin_client.create_topics([topic])
            print(f"토픽 '{topic_name}' 생성됨 (파티션: {partitions})")
            
        except TopicAlreadyExistsError:
            # 기존 토픽의 파티션 수 증가
            try:
                partition_update = {topic_name: NewPartitions(total_count=partitions)}
                self.admin_client.create_partitions(partition_update)
                print(f"토픽 '{topic_name}' 파티션 수 업데이트됨: {partitions}")
            except:
                print(f"토픽 '{topic_name}' 이미 존재함")
                
        time.sleep(2)  # 토픽 생성 대기
        
    def _test_producer_performance(self, topic_name, num_messages=10000):
        """프로듀서 성능 테스트"""
        producer = KafkaProducer(
            bootstrap_servers=self.bootstrap_servers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            batch_size=16384,  # 16KB
            linger_ms=10,
            compression_type='snappy'
        )
        
        start_time = time.time()
        
        for i in range(num_messages):
            message = {
                'timestamp': time.time(),
                'message_id': i,
                'robot_id': i % 10,
                'data': f'performance_test_message_{i}'
            }
            producer.send(topic_name, message)
            
            if i % 1000 == 0:
                print(f"  Producer progress: {i}/{num_messages}")
        
        producer.flush()
        producer.close()
        
        end_time = time.time()
        duration = end_time - start_time
        tps = num_messages / duration
        
        return tps
        
    def _test_consumer_performance(self, topic_name, num_consumers=1):
        """컨슈머 성능 테스트"""
        consumed_counts = defaultdict(int)
        start_time = time.time()
        test_duration = 10  # 10초간 테스트
        
        def consume_messages(consumer_id):
            consumer = KafkaConsumer(
                topic_name,
                bootstrap_servers=self.bootstrap_servers,
                group_id=f'perf_test_group_{int(time.time())}',
                value_deserializer=lambda m: json.loads(m.decode('utf-8')),
                auto_offset_reset='earliest'
            )
            
            timeout = time.time() + test_duration
            while time.time() < timeout:
                messages = consumer.poll(timeout_ms=100)
                for topic_partition, msgs in messages.items():
                    consumed_counts[consumer_id] += len(msgs)
            
            consumer.close()
        
        # 여러 컨슈머 스레드 시작
        threads = []
        for i in range(num_consumers):
            thread = threading.Thread(target=consume_messages, args=(i,))
            thread.start()
            threads.append(thread)
        
        # 모든 스레드 완료 대기
        for thread in threads:
            thread.join()
            
        total_consumed = sum(consumed_counts.values())
        tps = total_consumed / test_duration
        
        return tps
    
    def test_throughput_scaling(self, topic_name='throughput_test'):
        """처리량 스케일링 테스트"""
        print("\n=== Kafka 처리량 스케일링 테스트 ===")
        
        producer_counts = [1, 2, 4, 8]
        results = {}
        
        for producer_count in producer_counts:
            print(f"\n--- {producer_count}개 프로듀서 테스트 ---")
            
            messages_per_producer = 5000
            total_messages = messages_per_producer * producer_count
            
            start_time = time.time()
            
            def produce_messages(producer_id):
                producer = KafkaProducer(
                    bootstrap_servers=self.bootstrap_servers,
                    value_serializer=lambda v: json.dumps(v).encode('utf-8')
                )
                
                for i in range(messages_per_producer):
                    message = {
                        'producer_id': producer_id,
                        'message_id': i,
                        'timestamp': time.time(),
                        'data': f'scaling_test_p{producer_id}_m{i}'
                    }
                    producer.send(topic_name, message)
                
                producer.flush()
                producer.close()
            
            # 여러 프로듀서 스레드 시작
            threads = []
            for i in range(producer_count):
                thread = threading.Thread(target=produce_messages, args=(i,))
                thread.start()
                threads.append(thread)
            
            # 모든 스레드 완료 대기
            for thread in threads:
                thread.join()
            
            end_time = time.time()
            duration = end_time - start_time
            tps = total_messages / duration
            
            results[producer_count] = tps
            print(f"총 메시지: {total_messages}, 처리시간: {duration:.2f}s, TPS: {tps:.2f}")
        
        self._print_scaling_results(results)
    
    def test_message_size_performance(self, topic_name='size_test'):
        """메시지 크기별 성능 테스트"""
        print("\n=== 메시지 크기별 성능 테스트 ===")
        
        message_sizes = [100, 1024, 10240, 102400]  # 100B, 1KB, 10KB, 100KB
        results = {}
        
        for size in message_sizes:
            print(f"\n--- {size}바이트 메시지 테스트 ---")
            
            # 더미 데이터 생성
            dummy_data = 'x' * (size - 50)  # JSON 구조를 위한 여유공간
            
            producer = KafkaProducer(
                bootstrap_servers=self.bootstrap_servers,
                value_serializer=lambda v: json.dumps(v).encode('utf-8')
            )
            
            num_messages = 1000
            start_time = time.time()
            
            for i in range(num_messages):
                message = {
                    'message_id': i,
                    'timestamp': time.time(),
                    'data': dummy_data
                }
                producer.send(topic_name, message)
            
            producer.flush()
            producer.close()
            
            end_time = time.time()
            duration = end_time - start_time
            tps = num_messages / duration
            throughput_mb = (num_messages * size) / (duration * 1024 * 1024)  # MB/s
            
            results[size] = {'tps': tps, 'throughput_mb': throughput_mb}
            print(f"TPS: {tps:.2f} msg/sec, 처리량: {throughput_mb:.2f} MB/s")
        
        self._print_size_results(results)
    
    def _print_partition_results(self, results):
        print("\n=== 파티션별 성능 요약 ===")
        print("파티션수\t프로듀서TPS\t컨슈머TPS")
        print("-" * 40)
        for partitions, data in results.items():
            print(f"{partitions}\t\t{data['producer_tps']:.2f}\t\t{data['consumer_tps']:.2f}")
    
    def _print_scaling_results(self, results):
        print("\n=== 스케일링 성능 요약 ===")
        print("프로듀서수\tTPS\t\t스케일링 효율")
        print("-" * 40)
        baseline = results[1] if 1 in results else list(results.values())[0]
        for count, tps in results.items():
            efficiency = (tps / baseline) / count * 100
            print(f"{count}\t\t{tps:.2f}\t\t{efficiency:.1f}%")
    
    def _print_size_results(self, results):
        print("\n=== 메시지 크기별 성능 요약 ===")
        print("메시지크기\tTPS\t\t처리량(MB/s)")
        print("-" * 40)
        for size, data in results.items():
            size_str = f"{size}B" if size < 1024 else f"{size//1024}KB"
            print(f"{size_str}\t\t{data['tps']:.2f}\t\t{data['throughput_mb']:.2f}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Kafka 성능 테스트')
    parser.add_argument('--test', choices=['all', 'partition', 'scaling', 'size'], 
                       default='all', help='실행할 테스트 종류')
    parser.add_argument('--bootstrap-servers', default='3.36.126.83:9092', 
                       help='Kafka 브로커 주소')
    
    args = parser.parse_args()
    
    tester = KafkaPerformanceTester(args.bootstrap_servers)
    
    try:
        if args.test in ['all', 'partition']:
            tester.test_partition_performance()
        
        if args.test in ['all', 'scaling']:
            tester.test_throughput_scaling()
            
        if args.test in ['all', 'size']:
            tester.test_message_size_performance()
            
    except KeyboardInterrupt:
        print("\n테스트가 중단되었습니다.")
    except Exception as e:
        print(f"테스트 중 오류 발생: {e}")