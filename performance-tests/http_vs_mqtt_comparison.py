#!/usr/bin/env python3

import time
import requests
import paho.mqtt.client as mqtt
import threading
import statistics
import json
import argparse
from concurrent.futures import ThreadPoolExecutor
import socket

class HTTPvsMQTTComparison:
    def __init__(self, mqtt_host="3.36.126.83", mqtt_port=3123, http_base_url="http://3.36.126.83:8081"):
        self.mqtt_host = mqtt_host
        self.mqtt_port = mqtt_port
        self.http_base_url = http_base_url
        self.results = {
            'http': {'latencies': [], 'throughput': 0, 'errors': 0},
            'mqtt': {'latencies': [], 'throughput': 0, 'errors': 0}
        }
        
    def test_http_performance(self, num_requests=1000, concurrent_requests=10):
        """HTTP API 성능 테스트"""
        print(f"=== HTTP API 성능 테스트 ===")
        print(f"요청 수: {num_requests}, 동시 요청: {concurrent_requests}")
        
        latencies = []
        errors = 0
        
        def send_http_request(request_id):
            try:
                data = {
                    'robot_id': request_id % 10,
                    'coordX': 100 + (request_id % 900),
                    'coordY': 200 + (request_id % 800),
                    'motorRPM': 1000 + (request_id % 2000),
                    'timestamp': time.time()
                }
                
                start_time = time.time()
                response = requests.post(
                    f"{self.http_base_url}/api/coordinate",
                    json=data,
                    timeout=5
                )
                end_time = time.time()
                
                latency_ms = (end_time - start_time) * 1000
                
                if response.status_code == 200:
                    return {'latency': latency_ms, 'error': False}
                else:
                    return {'latency': latency_ms, 'error': True}
                    
            except Exception as e:
                return {'latency': 0, 'error': True}
        
        start_time = time.time()
        
        # ThreadPoolExecutor로 동시 요청 처리
        with ThreadPoolExecutor(max_workers=concurrent_requests) as executor:
            futures = [executor.submit(send_http_request, i) for i in range(num_requests)]
            
            for i, future in enumerate(futures):
                result = future.result()
                
                if result['error']:
                    errors += 1
                else:
                    latencies.append(result['latency'])
                
                if (i + 1) % 100 == 0:
                    print(f"  HTTP Progress: {i + 1}/{num_requests}")
        
        total_time = time.time() - start_time
        successful_requests = len(latencies)
        throughput = successful_requests / total_time
        
        self.results['http'] = {
            'latencies': latencies,
            'throughput': throughput,
            'errors': errors,
            'total_time': total_time,
            'successful_requests': successful_requests
        }
        
        print(f"\n=== HTTP 결과 ===")
        print(f"총 처리시간: {total_time:.2f}초")
        print(f"성공한 요청: {successful_requests}/{num_requests}")
        print(f"에러율: {errors/num_requests*100:.2f}%")
        print(f"처리량: {throughput:.2f} req/sec")
        
        if latencies:
            print(f"평균 응답시간: {statistics.mean(latencies):.2f}ms")
            print(f"최소 응답시간: {min(latencies):.2f}ms") 
            print(f"최대 응답시간: {max(latencies):.2f}ms")
            print(f"95퍼센타일: {sorted(latencies)[int(len(latencies) * 0.95)]:.2f}ms")
    
    def test_mqtt_performance(self, num_messages=1000, concurrent_publishers=10):
        """MQTT 성능 테스트"""
        print(f"\n=== MQTT 성능 테스트 ===")
        print(f"메시지 수: {num_messages}, 동시 발행자: {concurrent_publishers}")
        
        latencies = []
        errors = 0
        messages_per_publisher = num_messages // concurrent_publishers
        
        def mqtt_publisher_thread(publisher_id):
            thread_latencies = []
            thread_errors = 0
            
            try:
                client = mqtt.Client(client_id=f"perf_test_{publisher_id}")
                client.connect(self.mqtt_host, self.mqtt_port, 60)
                
                for i in range(messages_per_publisher):
                    try:
                        robot_id = (publisher_id * 1000 + i) % 10
                        coord_x = 100 + (i % 900)
                        coord_y = 200 + (i % 800)
                        motor_rpm = 1000 + (i % 2000)
                        
                        # 좌표 X 발송
                        start_time = time.time()
                        result1 = client.publish(f"sensors/robot{robot_id}/coordX", str(coord_x))
                        result1.wait_for_publish(timeout=1)
                        
                        # 좌표 Y 발송
                        result2 = client.publish(f"sensors/robot{robot_id}/coordY", str(coord_y))
                        result2.wait_for_publish(timeout=1)
                        
                        # 모터 RPM 발송
                        result3 = client.publish(f"sensors/robot{robot_id}/motorRPM", str(motor_rpm))
                        result3.wait_for_publish(timeout=1)
                        
                        end_time = time.time()
                        
                        if result1.rc == mqtt.MQTT_ERR_SUCCESS and \
                           result2.rc == mqtt.MQTT_ERR_SUCCESS and \
                           result3.rc == mqtt.MQTT_ERR_SUCCESS:
                            latency_ms = (end_time - start_time) * 1000
                            thread_latencies.append(latency_ms)
                        else:
                            thread_errors += 1
                            
                    except Exception:
                        thread_errors += 1
                
                client.disconnect()
                
            except Exception:
                thread_errors = messages_per_publisher
            
            return thread_latencies, thread_errors
        
        start_time = time.time()
        
        # 여러 발행자 스레드로 동시 실행
        threads = []
        for i in range(concurrent_publishers):
            thread = threading.Thread(target=mqtt_publisher_thread, args=(i,))
            thread.start()
            threads.append(thread)
        
        # 모든 스레드 완료 대기 및 결과 수집
        all_latencies = []
        total_errors = 0
        
        with ThreadPoolExecutor(max_workers=concurrent_publishers) as executor:
            futures = [executor.submit(mqtt_publisher_thread, i) for i in range(concurrent_publishers)]
            
            for i, future in enumerate(futures):
                thread_latencies, thread_errors = future.result()
                all_latencies.extend(thread_latencies)
                total_errors += thread_errors
                
                progress = ((i + 1) * messages_per_publisher)
                print(f"  MQTT Progress: {progress}/{num_messages}")
        
        total_time = time.time() - start_time
        successful_messages = len(all_latencies)
        throughput = successful_messages / total_time
        
        self.results['mqtt'] = {
            'latencies': all_latencies,
            'throughput': throughput,
            'errors': total_errors,
            'total_time': total_time,
            'successful_messages': successful_messages
        }
        
        print(f"\n=== MQTT 결과 ===")
        print(f"총 처리시간: {total_time:.2f}초")
        print(f"성공한 메시지: {successful_messages}/{num_messages}")
        print(f"에러율: {total_errors/num_messages*100:.2f}%")
        print(f"처리량: {throughput:.2f} msg/sec")
        
        if all_latencies:
            print(f"평균 발송시간: {statistics.mean(all_latencies):.2f}ms")
            print(f"최소 발송시간: {min(all_latencies):.2f}ms")
            print(f"최대 발송시간: {max(all_latencies):.2f}ms")
            print(f"95퍼센타일: {sorted(all_latencies)[int(len(all_latencies) * 0.95)]:.2f}ms")
    
    def test_connection_overhead(self):
        """연결 오버헤드 비교"""
        print(f"\n=== 연결 오버헤드 비교 ===")
        
        # HTTP 연결 오버헤드
        http_times = []
        for i in range(10):
            start_time = time.time()
            try:
                response = requests.get(f"{self.http_base_url}/api/health", timeout=5)
                end_time = time.time()
                if response.status_code == 200:
                    http_times.append((end_time - start_time) * 1000)
            except:
                pass
        
        # MQTT 연결 오버헤드
        mqtt_times = []
        for i in range(10):
            start_time = time.time()
            try:
                client = mqtt.Client()
                client.connect(self.mqtt_host, self.mqtt_port, 60)
                client.disconnect()
                end_time = time.time()
                mqtt_times.append((end_time - start_time) * 1000)
            except:
                pass
        
        if http_times and mqtt_times:
            print(f"HTTP 평균 연결시간: {statistics.mean(http_times):.2f}ms")
            print(f"MQTT 평균 연결시간: {statistics.mean(mqtt_times):.2f}ms")
            print(f"MQTT가 HTTP보다 {statistics.mean(http_times)/statistics.mean(mqtt_times):.1f}배 빠름")
    
    def test_concurrent_connections(self, max_connections=100):
        """최대 동시 연결 수 테스트"""
        print(f"\n=== 최대 동시 연결 수 테스트 ===")
        
        # HTTP 동시 연결 테스트
        print("HTTP 동시 연결 테스트...")
        http_sessions = []
        http_max = 0
        
        for i in range(max_connections):
            try:
                session = requests.Session()
                response = session.get(f"{self.http_base_url}/api/health", timeout=1)
                if response.status_code == 200:
                    http_sessions.append(session)
                    http_max = i + 1
                else:
                    break
            except:
                break
            
            if i % 10 == 0:
                print(f"  HTTP 연결: {i + 1}/{max_connections}")
        
        # HTTP 세션 정리
        for session in http_sessions:
            try:
                session.close()
            except:
                pass
        
        # MQTT 동시 연결 테스트
        print("MQTT 동시 연결 테스트...")
        mqtt_clients = []
        mqtt_max = 0
        
        for i in range(max_connections):
            try:
                client = mqtt.Client(client_id=f"conn_test_{i}")
                client.connect(self.mqtt_host, self.mqtt_port, 60)
                mqtt_clients.append(client)
                mqtt_max = i + 1
            except:
                break
                
            if i % 10 == 0:
                print(f"  MQTT 연결: {i + 1}/{max_connections}")
        
        # MQTT 클라이언트 정리
        for client in mqtt_clients:
            try:
                client.disconnect()
            except:
                pass
        
        print(f"\nHTTP 최대 동시 연결: {http_max}")
        print(f"MQTT 최대 동시 연결: {mqtt_max}")
        print(f"MQTT가 HTTP보다 {mqtt_max/http_max:.1f}배 더 많은 동시 연결 지원")
    
    def print_comparison_summary(self):
        """비교 결과 요약"""
        if not self.results['http']['latencies'] or not self.results['mqtt']['latencies']:
            print("비교할 충분한 데이터가 없습니다.")
            return
            
        print(f"\n" + "="*60)
        print(f"{'항목':<20} {'HTTP':<15} {'MQTT':<15} {'MQTT 우위':<10}")
        print(f"="*60)
        
        # 처리량 비교
        http_tps = self.results['http']['throughput']
        mqtt_tps = self.results['mqtt']['throughput']
        tps_ratio = mqtt_tps / http_tps if http_tps > 0 else 0
        print(f"{'처리량(req/sec)':<20} {http_tps:<15.2f} {mqtt_tps:<15.2f} {tps_ratio:<10.1f}x")
        
        # 평균 지연시간 비교
        http_avg = statistics.mean(self.results['http']['latencies'])
        mqtt_avg = statistics.mean(self.results['mqtt']['latencies'])
        latency_ratio = http_avg / mqtt_avg
        print(f"{'평균 지연시간(ms)':<20} {http_avg:<15.2f} {mqtt_avg:<15.2f} {latency_ratio:<10.1f}x")
        
        # 95퍼센타일 비교
        http_95p = sorted(self.results['http']['latencies'])[int(len(self.results['http']['latencies']) * 0.95)]
        mqtt_95p = sorted(self.results['mqtt']['latencies'])[int(len(self.results['mqtt']['latencies']) * 0.95)]
        p95_ratio = http_95p / mqtt_95p
        print(f"{'95퍼센타일(ms)':<20} {http_95p:<15.2f} {mqtt_95p:<15.2f} {p95_ratio:<10.1f}x")
        
        # 에러율 비교
        http_error_rate = self.results['http']['errors'] / (self.results['http']['successful_requests'] + self.results['http']['errors']) * 100
        mqtt_error_rate = self.results['mqtt']['errors'] / (self.results['mqtt']['successful_messages'] + self.results['mqtt']['errors']) * 100
        print(f"{'에러율(%)':<20} {http_error_rate:<15.2f} {mqtt_error_rate:<15.2f} {'더 안정적' if mqtt_error_rate < http_error_rate else '덜 안정적'}")
        
        print(f"="*60)
        
        # 종합 결론
        print(f"\n=== 종합 결론 ===")
        if tps_ratio > 1 and latency_ratio > 1:
            print(f"✓ MQTT가 HTTP보다 {tps_ratio:.1f}배 빠른 처리량과 {latency_ratio:.1f}배 낮은 지연시간을 보임")
        elif tps_ratio > 1:
            print(f"✓ MQTT가 HTTP보다 {tps_ratio:.1f}배 높은 처리량을 보임")
        elif latency_ratio > 1:
            print(f"✓ MQTT가 HTTP보다 {latency_ratio:.1f}배 낮은 지연시간을 보임")
        else:
            print("HTTP와 MQTT 성능이 비슷하거나 테스트 환경에 따라 다름")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='HTTP vs MQTT 성능 비교')
    parser.add_argument('--mqtt-host', default='3.36.126.83', help='MQTT 브로커 호스트')
    parser.add_argument('--mqtt-port', type=int, default=3123, help='MQTT 브로커 포트')
    parser.add_argument('--http-url', default='http://3.36.126.83:8081', help='HTTP API 기본 URL')
    parser.add_argument('--requests', type=int, default=1000, help='테스트할 요청/메시지 수')
    parser.add_argument('--concurrent', type=int, default=10, help='동시 처리 수')
    parser.add_argument('--test', choices=['all', 'performance', 'connection', 'concurrent'], 
                       default='all', help='실행할 테스트 종류')
    
    args = parser.parse_args()
    
    comparator = HTTPvsMQTTComparison(
        mqtt_host=args.mqtt_host,
        mqtt_port=args.mqtt_port,
        http_base_url=args.http_url
    )
    
    try:
        if args.test in ['all', 'performance']:
            comparator.test_http_performance(args.requests, args.concurrent)
            comparator.test_mqtt_performance(args.requests, args.concurrent)
            comparator.print_comparison_summary()
        
        if args.test in ['all', 'connection']:
            comparator.test_connection_overhead()
            
        if args.test in ['all', 'concurrent']:
            comparator.test_concurrent_connections()
            
    except KeyboardInterrupt:
        print("\n테스트가 중단되었습니다.")
    except Exception as e:
        print(f"테스트 중 오류 발생: {e}")