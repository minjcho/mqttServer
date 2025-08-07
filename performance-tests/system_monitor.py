#!/usr/bin/env python3

import psutil
import time
import json
import argparse
import csv
import subprocess
import socket
import threading
from datetime import datetime, timedelta
import os
import signal
import sys

class SystemMonitor:
    def __init__(self, output_dir="/tmp/performance_monitor"):
        self.output_dir = output_dir
        self.monitoring = False
        self.monitor_thread = None
        
        # 출력 디렉토리 생성
        os.makedirs(output_dir, exist_ok=True)
        
        # 모니터링 데이터 저장
        self.system_data = []
        self.docker_data = []
        self.network_data = []
        self.service_data = []
        
    def get_docker_stats(self):
        """Docker 컨테이너 통계 수집"""
        try:
            result = subprocess.run(
                ['docker', 'stats', '--no-stream', '--format', 
                 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}'],
                capture_output=True, text=True, timeout=10
            )
            
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')[1:]  # 헤더 제외
                containers = []
                
                for line in lines:
                    if line.strip():
                        parts = line.split('\t')
                        if len(parts) >= 5:
                            containers.append({
                                'name': parts[0],
                                'cpu_percent': parts[1].replace('%', ''),
                                'memory_usage': parts[2],
                                'network_io': parts[3],
                                'block_io': parts[4]
                            })
                
                return containers
            else:
                return []
                
        except (subprocess.TimeoutExpired, subprocess.SubprocessError, FileNotFoundError):
            return []
    
    def get_service_health(self):
        """서비스 헬스체크"""
        services = {
            'mqtt': {'host': '3.36.126.83', 'port': 3123},
            'kafka': {'host': '3.36.126.83', 'port': 9092},
            'redis': {'host': '3.36.126.83', 'port': 6379},
            'websocket': {'host': '3.36.126.83', 'port': 8081}
        }
        
        health_status = {}
        
        for service_name, config in services.items():
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(2)
                result = sock.connect_ex((config['host'], config['port']))
                sock.close()
                
                health_status[service_name] = {
                    'status': 'healthy' if result == 0 else 'unhealthy',
                    'port': config['port'],
                    'response_time': self.check_service_response_time(config['host'], config['port'])
                }
            except Exception:
                health_status[service_name] = {
                    'status': 'error',
                    'port': config['port'],
                    'response_time': -1
                }
        
        return health_status
    
    def check_service_response_time(self, host, port, timeout=2):
        """서비스 응답 시간 측정"""
        try:
            start_time = time.time()
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(timeout)
            sock.connect((host, port))
            sock.close()
            return (time.time() - start_time) * 1000  # milliseconds
        except Exception:
            return -1
    
    def get_network_stats(self):
        """네트워크 통계 수집"""
        try:
            # 네트워크 인터페이스 통계
            net_io = psutil.net_io_counters()
            
            # TCP/UDP 연결 상태
            connections = psutil.net_connections()
            
            # 포트별 연결 수 계산
            port_connections = {}
            for conn in connections:
                if conn.laddr and conn.status == 'ESTABLISHED':
                    port = conn.laddr.port
                    port_connections[port] = port_connections.get(port, 0) + 1
            
            # 특정 포트들의 연결 수
            service_connections = {
                'mqtt': port_connections.get(3123, 0),
                'kafka': port_connections.get(9092, 0),
                'redis': port_connections.get(6379, 0),
                'websocket': port_connections.get(8081, 0)
            }
            
            return {
                'bytes_sent': net_io.bytes_sent,
                'bytes_recv': net_io.bytes_recv,
                'packets_sent': net_io.packets_sent,
                'packets_recv': net_io.packets_recv,
                'total_connections': len([c for c in connections if c.status == 'ESTABLISHED']),
                'service_connections': service_connections
            }
            
        except Exception as e:
            print(f"네트워크 통계 수집 오류: {e}")
            return {}
    
    def collect_system_metrics(self):
        """시스템 메트릭 수집"""
        try:
            # CPU 사용률
            cpu_percent = psutil.cpu_percent(interval=1)
            cpu_count = psutil.cpu_count()
            cpu_freq = psutil.cpu_freq()
            
            # 메모리 사용률
            memory = psutil.virtual_memory()
            swap = psutil.swap_memory()
            
            # 디스크 사용률
            disk = psutil.disk_usage('/')
            disk_io = psutil.disk_io_counters()
            
            # 프로세스 개수
            process_count = len(psutil.pids())
            
            # 로드 평균 (Linux/Mac만)
            try:
                load_avg = os.getloadavg()
            except (OSError, AttributeError):
                load_avg = [0, 0, 0]
            
            return {
                'timestamp': datetime.now().isoformat(),
                'cpu': {
                    'percent': cpu_percent,
                    'count': cpu_count,
                    'freq_current': cpu_freq.current if cpu_freq else 0,
                    'load_1m': load_avg[0],
                    'load_5m': load_avg[1],
                    'load_15m': load_avg[2]
                },
                'memory': {
                    'total': memory.total,
                    'available': memory.available,
                    'percent': memory.percent,
                    'used': memory.used,
                    'free': memory.free,
                    'swap_percent': swap.percent,
                    'swap_used': swap.used
                },
                'disk': {
                    'total': disk.total,
                    'used': disk.used,
                    'free': disk.free,
                    'percent': disk.percent,
                    'read_bytes': disk_io.read_bytes if disk_io else 0,
                    'write_bytes': disk_io.write_bytes if disk_io else 0
                },
                'process_count': process_count
            }
            
        except Exception as e:
            print(f"시스템 메트릭 수집 오류: {e}")
            return {}
    
    def monitor_loop(self, interval=5, duration=None):
        """모니터링 루프"""
        self.monitoring = True
        start_time = time.time()
        
        print(f"시스템 모니터링 시작 (간격: {interval}초)")
        if duration:
            print(f"모니터링 지속시간: {duration}초")
        
        try:
            while self.monitoring:
                current_time = time.time()
                
                # 지속시간 체크
                if duration and (current_time - start_time) > duration:
                    print("모니터링 지속시간 완료")
                    break
                
                # 시스템 메트릭 수집
                system_metrics = self.collect_system_metrics()
                if system_metrics:
                    self.system_data.append(system_metrics)
                
                # Docker 통계 수집
                docker_stats = self.get_docker_stats()
                if docker_stats:
                    docker_entry = {
                        'timestamp': datetime.now().isoformat(),
                        'containers': docker_stats
                    }
                    self.docker_data.append(docker_entry)
                
                # 네트워크 통계 수집
                network_stats = self.get_network_stats()
                if network_stats:
                    network_entry = {
                        'timestamp': datetime.now().isoformat(),
                        **network_stats
                    }
                    self.network_data.append(network_entry)
                
                # 서비스 헬스체크
                service_health = self.get_service_health()
                if service_health:
                    service_entry = {
                        'timestamp': datetime.now().isoformat(),
                        'services': service_health
                    }
                    self.service_data.append(service_entry)
                
                # 실시간 출력
                if system_metrics:
                    cpu_percent = system_metrics['cpu']['percent']
                    mem_percent = system_metrics['memory']['percent']
                    disk_percent = system_metrics['disk']['percent']
                    process_count = system_metrics['process_count']
                    
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] "
                          f"CPU: {cpu_percent:5.1f}% | "
                          f"메모리: {mem_percent:5.1f}% | "
                          f"디스크: {disk_percent:5.1f}% | "
                          f"프로세스: {process_count}")
                
                # 다음 수집까지 대기
                time.sleep(interval)
                
        except KeyboardInterrupt:
            print("\n모니터링이 사용자에 의해 중단되었습니다.")
        except Exception as e:
            print(f"모니터링 오류: {e}")
        finally:
            self.monitoring = False
    
    def start_monitoring(self, interval=5, duration=None):
        """백그라운드에서 모니터링 시작"""
        if self.monitor_thread and self.monitor_thread.is_alive():
            print("이미 모니터링이 실행 중입니다.")
            return
        
        self.monitor_thread = threading.Thread(
            target=self.monitor_loop, 
            args=(interval, duration)
        )
        self.monitor_thread.daemon = True
        self.monitor_thread.start()
    
    def stop_monitoring(self):
        """모니터링 중단"""
        self.monitoring = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=10)
    
    def save_data(self):
        """수집된 데이터를 파일로 저장"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # JSON 형태로 저장
        if self.system_data:
            system_file = f"{self.output_dir}/system_metrics_{timestamp}.json"
            with open(system_file, 'w', encoding='utf-8') as f:
                json.dump(self.system_data, f, indent=2, ensure_ascii=False)
            print(f"시스템 메트릭 저장: {system_file}")
        
        if self.docker_data:
            docker_file = f"{self.output_dir}/docker_stats_{timestamp}.json"
            with open(docker_file, 'w', encoding='utf-8') as f:
                json.dump(self.docker_data, f, indent=2, ensure_ascii=False)
            print(f"Docker 통계 저장: {docker_file}")
        
        if self.network_data:
            network_file = f"{self.output_dir}/network_stats_{timestamp}.json"
            with open(network_file, 'w', encoding='utf-8') as f:
                json.dump(self.network_data, f, indent=2, ensure_ascii=False)
            print(f"네트워크 통계 저장: {network_file}")
        
        if self.service_data:
            service_file = f"{self.output_dir}/service_health_{timestamp}.json"
            with open(service_file, 'w', encoding='utf-8') as f:
                json.dump(self.service_data, f, indent=2, ensure_ascii=False)
            print(f"서비스 헬스체크 저장: {service_file}")
        
        # CSV 형태로도 시스템 메트릭 저장
        if self.system_data:
            csv_file = f"{self.output_dir}/system_metrics_{timestamp}.csv"
            with open(csv_file, 'w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                writer.writerow([
                    'timestamp', 'cpu_percent', 'cpu_load_1m', 'memory_percent', 
                    'memory_used_gb', 'disk_percent', 'process_count'
                ])
                
                for entry in self.system_data:
                    writer.writerow([
                        entry['timestamp'],
                        entry['cpu']['percent'],
                        entry['cpu']['load_1m'],
                        entry['memory']['percent'],
                        round(entry['memory']['used'] / (1024**3), 2),  # GB
                        entry['disk']['percent'],
                        entry['process_count']
                    ])
            print(f"시스템 메트릭 CSV 저장: {csv_file}")
    
    def print_summary(self):
        """모니터링 결과 요약"""
        if not self.system_data:
            print("수집된 데이터가 없습니다.")
            return
        
        print(f"\n{'='*60}")
        print(f"모니터링 결과 요약")
        print(f"{'='*60}")
        print(f"수집 기간: {self.system_data[0]['timestamp']} ~ {self.system_data[-1]['timestamp']}")
        print(f"데이터 포인트 수: {len(self.system_data)}")
        
        # CPU 통계
        cpu_values = [entry['cpu']['percent'] for entry in self.system_data]
        print(f"\nCPU 사용률:")
        print(f"  평균: {sum(cpu_values)/len(cpu_values):.1f}%")
        print(f"  최소: {min(cpu_values):.1f}%")
        print(f"  최대: {max(cpu_values):.1f}%")
        
        # 메모리 통계  
        memory_values = [entry['memory']['percent'] for entry in self.system_data]
        print(f"\n메모리 사용률:")
        print(f"  평균: {sum(memory_values)/len(memory_values):.1f}%")
        print(f"  최소: {min(memory_values):.1f}%")
        print(f"  최대: {max(memory_values):.1f}%")
        
        # 디스크 통계
        disk_values = [entry['disk']['percent'] for entry in self.system_data]
        print(f"\n디스크 사용률:")
        print(f"  평균: {sum(disk_values)/len(disk_values):.1f}%")
        print(f"  최소: {min(disk_values):.1f}%")
        print(f"  최대: {max(disk_values):.1f}%")
        
        # 서비스 가용성
        if self.service_data:
            print(f"\n서비스 가용성:")
            services = ['mqtt', 'kafka', 'redis', 'websocket']
            for service in services:
                healthy_count = sum(
                    1 for entry in self.service_data 
                    if entry['services'].get(service, {}).get('status') == 'healthy'
                )
                total_checks = len(self.service_data)
                uptime = (healthy_count / total_checks * 100) if total_checks > 0 else 0
                print(f"  {service.upper()}: {uptime:.1f}% ({healthy_count}/{total_checks})")

def signal_handler(signum, frame):
    """시그널 핸들러"""
    print("\n모니터링을 종료합니다...")
    sys.exit(0)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='시스템 성능 모니터링')
    parser.add_argument('--interval', type=int, default=5, help='수집 간격 (초)')
    parser.add_argument('--duration', type=int, help='모니터링 지속 시간 (초)')
    parser.add_argument('--output', default='/tmp/performance_monitor', help='출력 디렉토리')
    parser.add_argument('--save-only', action='store_true', help='파일로만 저장 (실시간 출력 없음)')
    
    args = parser.parse_args()
    
    # 시그널 핸들러 등록
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    monitor = SystemMonitor(args.output)
    
    try:
        # 모니터링 실행
        monitor.monitor_loop(args.interval, args.duration)
        
    finally:
        # 데이터 저장
        print("\n모니터링 완료. 데이터 저장 중...")
        monitor.save_data()
        monitor.print_summary()
        print(f"\n모든 데이터가 {args.output} 디렉토리에 저장되었습니다.")