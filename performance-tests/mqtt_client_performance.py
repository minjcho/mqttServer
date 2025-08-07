#!/usr/bin/env python3

import paho.mqtt.client as mqtt
import time
import random
import json
import threading
import statistics
import argparse
from concurrent.futures import ThreadPoolExecutor
from collections import defaultdict

class MQTTClientPerformanceTester:
    def __init__(self, broker_address="3.36.126.83", port=3123):
        self.broker_address = broker_address
        self.port = port
        self.results = {
            'publish_latencies': [],
            'command_latencies': [],
            'messages_sent': 0,
            'commands_received': 0,
            'errors': 0
        }
        
    def test_coordinate_publishing(self, orin_ids=["orin123"], duration=30, publish_interval=1):
        """좌표 데이터 발송 성능 테스트"""
        print(f"=== 좌표 발송 성능 테스트 ===")
        print(f"ORIN IDs: {orin_ids}")
        print(f"테스트 시간: {duration}초")
        print(f"발송 간격: {publish_interval}초")
        
        orin_states = {orin_id: {"following": False} for orin_id in orin_ids}
        publish_latencies = []
        messages_sent = 0
        errors = 0
        
        def on_connect(client, userdata, flags, rc):
            if rc == 0:
                print(f"✅ MQTT 브로커 연결됨 (코드: {rc})")
                # commands 토픽 구독
                for orin_id in orin_ids:
                    topic = f"commands/{orin_id}"
                    client.subscribe(topic)
                    print(f"📥 구독: {topic}")
            else:
                print(f"❌ 연결 실패 (코드: {rc})")
        
        def on_message(client, userdata, msg):
            try:
                topic = msg.topic
                payload = msg.payload.decode()
                orin_id = topic.split("/")[1]
                
                if payload == "following":
                    orin_states[orin_id]["following"] = True
                    print(f"🎯 [{orin_id}] Following 명령 수신!")
            except Exception as e:
                print(f"❌ 메시지 처리 오류: {e}")
        
        client = mqtt.Client()
        client.on_connect = on_connect
        client.on_message = on_message
        
        try:
            client.connect(self.broker_address, self.port)
            client.loop_start()
            
            start_time = time.time()
            test_end_time = start_time + duration
            
            message_count = 0
            
            while time.time() < test_end_time:
                loop_start = time.time()
                
                for orin_id in orin_ids:
                    coord_x = round(random.uniform(0, 1000), 2)
                    coord_y = round(random.uniform(0, 1000), 2)
                    
                    topic_coords = f"sensors/{orin_id}/coordinates"
                    
                    payload = json.dumps({
                        "orinId": orin_id,
                        "coordX": coord_x,
                        "coordY": coord_y,
                        "timestamp": int(time.time() * 1000),
                        "following": orin_states[orin_id]["following"]
                    })
                    
                    publish_start = time.time()
                    result = client.publish(topic_coords, payload)
                    
                    if result.rc == mqtt.MQTT_ERR_SUCCESS:
                        publish_end = time.time()
                        latency = (publish_end - publish_start) * 1000
                        publish_latencies.append(latency)
                        messages_sent += 1
                    else:
                        errors += 1
                    
                    message_count += 1
                    
                    status = "🟢 FOLLOWING" if orin_states[orin_id]["following"] else "⚪ NORMAL"
                    if message_count % 10 == 0:
                        print(f"📍 [{message_count:04d}] {orin_id} {status}: X={coord_x:7.2f}, Y={coord_y:7.2f}")
                
                # 정확한 간격 유지
                elapsed = time.time() - loop_start
                if elapsed < publish_interval:
                    time.sleep(publish_interval - elapsed)
            
            client.loop_stop()
            client.disconnect()
            
        except Exception as e:
            print(f"❌ 테스트 중 오류: {e}")
            errors += 1
        
        total_time = time.time() - start_time
        
        self.results.update({
            'publish_latencies': publish_latencies,
            'messages_sent': messages_sent,
            'errors': errors,
            'total_time': total_time,
            'throughput': messages_sent / total_time if total_time > 0 else 0
        })
        
        print(f"\n=== 좌표 발송 테스트 결과 ===")
        print(f"총 처리시간: {total_time:.2f}초")
        print(f"발송된 메시지: {messages_sent}")
        print(f"에러 수: {errors}")
        print(f"처리량: {self.results['throughput']:.2f} msg/sec")
        
        if publish_latencies:
            print(f"평균 발송시간: {statistics.mean(publish_latencies):.2f}ms")
            print(f"최소 발송시간: {min(publish_latencies):.2f}ms")
            print(f"최대 발송시간: {max(publish_latencies):.2f}ms")
            print(f"95퍼센타일: {sorted(publish_latencies)[int(len(publish_latencies) * 0.95)]:.2f}ms")
    
    def test_concurrent_orins(self, num_orins=5, duration=30):
        """다중 ORIN 동시 테스트"""
        print(f"\n=== 다중 ORIN 동시 테스트 ===")
        print(f"ORIN 수: {num_orins}")
        print(f"테스트 시간: {duration}초")
        
        orin_ids = [f"ORIN{i:03d}" for i in range(1, num_orins + 1)]
        
        results = {}
        threads = []
        
        def test_single_orin(orin_id):
            client = mqtt.Client(client_id=f"test_{orin_id}")
            messages_sent = 0
            errors = 0
            latencies = []
            
            try:
                client.connect(self.broker_address, self.port)
                client.loop_start()
                
                start_time = time.time()
                test_end_time = start_time + duration
                
                while time.time() < test_end_time:
                    coord_x = round(random.uniform(0, 1000), 2)
                    coord_y = round(random.uniform(0, 1000), 2)
                    
                    topic_coords = f"sensors/{orin_id}/coordinates"
                    
                    payload = json.dumps({
                        "orinId": orin_id,
                        "coordX": coord_x,
                        "coordY": coord_y,
                        "timestamp": int(time.time() * 1000),
                        "following": False
                    })
                    
                    publish_start = time.time()
                    result = client.publish(topic_coords, payload)
                    
                    if result.rc == mqtt.MQTT_ERR_SUCCESS:
                        publish_end = time.time()
                        latency = (publish_end - publish_start) * 1000
                        latencies.append(latency)
                        messages_sent += 1
                    else:
                        errors += 1
                    
                    time.sleep(1)  # 1초 간격
                
                client.loop_stop()
                client.disconnect()
                
            except Exception as e:
                print(f"❌ {orin_id} 오류: {e}")
                errors += 1
            
            total_time = time.time() - start_time
            
            results[orin_id] = {
                'messages_sent': messages_sent,
                'errors': errors,
                'latencies': latencies,
                'throughput': messages_sent / total_time if total_time > 0 else 0
            }
            
            print(f"✓ {orin_id}: {messages_sent}개 메시지 발송 완료")
        
        # 모든 ORIN을 동시에 시작
        start_time = time.time()
        
        with ThreadPoolExecutor(max_workers=num_orins) as executor:
            futures = [executor.submit(test_single_orin, orin_id) for orin_id in orin_ids]
            
            for future in futures:
                future.result()  # 모든 작업 완료 대기
        
        total_time = time.time() - start_time
        
        # 결과 집계
        total_messages = sum(result['messages_sent'] for result in results.values())
        total_errors = sum(result['errors'] for result in results.values())
        all_latencies = []
        for result in results.values():
            all_latencies.extend(result['latencies'])
        
        print(f"\n=== 다중 ORIN 테스트 결과 ===")
        print(f"총 처리시간: {total_time:.2f}초")
        print(f"총 발송 메시지: {total_messages}")
        print(f"총 에러: {total_errors}")
        print(f"전체 처리량: {total_messages / total_time:.2f} msg/sec")
        
        if all_latencies:
            print(f"전체 평균 발송시간: {statistics.mean(all_latencies):.2f}ms")
            print(f"전체 95퍼센타일: {sorted(all_latencies)[int(len(all_latencies) * 0.95)]:.2f}ms")
        
        print(f"\n=== ORIN별 상세 결과 ===")
        for orin_id, result in results.items():
            print(f"{orin_id}: {result['messages_sent']}개 메시지, {result['throughput']:.2f} msg/sec")
    
    def test_command_response_time(self, orin_ids=["orin123"], num_commands=100):
        """명령 응답 시간 테스트"""
        print(f"\n=== 명령 응답 시간 테스트 ===")
        print(f"ORIN IDs: {orin_ids}")
        print(f"명령 수: {num_commands}")
        
        command_times = {}
        received_commands = 0
        
        def on_connect(client, userdata, flags, rc):
            if rc == 0:
                print(f"✅ 명령 테스트 클라이언트 연결됨")
                for orin_id in orin_ids:
                    topic = f"commands/{orin_id}"
                    client.subscribe(topic)
                    print(f"📥 구독: {topic}")
        
        def on_message(client, userdata, msg):
            nonlocal received_commands
            try:
                topic = msg.topic
                payload = msg.payload.decode()
                orin_id = topic.split("/")[1]
                
                if payload == "following":
                    receive_time = time.time()
                    if orin_id in command_times:
                        response_time = (receive_time - command_times[orin_id]) * 1000
                        print(f"🎯 [{orin_id}] 응답시간: {response_time:.2f}ms")
                        received_commands += 1
            except Exception as e:
                print(f"❌ 메시지 처리 오류: {e}")
        
        # 수신 클라이언트
        client = mqtt.Client(client_id="command_tester")
        client.on_connect = on_connect
        client.on_message = on_message
        
        try:
            client.connect(self.broker_address, self.port)
            client.loop_start()
            
            time.sleep(2)  # 연결 안정화
            
            # 명령 발송 클라이언트
            cmd_client = mqtt.Client(client_id="command_sender")
            cmd_client.connect(self.broker_address, self.port)
            
            for i in range(num_commands):
                for orin_id in orin_ids:
                    command_times[orin_id] = time.time()
                    topic = f"commands/{orin_id}"
                    cmd_client.publish(topic, "following")
                    
                    print(f"📤 [{i+1}] 명령 발송: {topic}")
                    time.sleep(0.1)  # 0.1초 간격
            
            # 응답 대기
            time.sleep(5)
            
            cmd_client.disconnect()
            client.loop_stop()
            client.disconnect()
            
        except Exception as e:
            print(f"❌ 명령 테스트 중 오류: {e}")
        
        print(f"\n=== 명령 응답 테스트 결과 ===")
        print(f"발송한 명령: {num_commands * len(orin_ids)}")
        print(f"수신한 응답: {received_commands}")
        print(f"응답률: {received_commands / (num_commands * len(orin_ids)) * 100:.1f}%")

    def test_stress_load(self, orin_ids=["orin123"], messages_per_second=10, duration=60):
        """스트레스 부하 테스트"""
        print(f"\n=== 스트레스 부하 테스트 ===")
        print(f"ORIN IDs: {orin_ids}")
        print(f"초당 메시지: {messages_per_second}")
        print(f"테스트 시간: {duration}초")
        
        interval = 1.0 / messages_per_second
        
        client = mqtt.Client()
        
        messages_sent = 0
        errors = 0
        latencies = []
        
        try:
            client.connect(self.broker_address, self.port)
            client.loop_start()
            
            start_time = time.time()
            test_end_time = start_time + duration
            next_send_time = start_time
            
            while time.time() < test_end_time:
                current_time = time.time()
                
                if current_time >= next_send_time:
                    for orin_id in orin_ids:
                        coord_x = round(random.uniform(0, 1000), 2)
                        coord_y = round(random.uniform(0, 1000), 2)
                        
                        topic_coords = f"sensors/{orin_id}/coordinates"
                        
                        payload = json.dumps({
                            "orinId": orin_id,
                            "coordX": coord_x,
                            "coordY": coord_y,
                            "timestamp": int(time.time() * 1000),
                            "following": False
                        })
                        
                        publish_start = time.time()
                        result = client.publish(topic_coords, payload)
                        
                        if result.rc == mqtt.MQTT_ERR_SUCCESS:
                            publish_end = time.time()
                            latency = (publish_end - publish_start) * 1000
                            latencies.append(latency)
                            messages_sent += 1
                        else:
                            errors += 1
                    
                    next_send_time += interval
                    
                    if messages_sent % (messages_per_second * 10) == 0:
                        elapsed = time.time() - start_time
                        current_rate = messages_sent / elapsed
                        print(f"📈 진행률: {elapsed/duration*100:.1f}% - {current_rate:.1f} msg/sec")
                
                time.sleep(0.001)  # 1ms 대기
            
            client.loop_stop()
            client.disconnect()
            
        except Exception as e:
            print(f"❌ 스트레스 테스트 중 오류: {e}")
            errors += 1
        
        total_time = time.time() - start_time
        actual_rate = messages_sent / total_time
        
        print(f"\n=== 스트레스 테스트 결과 ===")
        print(f"총 처리시간: {total_time:.2f}초")
        print(f"발송된 메시지: {messages_sent}")
        print(f"에러 수: {errors}")
        print(f"목표 처리율: {messages_per_second * len(orin_ids)} msg/sec")
        print(f"실제 처리율: {actual_rate:.2f} msg/sec")
        print(f"달성률: {actual_rate / (messages_per_second * len(orin_ids)) * 100:.1f}%")
        
        if latencies:
            print(f"평균 발송시간: {statistics.mean(latencies):.2f}ms")
            print(f"최대 발송시간: {max(latencies):.2f}ms")
            print(f"95퍼센타일: {sorted(latencies)[int(len(latencies) * 0.95)]:.2f}ms")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='MQTT 클라이언트 성능 테스트')
    parser.add_argument('--broker', default='3.36.126.83', help='MQTT 브로커 주소')
    parser.add_argument('--port', type=int, default=3123, help='MQTT 브로커 포트')
    parser.add_argument('--test', choices=['all', 'coordinate', 'concurrent', 'command', 'stress'], 
                       default='all', help='실행할 테스트 종류')
    parser.add_argument('--duration', type=int, default=30, help='테스트 지속 시간(초)')
    parser.add_argument('--orins', type=int, default=5, help='테스트할 ORIN 수')
    parser.add_argument('--rate', type=int, default=10, help='초당 메시지 수 (스트레스 테스트)')
    
    args = parser.parse_args()
    
    tester = MQTTClientPerformanceTester(args.broker, args.port)
    
    try:
        if args.test in ['all', 'coordinate']:
            tester.test_coordinate_publishing(duration=args.duration)
        
        if args.test in ['all', 'concurrent']:
            tester.test_concurrent_orins(num_orins=args.orins, duration=args.duration)
        
        if args.test in ['all', 'command']:
            tester.test_command_response_time(num_commands=50)
        
        if args.test in ['all', 'stress']:
            tester.test_stress_load(messages_per_second=args.rate, duration=args.duration)
            
    except KeyboardInterrupt:
        print("\n🛑 사용자에 의해 중단됨")
    except Exception as e:
        print(f"❌ 테스트 중 오류 발생: {e}")