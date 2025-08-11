package com.example.qrlogin.service;

import com.example.qrlogin.dto.RefreshTokenRequest;
import com.example.qrlogin.dto.TokenResponse;
import com.example.qrlogin.entity.RefreshToken;
import com.example.qrlogin.exception.InvalidOtcException;
import com.example.qrlogin.repository.RefreshTokenRepository;
import com.example.qrlogin.util.JwtUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class TokenService {
    
    private final JwtUtil jwtUtil;
    private final RefreshTokenRepository refreshTokenRepository;
    
    public TokenResponse generateTokens(String userId) {
        // Clean up any expired tokens first
        refreshTokenRepository.cleanupExpiredTokens(userId);
        
        // Generate new tokens
        String accessToken = jwtUtil.generateAccessToken(userId);
        String refreshToken = jwtUtil.generateRefreshToken(userId);
        String tokenId = jwtUtil.extractTokenId(refreshToken);
        
        // Save refresh token to repository
        RefreshToken refreshTokenEntity = RefreshToken.builder()
            .tokenId(tokenId)
            .userId(userId)
            .refreshToken(refreshToken)
            .createdAt(LocalDateTime.now())
            .expiresAt(LocalDateTime.now().plusSeconds(jwtUtil.getRefreshTokenExpirationTime() / 1000))
            .used(false)
            .build();
        
        refreshTokenRepository.save(refreshTokenEntity);
        
        log.info("Generated new token pair for user: {}", userId);
        
        return TokenResponse.builder()
            .accessToken(accessToken)
            .refreshToken(refreshToken)
            .tokenType("Bearer")
            .accessTokenExpiresIn(jwtUtil.getAccessTokenExpirationTime() / 1000) // Convert to seconds
            .refreshTokenExpiresIn(jwtUtil.getRefreshTokenExpirationTime() / 1000) // Convert to seconds
            .build();
    }
    
    public TokenResponse refreshTokens(RefreshTokenRequest request) {
        String refreshToken = request.getRefreshToken();
        
        // Validate refresh token format
        if (!jwtUtil.validateRefreshToken(refreshToken)) {
            throw new InvalidOtcException("Invalid refresh token");
        }
        
        // Find refresh token in repository
        RefreshToken storedToken = refreshTokenRepository.findByRefreshToken(refreshToken)
            .orElseThrow(() -> new InvalidOtcException("Refresh token not found or expired"));
        
        // Check if token is already used (potential token theft)
        if (storedToken.getUsed()) {
            log.warn("Attempted to use already consumed refresh token. Possible token theft for user: {}", 
                storedToken.getUserId());
            
            // Revoke all tokens for this user as security measure
            refreshTokenRepository.revokeAllUserTokens(storedToken.getUserId());
            throw new InvalidOtcException("Refresh token has been compromised. Please login again.");
        }
        
        // Check if token is expired
        if (storedToken.getExpiresAt().isBefore(LocalDateTime.now())) {
            refreshTokenRepository.delete(refreshToken);
            throw new InvalidOtcException("Refresh token has expired");
        }
        
        String userId = storedToken.getUserId();
        
        // Generate new token pair
        String newAccessToken = jwtUtil.generateAccessToken(userId);
        String newRefreshToken = jwtUtil.generateRefreshToken(userId);
        String newTokenId = jwtUtil.extractTokenId(newRefreshToken);
        
        // Mark old refresh token as used
        refreshTokenRepository.markAsUsed(refreshToken, newRefreshToken);
        
        // Save new refresh token
        RefreshToken newRefreshTokenEntity = RefreshToken.builder()
            .tokenId(newTokenId)
            .userId(userId)
            .refreshToken(newRefreshToken)
            .createdAt(LocalDateTime.now())
            .expiresAt(LocalDateTime.now().plusSeconds(jwtUtil.getRefreshTokenExpirationTime() / 1000))
            .used(false)
            .build();
        
        refreshTokenRepository.save(newRefreshTokenEntity);
        
        log.info("Refreshed token pair for user: {}", userId);
        
        return TokenResponse.builder()
            .accessToken(newAccessToken)
            .refreshToken(newRefreshToken)
            .tokenType("Bearer")
            .accessTokenExpiresIn(jwtUtil.getAccessTokenExpirationTime() / 1000)
            .refreshTokenExpiresIn(jwtUtil.getRefreshTokenExpirationTime() / 1000)
            .build();
    }
    
    public void revokeRefreshToken(String refreshToken) {
        refreshTokenRepository.findByRefreshToken(refreshToken)
            .ifPresent(token -> {
                refreshTokenRepository.delete(refreshToken);
                log.info("Revoked refresh token for user: {}", token.getUserId());
            });
    }
    
    public void revokeAllUserTokens(String userId) {
        refreshTokenRepository.revokeAllUserTokens(userId);
        log.info("Revoked all tokens for user: {}", userId);
    }
    
    public void saveRefreshToken(String userId, String refreshToken) {
        String tokenId = jwtUtil.extractTokenId(refreshToken);
        
        RefreshToken refreshTokenEntity = RefreshToken.builder()
            .tokenId(tokenId)
            .userId(userId)
            .refreshToken(refreshToken)
            .createdAt(LocalDateTime.now())
            .expiresAt(LocalDateTime.now().plusSeconds(jwtUtil.getRefreshTokenExpirationTime() / 1000))
            .used(false)
            .build();
        
        refreshTokenRepository.save(refreshTokenEntity);
        log.debug("Saved refresh token for user: {}", userId);
    }
}