# Entity Relationship Diagram (ERD)

## 시스템 아키텍처 개요

이 시스템은 MQTT, Kafka, Redis, WebSocket을 활용한 실시간 데이터 처리 및 QR 로그인 시스템으로 구성되어 있습니다.

## 주요 구성 요소

### 1. QR Login System (PostgreSQL + Redis)
- **PostgreSQL**: User 데이터 영구 저장
- **Redis**: QR Challenge, Refresh Token 임시 저장 및 캐싱

### 2. MQTT-Kafka Bridge
- **Mosquitto (MQTT Broker)**: IoT 디바이스로부터 메시지 수신
- **Kafka**: MQTT 메시지를 Kafka 토픽으로 브릿지 (Telegraf 사용)

### 3. Kafka-Redis-WebSocket Pipeline  
- **Kafka**: 좌표 데이터 스트리밍 (coordX, coordY 토픽)
- **Redis**: Kafka에서 소비한 좌표 데이터 임시 저장
- **WebSocket Server**: Redis에서 데이터 읽어 클라이언트로 실시간 전송

## Entity Relationship Diagram

```mermaid
erDiagram
    %% PostgreSQL Entities (QR Login System)
    User {
        Long id PK
        String email UK
        String password_hash
        String orin_id UK
        Boolean enabled
        DateTime created_at
        DateTime updated_at
    }
    
    UserRole {
        Long user_id FK
        String role
    }
    
    %% Redis Entities (QR Login System)
    QrChallenge {
        String challengeId PK
        String nonce
        String status "PENDING|APPROVED|EXPIRED|EXCHANGED"
        String userId FK
        String otc
        DateTime createdAt
        DateTime approvedAt
        DateTime exchangedAt
    }
    
    RefreshToken {
        String tokenId PK
        String userId FK
        String refreshToken
        DateTime createdAt
        DateTime expiresAt
        Boolean used
        String replacedByToken
    }
    
    %% Redis Entities (WebSocket System)
    CoordinateData {
        Double coordX
        Double coordY
        String timestamp
        String source "coordX|coordY"
    }
    
    %% Kafka Topics (Message Queues)
    KafkaTopic_coordX {
        String message
        String timestamp
    }
    
    KafkaTopic_coordY {
        String message
        String timestamp
    }
    
    %% MQTT Topics
    MqttTopic {
        String topic_name
        String payload
    }
    
    %% Relationships
    User ||--o{ UserRole : has
    User ||--o{ QrChallenge : generates
    User ||--o{ RefreshToken : owns
    
    %% Data Flow Relationships
    MqttTopic }o--|| KafkaTopic_coordX : "bridges_via_telegraf"
    MqttTopic }o--|| KafkaTopic_coordY : "bridges_via_telegraf"
    KafkaTopic_coordX }o--|| CoordinateData : "consumed_to_redis"
    KafkaTopic_coordY }o--|| CoordinateData : "consumed_to_redis"
    CoordinateData }o--|| WebSocketConnection : "streams_to_client"
    
    %% SSE Connection for QR Login
    QrChallenge }o--|| SSEConnection : "notifies_status"
    
    WebSocketConnection {
        String sessionId
        String clientIP
        DateTime connectedAt
    }
    
    SSEConnection {
        String challengeId
        String clientId
        DateTime connectedAt
    }
```

## 데이터 저장소별 엔티티 분류

### PostgreSQL (영구 저장소)
- **User**: 사용자 계정 정보
- **UserRole**: 사용자 권한 (USER, ADMIN)

### Redis - QR Login (Port: 6378)
- **QrChallenge**: QR 코드 챌린지 (TTL: 120초)
- **RefreshToken**: JWT 리프레시 토큰 (TTL: 7일)

### Redis - WebSocket (Port: 6379)  
- **CoordinateData**: MQTT에서 수신한 좌표 데이터 (실시간 스트리밍)

### Kafka Topics
- **coordX**: X 좌표 데이터 토픽
- **coordY**: Y 좌표 데이터 토픽

## 데이터 흐름

### 1. MQTT → Kafka → Redis → WebSocket
```
IoT Device → MQTT Broker → Telegraf → Kafka → Python Consumer → Redis → Spring WebSocket → Client
```

### 2. QR Login Flow
```
Client → Generate QR → Redis (QrChallenge) → Mobile Scan → Approve → Redis Update → SSE Notify → JWT Token
```

### 3. Authentication Flow
```
Login → PostgreSQL (User) → JWT Access Token + Refresh Token → Redis (RefreshToken Cache)
```

## 주요 특징

1. **이중 Redis 구성**
   - QR Login용 Redis (6378): 인증 관련 임시 데이터
   - WebSocket용 Redis (6379): 실시간 스트리밍 데이터

2. **실시간 통신**
   - SSE (Server-Sent Events): QR 로그인 상태 알림
   - WebSocket: 좌표 데이터 실시간 스트리밍

3. **메시지 브릿지**
   - Telegraf: MQTT → Kafka 브릿지
   - Python Consumer: Kafka → Redis 브릿지

4. **보안**
   - JWT 기반 인증
   - QR Challenge + OTC (One-Time Code) 검증
   - Refresh Token Rotation

## 서비스 포트 정보

| 서비스 | 포트 | 설명 |
|--------|------|------|
| PostgreSQL | 5433 | QR Login 데이터베이스 |
| Redis (QR) | 6378 | QR Login 캐시 |
| Redis (WS) | 6379 | WebSocket 데이터 |
| Kafka | 9092 | 메시지 브로커 |
| MQTT | 3123 | MQTT 브로커 |
| QR Login API | 8090 | REST API |
| WebSocket Server | 8081 | 실시간 좌표 스트리밍 |