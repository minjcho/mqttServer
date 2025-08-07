#!/usr/bin/env python3

import paho.mqtt.client as mqtt
import time
import random
import json
import threading
import statistics
from concurrent.futures import ThreadPoolExecutor
import argparse

def test_max_connections(broker_address="3.36.126.83", port=3123, max_connections=1000):
    """최대 동시 연결 수 테스트"""
    print(f"=== 최대 동시 연결 테스트 ===")
    print(f"목표 연결 수: {max_connections}")
    
    clients = []
    successful_connections = 0
    failed_connections = 0
    
    def create_connection(client_id):
        try:
            client = mqtt.Client(client_id=f"extreme_test_{client_id}")
            client.connect(broker_address, port, 60)
            client.loop_start()
            
            # 간단한 publish 테스트
            result = client.publish(f"test/{client_id}", f"hello_{client_id}")
            if result.rc == mqtt.MQTT_ERR_SUCCESS:
                return client, True
            else:
                client.disconnect()
                return None, False
                
        except Exception as e:
            return None, False
    
    print("연결 생성 중...")
    start_time = time.time()
    
    # 배치로 연결 생성 (메모리 절약)
    batch_size = 50
    total_successful = 0
    
    for batch_start in range(0, max_connections, batch_size):
        batch_end = min(batch_start + batch_size, max_connections)
        batch_clients = []
        
        with ThreadPoolExecutor(max_workers=20) as executor:
            futures = [executor.submit(create_connection, i) for i in range(batch_start, batch_end)]
            
            for future in futures:
                client, success = future.result()
                if success and client:
                    batch_clients.append(client)
                    total_successful += 1
                else:
                    failed_connections += 1
        
        clients.extend(batch_clients)
        print(f"  배치 {batch_start//batch_size + 1}: {len(batch_clients)}개 연결 성공, 총 {total_successful}개")
        
        # 메모리 관리: 이전 배치 정리
        if len(clients) > 200:  # 200개 이상 유지하지 않음
            for old_client in clients[:len(batch_clients)]:
                try:
                    old_client.disconnect()
                except:
                    pass
            clients = clients[len(batch_clients):]
    
    creation_time = time.time() - start_time
    
    print(f"\n=== 연결 테스트 결과 ===")
    print(f"연결 생성 시간: {creation_time:.2f}초")
    print(f"성공한 연결: {total_successful}")
    print(f"실패한 연결: {failed_connections}")
    print(f"성공률: {total_successful/max_connections*100:.1f}%")
    print(f"초당 연결 생성: {total_successful/creation_time:.1f} conn/sec")
    
    # 정리
    print("연결 정리 중...")
    for client in clients:
        try:
            client.disconnect()
        except:
            pass
    
    return total_successful

def test_message_flood(broker_address="3.36.126.83", port=3123, messages_per_second=5000, duration=10):
    """메시지 홍수 테스트"""
    print(f"\n=== 메시지 홍수 테스트 ===")
    print(f"목표 처리율: {messages_per_second} msg/sec")
    print(f"테스트 시간: {duration}초")
    
    total_messages = 0
    total_errors = 0
    latencies = []
    
    def message_sender(sender_id, target_rate):
        nonlocal total_messages, total_errors, latencies
        
        client = mqtt.Client(client_id=f"flood_{sender_id}")
        try:
            client.connect(broker_address, port)
            client.loop_start()
            
            interval = 1.0 / target_rate
            start_time = time.time()
            next_send = start_time
            
            while time.time() - start_time < duration:
                current_time = time.time()
                
                if current_time >= next_send:
                    data = {
                        "sender_id": sender_id,
                        "timestamp": int(current_time * 1000),
                        "data": f"flood_test_{total_messages}"
                    }
                    
                    send_start = time.time()
                    result = client.publish(f"flood/{sender_id}", json.dumps(data))
                    
                    if result.rc == mqtt.MQTT_ERR_SUCCESS:
                        send_end = time.time()
                        latencies.append((send_end - send_start) * 1000)
                        total_messages += 1
                    else:
                        total_errors += 1
                    
                    next_send += interval
                
                time.sleep(0.0001)  # 0.1ms
            
            client.disconnect()
            
        except Exception as e:
            total_errors += 1
    
    # 여러 발송자로 분산
    num_senders = min(20, messages_per_second // 100)  # 최대 20개 발송자
    rate_per_sender = messages_per_second / num_senders
    
    print(f"발송자 수: {num_senders}, 발송자당 목표: {rate_per_sender:.1f} msg/sec")
    
    start_time = time.time()
    
    with ThreadPoolExecutor(max_workers=num_senders) as executor:
        futures = [executor.submit(message_sender, i, rate_per_sender) for i in range(num_senders)]
        
        for future in futures:
            future.result()
    
    total_time = time.time() - start_time
    actual_rate = total_messages / total_time
    
    print(f"\n=== 홍수 테스트 결과 ===")
    print(f"총 처리시간: {total_time:.2f}초")
    print(f"발송된 메시지: {total_messages}")
    print(f"에러 수: {total_errors}")
    print(f"목표 처리율: {messages_per_second} msg/sec")
    print(f"실제 처리율: {actual_rate:.2f} msg/sec")
    print(f"달성률: {actual_rate/messages_per_second*100:.1f}%")
    
    if latencies:
        print(f"평균 발송시간: {statistics.mean(latencies):.2f}ms")
        print(f"최대 발송시간: {max(latencies):.2f}ms")
        print(f"95퍼센타일: {sorted(latencies)[int(len(latencies) * 0.95)]:.2f}ms")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='극한 부하 테스트')
    parser.add_argument('--broker', default='3.36.126.83', help='MQTT 브로커 주소')
    parser.add_argument('--port', type=int, default=3123, help='MQTT 브로커 포트')
    parser.add_argument('--connections', type=int, default=1000, help='최대 연결 수')
    parser.add_argument('--rate', type=int, default=5000, help='초당 메시지 수')
    parser.add_argument('--duration', type=int, default=10, help='테스트 지속시간')
    
    args = parser.parse_args()
    
    print("⚠️  극한 부하 테스트를 시작합니다.")
    
    try:
        # 연결 수 테스트
        max_conn = test_max_connections(args.broker, args.port, args.connections)
        
        # 메시지 홍수 테스트
        test_message_flood(args.broker, args.port, args.rate, args.duration)
        
        print(f"\n=== 종합 결과 ===")
        print(f"최대 동시 연결: {max_conn}개")
        print(f"권장 운영 규모: {max_conn * 0.7:.0f}개 연결 (70% 여유)")
        
    except KeyboardInterrupt:
        print("\n🛑 테스트가 중단되었습니다.")
    except Exception as e:
        print(f"❌ 테스트 중 오류: {e}")