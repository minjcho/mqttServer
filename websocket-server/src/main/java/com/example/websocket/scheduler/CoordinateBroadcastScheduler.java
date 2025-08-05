package com.example.websocket.scheduler;

import com.example.websocket.handler.CoordinateWebSocketHandler;
import com.example.websocket.model.CoordinateData;
import com.example.websocket.service.CoordinateService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.Map;

@Component
public class CoordinateBroadcastScheduler {

    private static final Logger logger = LoggerFactory.getLogger(CoordinateBroadcastScheduler.class);
    
    private final CoordinateWebSocketHandler webSocketHandler;
    private final CoordinateService coordinateService;
    private final ObjectMapper objectMapper;
    
    @Value("${websocket.broadcast-interval:1000}")
    private long broadcastInterval;
    
    private long messagesSent = 0;
    private long lastBroadcastTime = System.currentTimeMillis();

    public CoordinateBroadcastScheduler(CoordinateWebSocketHandler webSocketHandler, 
                                       CoordinateService coordinateService) {
        this.webSocketHandler = webSocketHandler;
        this.coordinateService = coordinateService;
        this.objectMapper = new ObjectMapper();
    }

    /**
     * 설정된 주기로 좌표 데이터를 브로드캐스트
     * application.yml의 websocket.broadcast-interval 값 사용 (기본 1초)
     */
    @Scheduled(fixedDelayString = "${websocket.broadcast-interval:1000}")
    public void broadcastCoordinates() {
        int activeSessionCount = webSocketHandler.getActiveSessionCount();
        
        // 활성 세션이 없으면 브로드캐스트 생략
        if (activeSessionCount == 0) {
            return;
        }

        try {
            // Redis에서 최신 좌표 데이터 가져오기
            CoordinateData coordinates = coordinateService.getLatestCoordinates();
            
            // 좌표 데이터가 없거나 기본값이면 랜덤 데이터로 대체 (테스트 목적)
            if (coordinates == null || (coordinates.getCoordX() == 0.0 && coordinates.getCoordY() == 0.0 && "system".equals(coordinates.getSource()))) {
                coordinates = coordinateService.generateRandomCoordinates();
                logger.debug("Using random coordinates as no data available from Redis");
            } else {
                logger.debug("✅ Using Redis coordinates: X={}, Y={}, source={}", 
                           coordinates.getCoordX(), coordinates.getCoordY(), coordinates.getSource());
            }

            // 브로드캐스트용 메시지 생성
            Map<String, Object> message = new HashMap<>();
            message.put("type", "coordinates");
            message.put("data", coordinates);
            message.put("timestamp", System.currentTimeMillis());
            message.put("activeClients", activeSessionCount);
            message.put("messageNumber", ++messagesSent);

            // JSON으로 변환하여 브로드캐스트
            String jsonMessage = objectMapper.writeValueAsString(message);
            webSocketHandler.broadcastCoordinates(jsonMessage);

            // 로깅 (5초마다 한 번씩만)
            long currentTime = System.currentTimeMillis();
            if (currentTime - lastBroadcastTime >= 5000) {
                logger.info("Broadcasted coordinates to {} clients - X: {}, Y: {}, Messages sent: {}", 
                          activeSessionCount, coordinates.getCoordX(), coordinates.getCoordY(), messagesSent);
                lastBroadcastTime = currentTime;
            }

        } catch (Exception e) {
            logger.error("Error broadcasting coordinates: {}", e.getMessage(), e);
        }
    }

    /**
     * 1분마다 통계 정보 로깅
     */
    @Scheduled(fixedRate = 60000) // 60초
    public void logStatistics() {
        int activeSessionCount = webSocketHandler.getActiveSessionCount();
        Map<String, Object> redisStats = coordinateService.getRedisStats();
        
        logger.info("=== WebSocket Server Statistics ===");
        logger.info("Active WebSocket sessions: {}", activeSessionCount);
        logger.info("Total messages sent: {}", messagesSent);
        logger.info("Redis connected: {}", redisStats.get("connected"));
        logger.info("Redis message count: {}", redisStats.get("messageCount"));
        logger.info("Redis message keys: {}", redisStats.get("messageKeys"));
        logger.info("Broadcast interval: {}ms", broadcastInterval);
        logger.info("===================================");
    }

    /**
     * 애플리케이션 시작 후 연결 상태 확인
     */
    @Scheduled(initialDelay = 5000, fixedRate = 30000) // 5초 후 시작, 30초마다 실행
    public void checkConnections() {
        boolean redisConnected = coordinateService.isRedisConnected();
        int activeClients = webSocketHandler.getActiveSessionCount();
        
        if (!redisConnected) {
            logger.warn("Redis connection is not available!");
        }
        
        logger.debug("Health check - Redis: {}, Active clients: {}", 
                   redisConnected ? "OK" : "FAIL", activeClients);
    }
}