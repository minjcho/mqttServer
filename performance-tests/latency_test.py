#!/usr/bin/env python3

import time
import json
import asyncio
import redis
import paho.mqtt.client as mqtt
from datetime import datetime
import statistics
import argparse

class LatencyTester:
    def __init__(self, mqtt_host="3.36.126.83", mqtt_port=3123, redis_host="3.36.126.83", redis_port=6379):
        self.mqtt_host = mqtt_host
        self.mqtt_port = mqtt_port
        self.redis_client = redis.Redis(host=redis_host, port=redis_port, decode_responses=True)
        self.latencies = []
        
    def test_end_to_end_latency(self, num_tests=100):
        """MQTT 발송부터 Redis 저장까지의 지연시간 측정"""
        print(f"=== End-to-End 지연시간 테스트 ({num_tests}회) ===")
        
        client = mqtt.Client()
        client.connect(self.mqtt_host, self.mqtt_port, 60)
        
        for i in range(num_tests):
            # 타임스탬프와 함께 메시지 발송
            timestamp = time.time() * 1000  # milliseconds
            topic = f"sensors/latency_test/timestamp_{i}"
            message = json.dumps({
                "timestamp": timestamp,
                "test_id": i,
                "data": f"latency_test_message_{i}"
            })
            
            # MQTT 메시지 발송
            send_time = time.time() * 1000
            client.publish(topic, message)
            
            # Redis에서 데이터가 나타날 때까지 대기
            max_wait = 5000  # 5초 최대 대기
            wait_start = time.time() * 1000
            
            while True:
                current_time = time.time() * 1000
                if current_time - wait_start > max_wait:
                    print(f"Test {i}: Timeout after {max_wait}ms")
                    break
                    
                # Redis에서 데이터 확인
                try:
                    redis_data = self.redis_client.get(topic)
                    if redis_data:
                        receive_time = time.time() * 1000
                        latency = receive_time - send_time
                        self.latencies.append(latency)
                        print(f"Test {i}: {latency:.2f}ms")
                        break
                except:
                    pass
                    
                time.sleep(0.001)  # 1ms 대기
                
            # 테스트 간 간격
            time.sleep(0.1)
            
        client.disconnect()
        
        if self.latencies:
            self.print_statistics()
        else:
            print("모든 테스트가 실패했습니다.")
    
    def test_mqtt_only_latency(self, num_tests=1000):
        """MQTT 발송 자체의 지연시간 측정"""
        print(f"=== MQTT 발송 지연시간 테스트 ({num_tests}회) ===")
        
        mqtt_latencies = []
        client = mqtt.Client()
        client.connect(self.mqtt_host, self.mqtt_port, 60)
        
        for i in range(num_tests):
            start_time = time.time() * 1000
            client.publish(f"sensors/mqtt_test/data_{i}", f"test_message_{i}")
            end_time = time.time() * 1000
            
            latency = end_time - start_time
            mqtt_latencies.append(latency)
            
            if i % 100 == 0:
                print(f"Progress: {i}/{num_tests}")
                
        client.disconnect()
        
        print(f"\n=== MQTT 발송 지연시간 통계 ===")
        print(f"평균: {statistics.mean(mqtt_latencies):.2f}ms")
        print(f"최소: {min(mqtt_latencies):.2f}ms")
        print(f"최대: {max(mqtt_latencies):.2f}ms")
        print(f"중간값: {statistics.median(mqtt_latencies):.2f}ms")
        print(f"95퍼센타일: {sorted(mqtt_latencies)[int(len(mqtt_latencies) * 0.95)]:.2f}ms")
        
    def test_redis_latency(self, num_tests=1000):
        """Redis 읽기/쓰기 지연시간 측정"""
        print(f"=== Redis 지연시간 테스트 ({num_tests}회) ===")
        
        write_latencies = []
        read_latencies = []
        
        for i in range(num_tests):
            # Redis 쓰기 테스트
            start_time = time.time() * 1000
            self.redis_client.set(f"test_key_{i}", f"test_value_{i}")
            end_time = time.time() * 1000
            write_latencies.append(end_time - start_time)
            
            # Redis 읽기 테스트
            start_time = time.time() * 1000
            self.redis_client.get(f"test_key_{i}")
            end_time = time.time() * 1000
            read_latencies.append(end_time - start_time)
            
            if i % 100 == 0:
                print(f"Progress: {i}/{num_tests}")
        
        print(f"\n=== Redis 쓰기 지연시간 통계 ===")
        print(f"평균: {statistics.mean(write_latencies):.2f}ms")
        print(f"최소: {min(write_latencies):.2f}ms")
        print(f"최대: {max(write_latencies):.2f}ms")
        print(f"중간값: {statistics.median(write_latencies):.2f}ms")
        
        print(f"\n=== Redis 읽기 지연시간 통계 ===")
        print(f"평균: {statistics.mean(read_latencies):.2f}ms")
        print(f"최소: {min(read_latencies):.2f}ms")
        print(f"최대: {max(read_latencies):.2f}ms")
        print(f"중간값: {statistics.median(read_latencies):.2f}ms")
        
    def print_statistics(self):
        if not self.latencies:
            return
            
        print(f"\n=== End-to-End 지연시간 통계 ===")
        print(f"성공한 테스트: {len(self.latencies)}회")
        print(f"평균: {statistics.mean(self.latencies):.2f}ms")
        print(f"최소: {min(self.latencies):.2f}ms")
        print(f"최대: {max(self.latencies):.2f}ms")
        print(f"중간값: {statistics.median(self.latencies):.2f}ms")
        print(f"95퍼센타일: {sorted(self.latencies)[int(len(self.latencies) * 0.95)]:.2f}ms")
        print(f"99퍼센타일: {sorted(self.latencies)[int(len(self.latencies) * 0.99)]:.2f}ms")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='MQTT-Kafka-Redis 지연시간 테스트')
    parser.add_argument('--test', choices=['all', 'end-to-end', 'mqtt', 'redis'], 
                       default='all', help='실행할 테스트 종류')
    parser.add_argument('--count', type=int, default=100, help='테스트 횟수')
    
    args = parser.parse_args()
    
    tester = LatencyTester()
    
    if args.test in ['all', 'end-to-end']:
        tester.test_end_to_end_latency(args.count)
    
    if args.test in ['all', 'mqtt']:
        tester.test_mqtt_only_latency(args.count)
        
    if args.test in ['all', 'redis']:
        tester.test_redis_latency(args.count)