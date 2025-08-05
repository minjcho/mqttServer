package com.example.websocket.service;

import com.example.websocket.model.CoordinateData;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class CoordinateService {

    private static final Logger logger = LoggerFactory.getLogger(CoordinateService.class);
    
    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;
    
    @Value("${websocket.max-messages:10}")
    private int maxMessages;

    // 최신 좌표 데이터를 캐시
    private volatile CoordinateData latestCoordinate = new CoordinateData(0.0, 0.0, "", "system");

    public CoordinateService(StringRedisTemplate redisTemplate) {
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

            // 오프셋 기준으로 정렬하여 가장 최신 메시지 찾기
            String latestKey = messageKeys.stream()
                .filter(key -> key.startsWith("message:mqtt-messages:"))
                .max((k1, k2) -> {
                    try {
                        // key 형식: message:mqtt-messages:partition:offset
                        int offset1 = Integer.parseInt(k1.substring(k1.lastIndexOf(':') + 1));
                        int offset2 = Integer.parseInt(k2.substring(k2.lastIndexOf(':') + 1));
                        return Integer.compare(offset1, offset2);
                    } catch (Exception e) {
                        return 0;
                    }
                })
                .orElse(null);

            if (latestKey == null) {
                logger.debug("No valid message key found");
                return latestCoordinate;
            }

            logger.debug("🎯 Using latest key: {}", latestKey);

            // Redis에서 해시 데이터 직접 읽기
            Map<Object, Object> rawData = redisTemplate.opsForHash().entries(latestKey);
            
            if (rawData == null || rawData.isEmpty()) {
                logger.debug("❌ No data found for key: {}", latestKey);
                return latestCoordinate;
            }

            logger.debug("📥 Retrieved {} fields from Redis", rawData.size());
            
            // Object를 String으로 변환
            Map<String, String> messageData = new HashMap<>();
            for (Map.Entry<Object, Object> entry : rawData.entrySet()) {
                messageData.put(String.valueOf(entry.getKey()), String.valueOf(entry.getValue()));
            }
            
            if (!messageData.containsKey("message")) {
                logger.debug("❌ No 'message' field found. Available fields: {}", messageData.keySet());
                return latestCoordinate;
            }

            String messageJson = messageData.get("message");
            logger.debug("📝 Raw message JSON: {}", messageJson);
            
            // JSON 파싱
            JsonNode messageNode = objectMapper.readTree(messageJson);
            logger.debug("🔍 Parsed message structure: {}", messageNode.toPrettyString());
            
            // Telegraf 포맷에서 좌표 데이터 추출
            if (messageNode.has("fields") && messageNode.get("fields").has("value")) {
                String valueString = messageNode.get("fields").get("value").asText();
                logger.debug("📊 Extracting coordinates from value: {}", valueString);
                
                // value 필드를 JSON으로 파싱
                JsonNode valueNode = objectMapper.readTree(valueString);
                
                if (valueNode.has("coordX") && valueNode.has("coordY")) {
                    Double coordX = valueNode.get("coordX").asDouble();
                    Double coordY = valueNode.get("coordY").asDouble();
                    String timestamp = messageData.getOrDefault("timestamp", "");
                    
                    // 새로운 좌표로 업데이트
                    latestCoordinate = new CoordinateData(coordX, coordY, timestamp, "redis");
                    
                    logger.info("✅ Successfully updated coordinates: X={}, Y={} from key={}", 
                               coordX, coordY, latestKey);
                    return latestCoordinate;
                } else {
                    logger.debug("⚠️ No coordX/coordY found in value: {}", valueNode);
                }
            } 
            // Python bridge 포맷 지원 (혹시 다른 데이터 소스가 있을 경우)
            else if (messageNode.has("payload")) {
                String payload = messageNode.get("payload").asText();
                logger.debug("🐍 Python bridge format detected, payload: {}", payload);
                
                JsonNode payloadNode = objectMapper.readTree(payload);
                if (payloadNode.has("coordX") && payloadNode.has("coordY")) {
                    Double coordX = payloadNode.get("coordX").asDouble();
                    Double coordY = payloadNode.get("coordY").asDouble();
                    String timestamp = messageData.getOrDefault("timestamp", "");
                    
                    latestCoordinate = new CoordinateData(coordX, coordY, timestamp, "redis");
                    logger.info("✅ Successfully updated coordinates from Python format: X={}, Y={}", coordX, coordY);
                    return latestCoordinate;
                }
            } else {
                logger.debug("❌ Unsupported message format: {}", messageNode);
            }

        } catch (Exception e) {
            logger.error("❌ Error fetching coordinates from Redis: {}", e.getMessage(), e);
        }

        logger.debug("⚠️ Returning cached coordinates: X={}, Y={}, source={}", 
                   latestCoordinate.getCoordX(), latestCoordinate.getCoordY(), latestCoordinate.getSource());
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
            String messageCount = redisTemplate.opsForValue().get("message_count");
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