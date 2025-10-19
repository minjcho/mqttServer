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
import java.util.Set;

@Component
public class CoordinateBroadcastScheduler {

    private static final Logger logger = LoggerFactory.getLogger(CoordinateBroadcastScheduler.class);

    // Redis Key Patterns
    private static final String REDIS_ORIN_KEY_PATTERN = "orin:*:latest";
    private static final String REDIS_ORIN_KEY_SEPARATOR = ":";
    private static final int REDIS_ORIN_KEY_ID_INDEX = 1;

    // WebSocket Message Types
    private static final String MESSAGE_TYPE_COORDINATES = "coordinates";

    // Logging Intervals
    private static final long STATS_LOG_INTERVAL_MS = 5000; // 5 seconds

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
            // Redis에서 모든 ORIN ID 찾기
            Set<String> orinKeys = coordinateService.getRedisTemplate().keys(REDIS_ORIN_KEY_PATTERN);

            if (orinKeys != null && !orinKeys.isEmpty()) {
                // 각 ORIN ID별로 데이터를 브로드캐스트
                for (String orinKey : orinKeys) {
                    // orin:ORIN001:latest -> ORIN001
                    String orinId = orinKey.split(REDIS_ORIN_KEY_SEPARATOR)[REDIS_ORIN_KEY_ID_INDEX];
                    
                    CoordinateData coordinates = coordinateService.getLatestCoordinatesForOrin(orinId);
                    
                    if (coordinates != null) {
                        // 브로드캐스트용 메시지 생성
                        Map<String, Object> message = new HashMap<>();
                        message.put("type", MESSAGE_TYPE_COORDINATES);
                        message.put("orinId", orinId);
                        message.put("data", coordinates);
                        message.put("timestamp", System.currentTimeMillis());
                        message.put("activeClients", activeSessionCount);
                        message.put("messageNumber", ++messagesSent);

                        // JSON으로 변환하여 해당 ORIN ID를 구독하는 세션들에게만 브로드캐스트
                        String jsonMessage = objectMapper.writeValueAsString(message);
                        webSocketHandler.broadcastCoordinatesForOrin(orinId, jsonMessage);

                        logger.debug("✅ Broadcasted ORIN {} coordinates: X={}, Y={}", 
                                   orinId, coordinates.getCoordX(), coordinates.getCoordY());
                    }
                }

                // 로깅 (STATS_LOG_INTERVAL_MS마다 한 번씩만)
                long currentTime = System.currentTimeMillis();
                if (currentTime - lastBroadcastTime >= STATS_LOG_INTERVAL_MS) {
                    logger.info("Broadcasted coordinates for {} ORIN IDs to {} clients, Messages sent: {}", 
                              orinKeys.size(), activeSessionCount, messagesSent);
                    lastBroadcastTime = currentTime;
                }
            } else {
                // ORIN 데이터가 없으면 기존 로직으로 폴백
                CoordinateData coordinates = coordinateService.getLatestCoordinates();
                
                if (coordinates == null || (coordinates.getCoordX() == 0.0 && coordinates.getCoordY() == 0.0 && "system".equals(coordinates.getSource()))) {
                    coordinates = coordinateService.generateRandomCoordinates();
                    logger.debug("Using random coordinates as no ORIN data available from Redis");
                }

                Map<String, Object> message = new HashMap<>();
                message.put("type", MESSAGE_TYPE_COORDINATES);
                message.put("data", coordinates);
                message.put("timestamp", System.currentTimeMillis());
                message.put("activeClients", activeSessionCount);
                message.put("messageNumber", ++messagesSent);

                String jsonMessage = objectMapper.writeValueAsString(message);
                webSocketHandler.broadcastCoordinates(jsonMessage);
                
                logger.debug("✅ Broadcasted fallback coordinates: X={}, Y={}", 
                           coordinates.getCoordX(), coordinates.getCoordY());
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