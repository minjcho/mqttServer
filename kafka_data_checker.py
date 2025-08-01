#!/usr/bin/env python3
"""
카프카 데이터 확인 도구
Kafka Data Checker Tool
"""

import json
import time
from kafka import KafkaConsumer, KafkaProducer
from kafka.admin import KafkaAdminClient, NewTopic
import redis

class KafkaDataChecker:
    def __init__(self):
        self.bootstrap_servers = ['localhost:9092']
        self.redis_host = 'localhost'
        self.redis_port = 6379
        
    def check_kafka_connection(self):
        """카프카 연결 확인"""
        try:
            admin_client = KafkaAdminClient(
                bootstrap_servers=self.bootstrap_servers,
                request_timeout_ms=5000
            )
            metadata = admin_client.describe_cluster()
            print("✅ 카프카 연결 성공")
            return True
        except Exception as e:
            print(f"❌ 카프카 연결 실패: {e}")
            return False
    
    def list_topics(self):
        """모든 토픽 목록 확인"""
        try:
            admin_client = KafkaAdminClient(bootstrap_servers=self.bootstrap_servers)
            topics = admin_client.list_topics()
            print(f"📋 사용 가능한 토픽: {list(topics)}")
            return list(topics)
        except Exception as e:
            print(f"❌ 토픽 목록 확인 실패: {e}")
            return []
    
    def check_topic_details(self, topic_name):
        """특정 토픽의 상세 정보 확인"""
        try:
            consumer = KafkaConsumer(
                bootstrap_servers=self.bootstrap_servers,
                consumer_timeout_ms=5000
            )
            
            partitions = consumer.partitions_for_topic(topic_name)
            if partitions:
                print(f"📊 토픽 '{topic_name}' 파티션: {list(partitions)}")
                
                # 각 파티션의 오프셋 정보 확인
                from kafka import TopicPartition
                topic_partitions = [TopicPartition(topic_name, p) for p in partitions]
                
                # 시작 오프셋
                beginning_offsets = consumer.beginning_offsets(topic_partitions)
                # 끝 오프셋
                end_offsets = consumer.end_offsets(topic_partitions)
                
                print(f"📈 오프셋 정보:")
                for tp in topic_partitions:
                    start = beginning_offsets.get(tp, 0)
                    end = end_offsets.get(tp, 0)
                    message_count = end - start
                    print(f"  파티션 {tp.partition}: 시작={start}, 끝={end}, 메시지 수={message_count}")
            else:
                print(f"⚠️ 토픽 '{topic_name}'에 파티션이 없습니다")
                
            consumer.close()
        except Exception as e:
            print(f"❌ 토픽 상세 정보 확인 실패: {e}")
    
    def consume_messages(self, topic_name, max_messages=10):
        """메시지 소비하여 내용 확인"""
        print(f"🔍 토픽 '{topic_name}'에서 최대 {max_messages}개 메시지 확인 중...")
        
        try:
            consumer = KafkaConsumer(
                topic_name,
                bootstrap_servers=self.bootstrap_servers,
                auto_offset_reset='earliest',
                group_id=f'checker-group-{int(time.time())}',
                value_deserializer=lambda x: x.decode('utf-8') if x else None,
                consumer_timeout_ms=10000
            )
            
            message_count = 0
            for message in consumer:
                message_count += 1
                print(f"\n📨 메시지 #{message_count}:")
                print(f"  토픽: {message.topic}")
                print(f"  파티션: {message.partition}")
                print(f"  오프셋: {message.offset}")
                print(f"  키: {message.key}")
                print(f"  값: {message.value}")
                print(f"  타임스탬프: {message.timestamp}")
                print("-" * 50)
                
                if message_count >= max_messages:
                    break
            
            if message_count == 0:
                print("📭 메시지가 없습니다")
            else:
                print(f"✅ 총 {message_count}개 메시지 확인 완료")
                
            consumer.close()
            
        except Exception as e:
            print(f"❌ 메시지 소비 실패: {e}")
    
    def send_test_message(self, topic_name, test_message):
        """테스트 메시지 전송"""
        try:
            producer = KafkaProducer(
                bootstrap_servers=self.bootstrap_servers,
                value_serializer=lambda x: x.encode('utf-8')
            )
            
            future = producer.send(topic_name, test_message)
            result = future.get(timeout=10)
            
            print(f"✅ 테스트 메시지 전송 성공:")
            print(f"  토픽: {result.topic}")
            print(f"  파티션: {result.partition}")
            print(f"  오프셋: {result.offset}")
            
            producer.close()
            return True
            
        except Exception as e:
            print(f"❌ 테스트 메시지 전송 실패: {e}")
            return False
    
    def check_redis_data(self):
        """Redis에 저장된 데이터 확인"""
        try:
            redis_client = redis.Redis(
                host=self.redis_host,
                port=self.redis_port,
                db=0,
                decode_responses=True
            )
            
            redis_client.ping()
            print("✅ Redis 연결 성공")
            
            # 모든 키 확인
            keys = redis_client.keys("*")
            print(f"🗂️ Redis 키 개수: {len(keys)}")
            
            if keys:
                print("📋 Redis 키 목록:")
                for key in keys[:10]:  # 최대 10개만 표시
                    key_type = redis_client.type(key)
                    print(f"  {key} ({key_type})")
                    
                    # 일부 데이터 내용 표시
                    if key_type == 'string':
                        value = redis_client.get(key)
                        print(f"    값: {value[:100]}...")
                    elif key_type == 'hash':
                        hash_data = redis_client.hgetall(key)
                        print(f"    해시 필드 수: {len(hash_data)}")
                        
                if len(keys) > 10:
                    print(f"  ... 및 {len(keys) - 10}개 더")
            else:
                print("📭 Redis에 데이터가 없습니다")
                
        except Exception as e:
            print(f"❌ Redis 확인 실패: {e}")
    
    def run_comprehensive_check(self):
        """종합 데이터 확인"""
        print("🚀 카프카 데이터 종합 확인 시작")
        print("=" * 60)
        
        # 1. 카프카 연결 확인
        print("\n1️⃣ 카프카 연결 확인")
        if not self.check_kafka_connection():
            return
        
        # 2. 토픽 목록 확인
        print("\n2️⃣ 토픽 목록 확인")
        topics = self.list_topics()
        
        # 3. 각 토픽 상세 정보 확인
        print("\n3️⃣ 토픽 상세 정보 확인")
        for topic in topics:
            print(f"\n--- 토픽: {topic} ---")
            self.check_topic_details(topic)
        
        # 4. 메시지 내용 확인
        print("\n4️⃣ 메시지 내용 확인")
        for topic in topics:
            print(f"\n--- 토픽 '{topic}' 메시지 확인 ---")
            self.consume_messages(topic, max_messages=5)
        
        # 5. Redis 데이터 확인
        print("\n5️⃣ Redis 데이터 확인")
        self.check_redis_data()
        
        print("\n" + "=" * 60)
        print("✅ 종합 확인 완료")

