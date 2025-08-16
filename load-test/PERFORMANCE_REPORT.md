# EC2 서버 성능 분석 보고서

## 1. 개요

### 1.1 서버 정보
- **도메인**: minjcho.site
- **인스턴스 타입**: [EC2 인스턴스 타입 기입]
- **리전**: [AWS 리전 기입]
- **분석 일시**: [분석 날짜/시간]

### 1.2 서비스 구성
| 서비스 | 포트 | 기술 스택 | 용도 |
|--------|------|-----------|------|
| MQTT Broker | 3123 | Mosquitto | IoT 메시지 브로커 |
| WebSocket Server | 8081 | Spring Boot + SockJS | 실시간 좌표 스트리밍 |
| QR Login API | 8090 | Spring Boot | QR 기반 인증 시스템 |
| PostgreSQL | 5433 | PostgreSQL 16 | QR 로그인 데이터 |
| Redis (MQTT) | 6379 | Redis 7.2 | MQTT 메시지 캐싱 |
| Redis (QR) | 6378 | Redis 7 | QR 세션 관리 |
| Kafka | 9092 | Apache Kafka | 메시지 스트리밍 |
| Nginx | 443 | Nginx | 리버스 프록시 |

## 2. 시스템 리소스 분석

### 2.1 하드웨어 사양
```
CPU: [CPU 모델 및 코어 수]
메모리: [전체 메모리 용량]
디스크: [디스크 용량 및 타입]
네트워크: [네트워크 대역폭]
```

### 2.2 현재 리소스 사용률
| 리소스 | 사용률 | 권장 임계값 | 상태 |
|--------|--------|-------------|------|
| CPU | [X]% | < 70% | [정상/주의/경고] |
| 메모리 | [X]% | < 80% | [정상/주의/경고] |
| 디스크 | [X]% | < 80% | [정상/주의/경고] |
| 네트워크 | [X] Mbps | - | [정상/주의/경고] |

## 3. 서비스별 성능 분석

### 3.1 MQTT Broker (Mosquitto)
#### 성능 지표
- **최대 동시 연결 수**: 이론적 10,000개 (설정값)
- **메시지 처리량**: [X] msg/sec
- **평균 지연 시간**: [X] ms

#### 부하 테스트 결과
| 동시 접속자 | 메시지/초 | 평균 응답시간 | 에러율 |
|------------|-----------|---------------|--------|
| 10 | [X] | [X]ms | [X]% |
| 50 | [X] | [X]ms | [X]% |
| 100 | [X] | [X]ms | [X]% |
| 200 | [X] | [X]ms | [X]% |
| 500 | [X] | [X]ms | [X]% |

### 3.2 WebSocket Server
#### 성능 지표
- **최대 동시 연결 수**: 약 5,000개 (Spring Boot 기본)
- **처리량**: [X] req/sec
- **평균 응답 시간**: [X] ms

#### API 엔드포인트 성능
| 엔드포인트 | 동시 사용자 | RPS | 평균 응답시간 | P95 응답시간 |
|-----------|------------|-----|--------------|-------------|
| /api/mqtt/commands | 100 | [X] | [X]ms | [X]ms |
| /api/sensor-data | 100 | [X] | [X]ms | [X]ms |
| /api/map-data | 100 | [X] | [X]ms | [X]ms |

### 3.3 QR Login System
#### 성능 지표
- **최대 동시 요청**: 약 200개
- **DB 연결 풀**: [X]개
- **Redis 연결**: [X]개

#### 부하 테스트 결과
| 작업 | 동시 사용자 | TPS | 평균 응답시간 | 에러율 |
|------|------------|-----|--------------|--------|
| QR 생성 | 50 | [X] | [X]ms | [X]% |
| QR 검증 | 50 | [X] | [X]ms | [X]% |
| 토큰 발급 | 50 | [X] | [X]ms | [X]% |

## 4. 병목 지점 분석

