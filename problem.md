# 문제 해결 기록

## 문제 1: Kafka Consumer Group 설정 문제

### 증상
- kafka-redis-consumer가 Kafka에서 메시지를 consume하지 못함
- Redis에 데이터가 저장되지 않음
- Consumer 로그에서 `Group Coordinator Not Available` 에러 발생

### 원인
- Consumer Group을 사용할 때 Kafka의 Group Coordinator가 제대로 설정되지 않음
- `group_id='redis-consumer-new-' + str(int(time.time()))` 설정으로 Consumer Group 의존성 발생
- 단일 컨테이너 환경에서 불필요한 복잡성 증가

### 해결방법
Consumer Group을 제거하고 수동 파티션 할당 방식으로 변경:

```python
# 이전 (문제 있던 코드)
consumer = KafkaConsumer(
    *topics,
    group_id='redis-consumer-new-' + str(int(time.time())),  # 문제 원인
    enable_auto_commit=True,
    ...
)

# 해결된 코드
consumer = KafkaConsumer(
    bootstrap_servers=[kafka_servers],
    enable_auto_commit=False,  # Consumer Group 없이 수동 관리
    ...
)
# 수동으로 파티션 할당
topic_partitions = [TopicPartition('mqtt-messages', 0), ...]
consumer.assign(topic_partitions)
```

### 결과
- ✅ Kafka에서 Redis로 데이터 전송 성공
- ✅ 메시지 카운트: 4개 메시지 정상 처리
- ✅ 전체 파이프라인 정상 작동: MQTT → Mosquitto → Kafka → Redis

---

## 문제 2: Spring Boot WebSocket 서버 정적 파일 서빙 문제

### 증상
- http://localhost:8080 접속 시 404 에러 발생
- API 엔드포인트는 정상 작동 (`/api/status`, `/api/coordinates`)
- 정적 HTML 파일에 접근할 수 없음

### 원인
- WebController에서 Thymeleaf 템플릿 방식을 사용하려고 했으나 의존성 없음
- `return "index"`는 템플릿 엔진을 요구하지만 정적 파일 서빙이 목적
- Spring Boot의 정적 리소스 매핑이 제대로 이루어지지 않음

### 해결방법
템플릿 방식에서 리다이렉트 방식으로 변경:

```java
// 이전 (문제 있던 코드)
@GetMapping("/")
public String index(Model model) {
    return "index";  // Thymeleaf 템플릿 요구
}

// 해결된 코드
@GetMapping("/")
public String index() {
    return "redirect:/index.html";  // 정적 파일로 리다이렉트
}
```

### 결과
- ✅ http://localhost:8080 정상 접속 (302 리다이렉트)
- ✅ http://localhost:8080/index.html 정상 서빙 (200 OK)
- ✅ 실시간 WebSocket 연결 및 좌표 데이터 스트리밍 정상 작동

---

## 문제 3: Maven 컴파일 에러

### 증상
- Docker 빌드 중 컴파일 에러 발생
- `reference to execute is ambiguous` 에러

### 원인
- Redis `execute` 메서드 오버로딩으로 인한 모호성
- `RedisCallback`과 `SessionCallback` 두 메서드 시그니처가 일치

### 해결방법
명시적 타입 캐스팅 추가:

```java
// 이전 (모호한 코드)
String ping = redisTemplate.execute(connection -> {
    return connection.ping();
});

// 해결된 코드
String ping = redisTemplate.execute((org.springframework.data.redis.core.RedisCallback<String>) connection -> {
    return connection.ping();
});
```

---

## 전체 시스템 아키텍처

```
MQTT 클라이언트 
    ↓
Mosquitto (MQTT Broker)
    ↓
mqtt-bridge (Python)
    ↓
Kafka (Message Queue)
    ↓
kafka-redis-consumer (Python) ← [문제 1 해결]
    ↓
Redis (Data Store)
    ↓
WebSocket 서버 (Spring Boot) ← [문제 2, 3 해결]
    ↓
웹 클라이언트 (HTML/JavaScript)
```

## 최종 결과
- ✅ 전체 데이터 파이프라인 정상 작동
- ✅ 실시간 좌표 데이터 스트리밍 성공
- ✅ 웹 인터페이스를 통한 모니터링 가능
- ✅ http://localhost:8080 접속 가능