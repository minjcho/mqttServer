package com.example.qrlogin.util;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;

@Slf4j
@Component
public class JwtUtil {
    
    @Value("${jwt.secret}")
    private String secret;
    
    @Value("${jwt.access-token.expiration}")
    private Long accessTokenExpiration;
    
    @Value("${jwt.refresh-token.expiration}")
    private Long refreshTokenExpiration;
    
    @Value("${jwt.issuer}")
    private String issuer;
    
    private SecretKey key;
    
    @PostConstruct
    public void init() {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }
    
    public String generateAccessToken(String userId) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", userId);
        claims.put("tokenType", "ACCESS");
        return createToken(claims, userId, accessTokenExpiration);
    }
    
    public String generateAccessToken(String userId, String email, Set<String> roles) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", userId);
        claims.put("email", email);
        claims.put("roles", roles);
        claims.put("tokenType", "ACCESS");
        return createToken(claims, userId, accessTokenExpiration);
    }
    
    public String generateRefreshToken(String userId) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", userId);
        claims.put("tokenType", "REFRESH");
        claims.put("tokenId", UUID.randomUUID().toString());
        return createToken(claims, userId, refreshTokenExpiration);
    }
    
    private String createToken(Map<String, Object> claims, String subject, Long expiration) {
        return Jwts.builder()
            .setClaims(claims)
            .setSubject(subject)
            .setIssuer(issuer)
            .setIssuedAt(new Date(System.currentTimeMillis()))
            .setExpiration(new Date(System.currentTimeMillis() + expiration))
            .signWith(key, SignatureAlgorithm.HS512)
            .compact();
    }
    
    public Boolean validateAccessToken(String token) {
        try {
            Claims claims = extractAllClaims(token);
            String tokenType = claims.get("tokenType", String.class);
            return "ACCESS".equals(tokenType) && !isTokenExpired(token);
        } catch (Exception e) {
            return false;
        }
    }
    
    public Boolean validateRefreshToken(String token) {
        try {
            Claims claims = extractAllClaims(token);
            String tokenType = claims.get("tokenType", String.class);
            return "REFRESH".equals(tokenType) && !isTokenExpired(token);
        } catch (Exception e) {
            return false;
        }
    }
    
    public String extractUserId(String token) {
        return extractClaim(token, Claims::getSubject);
    }
    
    public String extractTokenId(String token) {
        Claims claims = extractAllClaims(token);
        return claims.get("tokenId", String.class);
    }
    
    public Date extractExpiration(String token) {
        return extractClaim(token, Claims::getExpiration);
    }
    
    public <T> T extractClaim(String token, Function<Claims, T> claimsResolver) {
        final Claims claims = extractAllClaims(token);
        return claimsResolver.apply(claims);
    }
    
    public Claims extractAllClaims(String token) {
        return Jwts.parser()
            .setSigningKey(key)
            .build()
            .parseClaimsJws(token)
            .getBody();
    }
    
    private Boolean isTokenExpired(String token) {
        return extractExpiration(token).before(new Date());
    }
    
    public Long getAccessTokenExpirationTime() {
        return accessTokenExpiration;
    }
    
    public Long getRefreshTokenExpirationTime() {
        return refreshTokenExpiration;
    }
}