### 4.1 식별된 병목 지점
1. **[병목 지점 1]**: [설명]
2. **[병목 지점 2]**: [설명]
3. **[병목 지점 3]**: [설명]

### 4.2 성능 제한 요소
- **파일 디스크립터 한계**: [현재값] (권장: 65536)
- **TCP 백로그**: [현재값] (권장: 1024)
- **데이터베이스 연결 풀**: [현재값] (권장: [X])

## 5. 최대 처리 용량 예측

### 5.1 서비스별 최대 용량
| 서비스 | 현재 설정 | 최대 동시 연결 | 최대 TPS | 비고 |
|--------|----------|---------------|----------|------|
| MQTT Broker | Default | 10,000 | [X] | CPU 제한 |
| WebSocket | Default | 5,000 | [X] | 메모리 제한 |
| QR Login | Default | 200 | [X] | DB 연결 제한 |

### 5.2 전체 시스템 용량
- **최대 동시 사용자**: 약 [X]명
- **최대 메시지 처리량**: [X] msg/sec
- **최대 API 처리량**: [X] req/sec

## 6. 최적화 권장사항

### 6.1 즉시 적용 가능한 최적화
1. **시스템 레벨**
   ```bash
   # 파일 디스크립터 증가
   ulimit -n 65536
   
   # TCP 설정 최적화
   sysctl -w net.core.somaxconn=1024
   sysctl -w net.ipv4.tcp_max_syn_backlog=2048
   ```

2. **MQTT Broker (mosquitto.conf)**
   ```
   max_connections 10000
   max_queued_messages 1000
   max_inflight_messages 100
   ```

3. **Spring Boot (application.yml)**
   ```yaml
   server:
     tomcat:
       max-threads: 200
       accept-count: 100
       max-connections: 10000
   ```

### 6.2 중장기 최적화 방안
1. **스케일링 전략**
   - 수평 확장: Load Balancer + 다중 인스턴스
   - 수직 확장: 인스턴스 타입 업그레이드

2. **캐싱 전략**
   - Redis 캐시 TTL 최적화
   - CDN 활용 (정적 리소스)

3. **데이터베이스 최적화**
   - 인덱스 최적화
   - 쿼리 튜닝
   - Read Replica 도입

## 7. 모니터링 권장사항

### 7.1 핵심 모니터링 지표
- CPU 사용률 (임계값: 70%)
- 메모리 사용률 (임계값: 80%)
- 디스크 I/O (임계값: 80%)
- 네트워크 처리량
- 애플리케이션 응답 시간
- 에러율

### 7.2 모니터링 도구
- **CloudWatch**: EC2 메트릭
- **Prometheus + Grafana**: 애플리케이션 메트릭
- **ELK Stack**: 로그 분석

## 8. 결론

### 8.1 현재 상태 요약
- 전반적인 시스템 상태: [정상/주의/경고]
- 예상 최대 부하 처리 능력: [X]%
- 권장 조치 우선순위: [높음/중간/낮음]

### 8.2 다음 단계
1. [우선순위 1 작업]
2. [우선순위 2 작업]
3. [우선순위 3 작업]

---

## 부록

### A. 테스트 스크립트
- `ec2-performance-analysis.sh`: 시스템 리소스 분석
- `load-test.sh`: 부하 테스트 실행
- `monitor.sh`: 실시간 모니터링

### B. 참고 자료
- [Mosquitto Performance Tuning](https://mosquitto.org/documentation/)
- [Spring Boot Performance Guide](https://docs.spring.io/spring-boot/)
- [AWS EC2 Best Practices](https://docs.aws.amazon.com/ec2/)

### C. 용어 정의
- **RPS**: Requests Per Second (초당 요청 수)
- **TPS**: Transactions Per Second (초당 트랜잭션 수)
- **P95**: 95 백분위수 응답 시간
- **TTL**: Time To Live (캐시 유효 시간)

---

*보고서 작성일: [날짜]*  
*작성자: [작성자명]*  
*검토자: [검토자명]*