package com.example.qrlogin.repository;

import com.example.qrlogin.entity.QrChallenge;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Repository;

import java.time.Duration;
import java.util.Optional;

@Slf4j
@Repository
@RequiredArgsConstructor
public class QrChallengeRepository {
    
    private final RedisTemplate<String, Object> redisTemplate;
    private static final String KEY_PREFIX = "qr:challenge:";
    private static final String OTC_PREFIX = "qr:otc:";
    
    @Value("${qr.challenge.ttl}")
    private long challengeTtl;
    
    @Value("${qr.otc.ttl}")
    private long otcTtl;
    
    public void save(QrChallenge challenge) {
        String key = KEY_PREFIX + challenge.getChallengeId();
        redisTemplate.opsForValue().set(key, challenge, Duration.ofSeconds(challengeTtl));
        log.debug("Saved QR challenge with ID: {} for {} seconds", challenge.getChallengeId(), challengeTtl);
    }
    
    public Optional<QrChallenge> findByChallengeId(String challengeId) {
        String key = KEY_PREFIX + challengeId;
        Object result = redisTemplate.opsForValue().get(key);
        
        if (result instanceof QrChallenge) {
            return Optional.of((QrChallenge) result);
        }
        
        return Optional.empty();
    }
    
    public void update(QrChallenge challenge) {
        String key = KEY_PREFIX + challenge.getChallengeId();
        Long ttl = redisTemplate.getExpire(key);
        if (ttl != null && ttl > 0) {
            redisTemplate.opsForValue().set(key, challenge, Duration.ofSeconds(ttl));
            log.debug("Updated QR challenge with ID: {}", challenge.getChallengeId());
        }
    }
    
    public void saveOtc(String otc, String challengeId) {
        String key = OTC_PREFIX + otc;
        redisTemplate.opsForValue().set(key, challengeId, Duration.ofSeconds(otcTtl));
        log.debug("Saved OTC for challenge ID: {} for {} seconds", challengeId, otcTtl);
    }
    
    public Optional<String> findChallengeIdByOtc(String otc) {
        String key = OTC_PREFIX + otc;
        Object result = redisTemplate.opsForValue().get(key);
        
        if (result instanceof String) {
            return Optional.of((String) result);
        }
        
        return Optional.empty();
    }
    
    public void deleteOtc(String otc) {
        String key = OTC_PREFIX + otc;
        redisTemplate.delete(key);
        log.debug("Deleted OTC: {}", otc);
    }
    
    public void delete(String challengeId) {
        String key = KEY_PREFIX + challengeId;
        redisTemplate.delete(key);
        log.debug("Deleted QR challenge with ID: {}", challengeId);
    }
}