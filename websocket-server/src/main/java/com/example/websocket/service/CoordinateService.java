package com.example.websocket.service;

import com.example.websocket.model.CoordinateData;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class CoordinateService {

    private static final Logger logger = LoggerFactory.getLogger(CoordinateService.class);
    
    private final RedisTemplate<String, Object> redisTemplate;
    private final ObjectMapper objectMapper;
    
    @Value("${websocket.max-messages:10}")
    private int maxMessages;

    // 최신 좌표 데이터를 캐시
    private volatile CoordinateData latestCoordinate = new CoordinateData(0.0, 0.0, "", "system");

    public CoordinateService(RedisTemplate<String, Object> redisTemplate) {
        this.redisTemplate = redisTemplate;
        this.objectMapper = new ObjectMapper();
    }

    /**
     * Redis에서 최신 좌표 데이터를 가져와서 파싱
     */
    public CoordinateData getLatestCoordinates() {
        try {
            // Redis에서 모든 메시지 키 조회
            Set<String> messageKeys = redisTemplate.keys("message:mqtt-messages:*");
            
            if (messageKeys == null || messageKeys.isEmpty()) {
                logger.debug("No message keys found in Redis");
                return latestCoordinate;
            }

            Map<String, Object> latestData = new HashMap<>();
            
            // 각 메시지를 확인하여 좌표 데이터 추출
            for (String key : messageKeys) {
                try {
                    Map<Object, Object> messageData = redisTemplate.opsForHash().entries(key);
                    
                    if (messageData.containsKey("message")) {
                        String messageJson = (String) messageData.get("message");
                        JsonNode messageNode = objectMapper.readTree(messageJson);
                        
                        // MQTT 메시지에서 payload 추출
                        if (messageNode.has("payload")) {
                            String payload = messageNode.get("payload").asText();
                            JsonNode payloadNode = objectMapper.readTree(payload);
                            
                            // coordX와 coordY 데이터 추출
                            if (payloadNode.has("coordX")) {
                                latestData.put("coordX", payloadNode.get("coordX").asDouble());
                            }
                            if (payloadNode.has("coordY")) {
                                latestData.put("coordY", payloadNode.get("coordY").asDouble());
                            }
                            
                            // 타임스탬프 저장
                            if (messageData.containsKey("timestamp")) {
                                latestData.put("timestamp", messageData.get("timestamp"));
                            }
                        }
                    }
                } catch (Exception e) {
                    logger.warn("Failed to parse message from key {}: {}", key, e.getMessage());
                }
            }

            // 좌표 데이터가 있으면 업데이트
            if (latestData.containsKey("coordX") || latestData.containsKey("coordY")) {
                Double coordX = (Double) latestData.getOrDefault("coordX", latestCoordinate.getCoordX());
                Double coordY = (Double) latestData.getOrDefault("coordY", latestCoordinate.getCoordY());
                String timestamp = (String) latestData.getOrDefault("timestamp", "");
                
                latestCoordinate = new CoordinateData(coordX, coordY, timestamp, "redis");
                logger.debug("Updated coordinates: X={}, Y={}", coordX, coordY);
            }

        } catch (Exception e) {
            logger.error("Error fetching coordinates from Redis: {}", e.getMessage());
        }

        return latestCoordinate;
    }

    /**
     * 테스트용 랜덤 좌표 생성 (Redis에서 데이터가 없을 때 사용)
     */
    public CoordinateData generateRandomCoordinates() {
        Random random = new Random();
        double coordX = Math.round((random.nextDouble() * 1000) * 100.0) / 100.0; // 0-1000, 소수점 2자리
        double coordY = Math.round((random.nextDouble() * 1000) * 100.0) / 100.0;
        String timestamp = String.valueOf(System.currentTimeMillis());
        
        return new CoordinateData(coordX, coordY, timestamp, "random");
    }

    /**
     * Redis 연결 상태 확인
     */
    public boolean isRedisConnected() {
        try {
            String ping = redisTemplate.execute((org.springframework.data.redis.core.RedisCallback<String>) connection -> {
                return connection.ping();
            });
            return "PONG".equals(ping);
        } catch (Exception e) {
            logger.error("Redis connection check failed: {}", e.getMessage());
            return false;
        }
    }

    /**
     * Redis 통계 정보 조회
     */
    public Map<String, Object> getRedisStats() {
        Map<String, Object> stats = new HashMap<>();
        
        try {
            // 총 메시지 수
            Object messageCount = redisTemplate.opsForValue().get("message_count");
            stats.put("messageCount", messageCount != null ? messageCount : 0);
            
            // 메시지 키 수
            Set<String> messageKeys = redisTemplate.keys("message:mqtt-messages:*");
            stats.put("messageKeys", messageKeys != null ? messageKeys.size() : 0);
            
            stats.put("connected", true);
            
        } catch (Exception e) {
            logger.error("Error getting Redis stats: {}", e.getMessage());
            stats.put("connected", false);
            stats.put("error", e.getMessage());
        }
        
        return stats;
    }
}