def main():
    checker = KafkaDataChecker()
    
    import sys
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == "topics":
            checker.list_topics()
        elif command == "messages":
            topic = sys.argv[2] if len(sys.argv) > 2 else "mqtt-messages"
            max_msgs = int(sys.argv[3]) if len(sys.argv) > 3 else 10
            checker.consume_messages(topic, max_msgs)
        elif command == "redis":
            checker.check_redis_data()
        elif command == "test":
            topic = sys.argv[2] if len(sys.argv) > 2 else "mqtt-messages"
            message = sys.argv[3] if len(sys.argv) > 3 else f"테스트 메시지 - {time.time()}"
            checker.send_test_message(topic, message)
        elif command == "check":
            topic = sys.argv[2] if len(sys.argv) > 2 else "mqtt-messages"
            checker.check_topic_details(topic)
        else:
            print("사용법:")
            print("  python kafka_data_checker.py topics          # 토픽 목록")
            print("  python kafka_data_checker.py messages [토픽] [개수]  # 메시지 확인")
            print("  python kafka_data_checker.py redis           # Redis 데이터")
            print("  python kafka_data_checker.py test [토픽] [메시지]    # 테스트 메시지 전송")
            print("  python kafka_data_checker.py check [토픽]    # 토픽 상세 정보")
    else:
        # 인수가 없으면 종합 확인 실행
        checker.run_comprehensive_check()

if __name__ == "__main__":
    main()