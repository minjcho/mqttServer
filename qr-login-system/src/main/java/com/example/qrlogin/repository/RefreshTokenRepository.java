package com.example.qrlogin.repository;

import com.example.qrlogin.entity.RefreshToken;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Repository;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Slf4j
@Repository
@RequiredArgsConstructor
public class RefreshTokenRepository {
    
    private final RedisTemplate<String, Object> redisTemplate;
    private static final String KEY_PREFIX = "refresh_token:";
    private static final String USER_TOKEN_PREFIX = "user_tokens:";
    
    @Value("${jwt.refresh-token.expiration}")
    private long refreshTokenExpiration;
    
    public void save(RefreshToken refreshToken) {
        String key = KEY_PREFIX + refreshToken.getRefreshToken();
        String userKey = USER_TOKEN_PREFIX + refreshToken.getUserId();
        
        // Save refresh token
        redisTemplate.opsForValue().set(key, refreshToken, Duration.ofMillis(refreshTokenExpiration));
        
        // Add to user's token list for rotation management
        redisTemplate.opsForList().rightPush(userKey, refreshToken.getRefreshToken());
        redisTemplate.expire(userKey, Duration.ofMillis(refreshTokenExpiration));
        
        log.debug("Saved refresh token for user: {} with TTL: {} ms", 
            refreshToken.getUserId(), refreshTokenExpiration);
    }
    
    public Optional<RefreshToken> findByRefreshToken(String refreshToken) {
        String key = KEY_PREFIX + refreshToken;
        Object result = redisTemplate.opsForValue().get(key);
        
        if (result instanceof RefreshToken) {
            return Optional.of((RefreshToken) result);
        }
        
        return Optional.empty();
    }
    
    public void markAsUsed(String refreshToken, String replacedByToken) {
        Optional<RefreshToken> tokenOpt = findByRefreshToken(refreshToken);
        if (tokenOpt.isPresent()) {
            RefreshToken token = tokenOpt.get();
            token.setUsed(true);
            token.setReplacedByToken(replacedByToken);
            
            String key = KEY_PREFIX + refreshToken;
            Long ttl = redisTemplate.getExpire(key);
            if (ttl != null && ttl > 0) {
                redisTemplate.opsForValue().set(key, token, Duration.ofSeconds(ttl));
                log.debug("Marked refresh token as used: {}", refreshToken);
            }
        }
    }
    
    public void revokeAllUserTokens(String userId) {
        String userKey = USER_TOKEN_PREFIX + userId;
        List<Object> tokens = redisTemplate.opsForList().range(userKey, 0, -1);
        
        if (tokens != null) {
            for (Object tokenObj : tokens) {
                if (tokenObj instanceof String) {
                    String tokenKey = KEY_PREFIX + tokenObj;
                    redisTemplate.delete(tokenKey);
                }
            }
        }
        
        redisTemplate.delete(userKey);
        log.debug("Revoked all refresh tokens for user: {}", userId);
    }
    
    public void delete(String refreshToken) {
        String key = KEY_PREFIX + refreshToken;
        redisTemplate.delete(key);
        log.debug("Deleted refresh token: {}", refreshToken);
    }
    
    public List<RefreshToken> findByUserId(String userId) {
        String userKey = USER_TOKEN_PREFIX + userId;
        List<Object> tokens = redisTemplate.opsForList().range(userKey, 0, -1);
        
        if (tokens == null) {
            return List.of();
        }
        
        return tokens.stream()
            .filter(token -> token instanceof String)
            .map(token -> (String) token)
            .map(this::findByRefreshToken)
            .filter(Optional::isPresent)
            .map(Optional::get)
            .collect(Collectors.toList());
    }
    
    public void cleanupExpiredTokens(String userId) {
        List<RefreshToken> userTokens = findByUserId(userId);
        LocalDateTime now = LocalDateTime.now();
        
        for (RefreshToken token : userTokens) {
            if (token.getExpiresAt().isBefore(now)) {
                delete(token.getRefreshToken());
                
                // Remove from user's token list
                String userKey = USER_TOKEN_PREFIX + userId;
                redisTemplate.opsForList().remove(userKey, 1, token.getRefreshToken());
            }
        }
        
        log.debug("Cleaned up expired tokens for user: {}", userId);
    }
}