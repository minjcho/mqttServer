#!/usr/bin/env python3

import redis
import time
import threading
import statistics
import argparse
import json
from concurrent.futures import ThreadPoolExecutor
import random
import string

class RedisBenchmark:
    def __init__(self, host='3.36.126.83', port=6379, db=0):
        self.redis_client = redis.Redis(host=host, port=port, db=db, decode_responses=True)
        self.results = {
            'set_latencies': [],
            'get_latencies': [],
            'pipeline_latencies': []
        }
        
    def test_basic_operations(self, num_operations=10000):
        """기본 SET/GET 연산 성능 테스트"""
        print(f"=== Redis 기본 연산 성능 테스트 ({num_operations}회) ===")
        
        # SET 연산 테스트
        print("SET 연산 테스트 중...")
        set_latencies = []
        
        start_time = time.time()
        for i in range(num_operations):
            key = f"test_key_{i}"
            value = f"test_value_{i}_{time.time()}"
            
            op_start = time.time()
            self.redis_client.set(key, value)
            op_end = time.time()
            
            latency_ms = (op_end - op_start) * 1000
            set_latencies.append(latency_ms)
            
            if i % 1000 == 0:
                print(f"  SET Progress: {i}/{num_operations}")
        
        set_duration = time.time() - start_time
        set_tps = num_operations / set_duration
        
        # GET 연산 테스트
        print("GET 연산 테스트 중...")
        get_latencies = []
        
        start_time = time.time()
        for i in range(num_operations):
            key = f"test_key_{i}"
            
            op_start = time.time()
            self.redis_client.get(key)
            op_end = time.time()
            
            latency_ms = (op_end - op_start) * 1000
            get_latencies.append(latency_ms)
            
            if i % 1000 == 0:
                print(f"  GET Progress: {i}/{num_operations}")
        
        get_duration = time.time() - start_time
        get_tps = num_operations / get_duration
        
        # 결과 출력
        print(f"\n=== SET 연산 결과 ===")
        print(f"총 처리시간: {set_duration:.2f}초")
        print(f"TPS: {set_tps:.2f} ops/sec")
        print(f"평균 지연시간: {statistics.mean(set_latencies):.3f}ms")
        print(f"최소 지연시간: {min(set_latencies):.3f}ms")
        print(f"최대 지연시간: {max(set_latencies):.3f}ms")
        print(f"95퍼센타일: {sorted(set_latencies)[int(len(set_latencies) * 0.95)]:.3f}ms")
        
        print(f"\n=== GET 연산 결과 ===")
        print(f"총 처리시간: {get_duration:.2f}초")
        print(f"TPS: {get_tps:.2f} ops/sec")
        print(f"평균 지연시간: {statistics.mean(get_latencies):.3f}ms")
        print(f"최소 지연시간: {min(get_latencies):.3f}ms")
        print(f"최대 지연시간: {max(get_latencies):.3f}ms")
        print(f"95퍼센타일: {sorted(get_latencies)[int(len(get_latencies) * 0.95)]:.3f}ms")
        
        self.results['set_latencies'] = set_latencies
        self.results['get_latencies'] = get_latencies
        
    def test_pipeline_performance(self, pipeline_size=100, num_pipelines=100):
        """파이프라인 성능 테스트"""
        print(f"=== Redis 파이프라인 성능 테스트 ===")
        print(f"파이프라인 크기: {pipeline_size}, 파이프라인 수: {num_pipelines}")
        
        pipeline_latencies = []
        total_operations = pipeline_size * num_pipelines
        
        start_time = time.time()
        
        for batch in range(num_pipelines):
            pipe_start = time.time()
            
            # 파이프라인 생성
            pipe = self.redis_client.pipeline()
            
            # 배치로 명령 추가
            for i in range(pipeline_size):
                key = f"pipeline_key_{batch}_{i}"
                value = f"pipeline_value_{batch}_{i}"
                pipe.set(key, value)
                pipe.get(key)
            
            # 파이프라인 실행
            pipe.execute()
            
            pipe_end = time.time()
            pipeline_latency = (pipe_end - pipe_start) * 1000
            pipeline_latencies.append(pipeline_latency)
            
            if batch % 10 == 0:
                print(f"  Pipeline Progress: {batch}/{num_pipelines}")
        
        total_duration = time.time() - start_time
        total_tps = total_operations / total_duration
        
        print(f"\n=== 파이프라인 결과 ===")
        print(f"총 연산 수: {total_operations}")
        print(f"총 처리시간: {total_duration:.2f}초")
        print(f"TPS: {total_tps:.2f} ops/sec")
        print(f"평균 파이프라인 지연시간: {statistics.mean(pipeline_latencies):.3f}ms")
        print(f"파이프라인 처리량: {num_pipelines / total_duration:.2f} pipelines/sec")
        
        self.results['pipeline_latencies'] = pipeline_latencies
        
    def test_concurrent_access(self, num_threads=10, operations_per_thread=1000):
        """동시 접근 성능 테스트"""
        print(f"=== Redis 동시 접근 성능 테스트 ===")
        print(f"스레드 수: {num_threads}, 스레드당 연산 수: {operations_per_thread}")
        
        results = []
        
        def worker_thread(thread_id):
            thread_results = []
            client = redis.Redis(host=self.redis_client.connection_pool.connection_kwargs['host'],
                               port=self.redis_client.connection_pool.connection_kwargs['port'],
                               decode_responses=True)
            
            for i in range(operations_per_thread):
                key = f"concurrent_key_{thread_id}_{i}"
                value = f"concurrent_value_{thread_id}_{i}"
                
                # SET 연산
                start_time = time.time()
                client.set(key, value)
                set_time = time.time()
                
                # GET 연산
                retrieved_value = client.get(key)
                get_time = time.time()
                
                set_latency = (set_time - start_time) * 1000
                get_latency = (get_time - set_time) * 1000
                
                thread_results.append({
                    'set_latency': set_latency,
                    'get_latency': get_latency
                })
            
            return thread_results
        
        # 스레드풀로 동시 실행
        start_time = time.time()
        with ThreadPoolExecutor(max_workers=num_threads) as executor:
            futures = [executor.submit(worker_thread, i) for i in range(num_threads)]
            
            for future in futures:
                results.extend(future.result())
        
        end_time = time.time()
        total_duration = end_time - start_time
        total_operations = len(results) * 2  # SET + GET
        total_tps = total_operations / total_duration
        
        set_latencies = [r['set_latency'] for r in results]
        get_latencies = [r['get_latency'] for r in results]
        
        print(f"\n=== 동시 접근 결과 ===")
        print(f"총 스레드 수: {num_threads}")
        print(f"총 연산 수: {total_operations}")
        print(f"총 처리시간: {total_duration:.2f}초")
        print(f"전체 TPS: {total_tps:.2f} ops/sec")
        print(f"스레드당 평균 TPS: {total_tps/num_threads:.2f} ops/sec")
        
        print(f"\nSET 연산 동시성:")
        print(f"  평균 지연시간: {statistics.mean(set_latencies):.3f}ms")
        print(f"  95퍼센타일: {sorted(set_latencies)[int(len(set_latencies) * 0.95)]:.3f}ms")
        
        print(f"\nGET 연산 동시성:")
        print(f"  평균 지연시간: {statistics.mean(get_latencies):.3f}ms")
        print(f"  95퍼센타일: {sorted(get_latencies)[int(len(get_latencies) * 0.95)]:.3f}ms")
        
    def test_data_structures(self, num_operations=1000):
        """Redis 데이터 구조별 성능 테스트"""
        print(f"=== Redis 데이터 구조별 성능 테스트 ===")
        
        # Hash 테스트
        print("Hash 구조 테스트 중...")
        hash_start = time.time()
        for i in range(num_operations):
            self.redis_client.hset(f"hash_key_{i}", "field1", f"value1_{i}")
            self.redis_client.hset(f"hash_key_{i}", "field2", f"value2_{i}")
            self.redis_client.hget(f"hash_key_{i}", "field1")
        hash_duration = time.time() - hash_start
        hash_tps = (num_operations * 3) / hash_duration
        
        # List 테스트
        print("List 구조 테스트 중...")
        list_start = time.time()
        for i in range(num_operations):
            self.redis_client.lpush(f"list_key_{i}", f"item1_{i}")
            self.redis_client.lpush(f"list_key_{i}", f"item2_{i}")
            self.redis_client.lpop(f"list_key_{i}")
        list_duration = time.time() - list_start
        list_tps = (num_operations * 3) / list_duration
        
        # Set 테스트
        print("Set 구조 테스트 중...")
        set_start = time.time()
        for i in range(num_operations):
            self.redis_client.sadd(f"set_key_{i}", f"member1_{i}")
            self.redis_client.sadd(f"set_key_{i}", f"member2_{i}")
            self.redis_client.sismember(f"set_key_{i}", f"member1_{i}")
        set_duration = time.time() - set_start
        set_tps = (num_operations * 3) / set_duration
        
        print(f"\n=== 데이터 구조별 결과 ===")
        print(f"Hash TPS: {hash_tps:.2f} ops/sec")
        print(f"List TPS: {list_tps:.2f} ops/sec")
        print(f"Set TPS: {set_tps:.2f} ops/sec")
        
    def test_memory_usage(self):
        """메모리 사용량 분석"""
        print("=== Redis 메모리 사용량 분석 ===")
        
        info = self.redis_client.info('memory')
        
        print(f"사용 중인 메모리: {info['used_memory_human']}")
        print(f"RSS 메모리: {info['used_memory_rss_human']}")
        print(f"피크 메모리: {info['used_memory_peak_human']}")
        print(f"메모리 단편화 비율: {info.get('mem_fragmentation_ratio', 'N/A')}")
        
        # 키 개수 확인
        total_keys = self.redis_client.dbsize()
        print(f"총 키 개수: {total_keys}")
        
        if total_keys > 0:
            avg_key_size = info['used_memory'] / total_keys
            print(f"키당 평균 메모리: {avg_key_size:.2f} bytes")
    
    def cleanup_test_data(self):
        """테스트 데이터 정리"""
        print("테스트 데이터 정리 중...")
        
        patterns = [
            "test_key_*",
            "pipeline_key_*",
            "concurrent_key_*",
            "hash_key_*",
            "list_key_*",
            "set_key_*"
        ]
        
        total_deleted = 0
        for pattern in patterns:
            keys = self.redis_client.keys(pattern)
            if keys:
                deleted = self.redis_client.delete(*keys)
                total_deleted += deleted
                print(f"  {pattern}: {deleted}개 키 삭제")
        
        print(f"총 {total_deleted}개 키 삭제 완료")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Redis 성능 벤치마크')
    parser.add_argument('--host', default='3.36.126.83', help='Redis 서버 호스트')
    parser.add_argument('--port', type=int, default=6379, help='Redis 서버 포트')
    parser.add_argument('--test', choices=['all', 'basic', 'pipeline', 'concurrent', 'structures'], 
                       default='all', help='실행할 테스트 종류')
    parser.add_argument('--operations', type=int, default=10000, help='연산 수')
    parser.add_argument('--threads', type=int, default=10, help='동시성 테스트 스레드 수')
    parser.add_argument('--cleanup', action='store_true', help='테스트 후 데이터 정리')
    
    args = parser.parse_args()
    
    benchmark = RedisBenchmark(host=args.host, port=args.port)
    
    try:
        # 연결 테스트
        benchmark.redis_client.ping()
        print(f"Redis 서버 연결 성공: {args.host}:{args.port}")
        print()
        
        if args.test in ['all', 'basic']:
            benchmark.test_basic_operations(args.operations)
            print()
        
        if args.test in ['all', 'pipeline']:
            benchmark.test_pipeline_performance()
            print()
            
        if args.test in ['all', 'concurrent']:
            benchmark.test_concurrent_access(args.threads, args.operations // 10)
            print()
            
        if args.test in ['all', 'structures']:
            benchmark.test_data_structures(args.operations // 10)
            print()
        
        benchmark.test_memory_usage()
        
        if args.cleanup:
            print()
            benchmark.cleanup_test_data()
            
    except redis.ConnectionError:
        print(f"Redis 서버에 연결할 수 없습니다: {args.host}:{args.port}")
    except KeyboardInterrupt:
        print("\n테스트가 중단되었습니다.")
    except Exception as e:
        print(f"테스트 중 오류 발생: {e}")