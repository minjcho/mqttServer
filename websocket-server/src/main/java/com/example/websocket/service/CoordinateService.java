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

    // Redis Key Patterns and Prefixes
    private static final String REDIS_KEY_PREFIX_MESSAGE = "message";
    private static final String REDIS_KEY_PREFIX_ORIN = "orin";
    private static final String REDIS_KEY_SUFFIX_LATEST = "latest";
    private static final String REDIS_KEY_MESSAGE_COUNT = "message_count";
    private static final String REDIS_KEY_SEPARATOR = ":";

    // Message Field Names
    private static final String FIELD_DATA = "data";
    private static final String FIELD_TIMESTAMP = "timestamp";
    private static final String FIELD_MESSAGE = "message";

    // JSON Field Names
    private static final String JSON_FIELD_FIELDS = "fields";
    private static final String JSON_FIELD_VALUE = "value";
    private static final String JSON_FIELD_PAYLOAD = "payload";
    private static final String JSON_FIELD_COORD_X = "coordX";
    private static final String JSON_FIELD_COORD_Y = "coordY";

    // Default Values
    private static final String DEFAULT_SOURCE_SYSTEM = "system";
    private static final String DEFAULT_SOURCE_REDIS = "redis";
    private static final String DEFAULT_SOURCE_RANDOM = "random";

    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;
    
    @Value("${websocket.max-messages:10}")
    private int maxMessages;

    private volatile CoordinateData latestCoordinate = new CoordinateData(0.0, 0.0, "", DEFAULT_SOURCE_SYSTEM);

    public CoordinateService(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
        this.objectMapper = new ObjectMapper();
    }

    /**
     * 특정 ORIN ID의 최신 좌표 데이터를 가져와서 파싱
     */
    public CoordinateData getLatestCoordinatesForOrin(String orinId) {
        try {
            String orinKey = REDIS_KEY_PREFIX_ORIN + REDIS_KEY_SEPARATOR + orinId + REDIS_KEY_SEPARATOR + REDIS_KEY_SUFFIX_LATEST;
            Map<Object, Object> rawData = redisTemplate.opsForHash().entries(orinKey);
            
            if (rawData == null || rawData.isEmpty()) {
                logger.debug("No data found for ORIN ID: {}", orinId);
                return null;
            }

            logger.debug("Retrieved ORIN {} data from Redis: {}", orinId, rawData);
            Map<String, String> orinData = new HashMap<>();
            for (Map.Entry<Object, Object> entry : rawData.entrySet()) {
                orinData.put(String.valueOf(entry.getKey()), String.valueOf(entry.getValue()));
            }
            
            if (!orinData.containsKey(FIELD_DATA)) {
                logger.debug("No '{}' field found for ORIN ID: {}. Available fields: {}", FIELD_DATA, orinId, orinData.keySet());
                return null;
            }

            String dataJson = orinData.get(FIELD_DATA);
            String timestamp = orinData.getOrDefault(FIELD_TIMESTAMP, "");
            JsonNode dataNode = objectMapper.readTree(dataJson);

            if (dataNode.has(JSON_FIELD_COORD_X) && dataNode.has(JSON_FIELD_COORD_Y)) {
                Double coordX = dataNode.get(JSON_FIELD_COORD_X).asDouble();
                Double coordY = dataNode.get(JSON_FIELD_COORD_Y).asDouble();

                CoordinateData coordinate = new CoordinateData(coordX, coordY, timestamp, REDIS_KEY_PREFIX_ORIN + REDIS_KEY_SEPARATOR + orinId);
                logger.debug("Successfully parsed coordinates for ORIN {}: X={}, Y={}", orinId, coordX, coordY);
                return coordinate;
            } else {
                logger.debug("No coordX/coordY found in data for ORIN ID: {}", orinId);
            }

        } catch (Exception e) {
            logger.error("Error fetching coordinates for ORIN ID {}: {}", orinId, e.getMessage(), e);
        }

        return null;
    }

    /**
     * Redis에서 최신 좌표 데이터를 가져와서 파싱 (기존 호환성)
     */
    public CoordinateData getLatestCoordinates() {
        try {
            Set<String> messageKeys = redisTemplate.keys(REDIS_KEY_PREFIX_MESSAGE + REDIS_KEY_SEPARATOR + "mqtt-messages" + REDIS_KEY_SEPARATOR + "*");
            
            if (messageKeys == null || messageKeys.isEmpty()) {
                logger.debug("No message keys found in Redis");
                return latestCoordinate;
            }

            String latestKey = messageKeys.stream()
                .filter(key -> key.startsWith("message:mqtt-messages:"))
                .max((k1, k2) -> {
                    try {
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

            Map<Object, Object> rawData = redisTemplate.opsForHash().entries(latestKey);
            
            if (rawData == null || rawData.isEmpty()) {
                logger.debug("❌ No data found for key: {}", latestKey);
                return latestCoordinate;
            }

            logger.debug("📥 Retrieved {} fields from Redis", rawData.size());
            Map<String, String> messageData = new HashMap<>();
            for (Map.Entry<Object, Object> entry : rawData.entrySet()) {
                messageData.put(String.valueOf(entry.getKey()), String.valueOf(entry.getValue()));
            }
            
            if (!messageData.containsKey(FIELD_MESSAGE)) {
                logger.debug("❌ No '{}' field found. Available fields: {}", FIELD_MESSAGE, messageData.keySet());
                return latestCoordinate;
            }

            String messageJson = messageData.get(FIELD_MESSAGE);
            logger.debug("📝 Raw message JSON: {}", messageJson);
            JsonNode messageNode = objectMapper.readTree(messageJson);
            logger.debug("🔍 Parsed message structure: {}", messageNode.toPrettyString());
            if (messageNode.has(JSON_FIELD_FIELDS) && messageNode.get(JSON_FIELD_FIELDS).has(JSON_FIELD_VALUE)) {
                String valueString = messageNode.get(JSON_FIELD_FIELDS).get(JSON_FIELD_VALUE).asText();
                logger.debug("📊 Extracting coordinates from value: {}", valueString);
                JsonNode valueNode = objectMapper.readTree(valueString);

                if (valueNode.has(JSON_FIELD_COORD_X) && valueNode.has(JSON_FIELD_COORD_Y)) {
                    Double coordX = valueNode.get(JSON_FIELD_COORD_X).asDouble();
                    Double coordY = valueNode.get(JSON_FIELD_COORD_Y).asDouble();
                    String timestamp = messageData.getOrDefault(FIELD_TIMESTAMP, "");
                    latestCoordinate = new CoordinateData(coordX, coordY, timestamp, DEFAULT_SOURCE_REDIS);
                    
                    logger.info("✅ Successfully updated coordinates: X={}, Y={} from key={}", 
                               coordX, coordY, latestKey);
                    return latestCoordinate;
                } else {
                    logger.debug("⚠️ No coordX/coordY found in value: {}", valueNode);
                }
            }
            else if (messageNode.has(JSON_FIELD_PAYLOAD)) {
                String payload = messageNode.get(JSON_FIELD_PAYLOAD).asText();
                logger.debug("🐍 Python bridge format detected, payload: {}", payload);

                JsonNode payloadNode = objectMapper.readTree(payload);
                if (payloadNode.has(JSON_FIELD_COORD_X) && payloadNode.has(JSON_FIELD_COORD_Y)) {
                    Double coordX = payloadNode.get(JSON_FIELD_COORD_X).asDouble();
                    Double coordY = payloadNode.get(JSON_FIELD_COORD_Y).asDouble();
                    String timestamp = messageData.getOrDefault(FIELD_TIMESTAMP, "");

                    latestCoordinate = new CoordinateData(coordX, coordY, timestamp, DEFAULT_SOURCE_REDIS);
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

        return new CoordinateData(coordX, coordY, timestamp, DEFAULT_SOURCE_RANDOM);
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
            String messageCount = redisTemplate.opsForValue().get(REDIS_KEY_MESSAGE_COUNT);
            stats.put("messageCount", messageCount != null ? messageCount : 0);
            Set<String> messageKeys = redisTemplate.keys(REDIS_KEY_PREFIX_MESSAGE + REDIS_KEY_SEPARATOR + "mqtt-messages" + REDIS_KEY_SEPARATOR + "*");
            stats.put("messageKeys", messageKeys != null ? messageKeys.size() : 0);
            
            stats.put("connected", true);
            
        } catch (Exception e) {
            logger.error("Error getting Redis stats: {}", e.getMessage());
            stats.put("connected", false);
            stats.put("error", e.getMessage());
        }
        
        return stats;
    }

    /**
     * Redis Template getter for scheduler access
     */
    public StringRedisTemplate getRedisTemplate() {
        return redisTemplate;
    }
}