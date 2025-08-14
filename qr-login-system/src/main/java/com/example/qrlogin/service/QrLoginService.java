package com.example.qrlogin.service;

import com.example.qrlogin.dto.*;
import com.example.qrlogin.entity.QrChallenge;
import com.example.qrlogin.exception.InvalidChallengeException;
import com.example.qrlogin.exception.InvalidOtcException;
import com.example.qrlogin.repository.QrChallengeRepository;
import com.example.qrlogin.service.TokenService;
import com.example.qrlogin.util.JwtUtil;
import com.example.qrlogin.util.QrGenerator;
import com.google.zxing.WriterException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Base64;

@Slf4j
@Service
@RequiredArgsConstructor
public class QrLoginService {
    
    private final QrChallengeRepository challengeRepository;
    private final QrGenerator qrGenerator;
    private final JwtUtil jwtUtil;
    private final TokenService tokenService;
    private final QrSseNotifier qrSseNotifier;
    private final com.example.qrlogin.user.UserService userService;
    private final SecureRandom secureRandom = new SecureRandom();
    
    public QrInitResponse initializeQrLogin() {
        try {
            // Generate challengeId and nonce
            String challengeId = generateBase64UrlSafeString(32);
            String nonce = generateBase64UrlSafeString(16);
            
            // Create QR challenge entity
            QrChallenge challenge = QrChallenge.builder()
                .challengeId(challengeId)
                .nonce(nonce)
                .status(QrChallenge.QrStatus.PENDING)
                .createdAt(LocalDateTime.now())
                .build();
            
            // Save to Redis
            challengeRepository.save(challenge);
            
            // Generate QR code content
            String qrContent = String.format("{\"challengeId\":\"%s\",\"nonce\":\"%s\"}", 
                challengeId, nonce);
            
            // Generate QR code image
            byte[] qrImage = qrGenerator.generateQRCodeImage(qrContent);
            
            log.info("QR login initialized with challengeId: {}", challengeId);
            
            return QrInitResponse.builder()
                .challengeId(challengeId)
                .nonce(nonce)
                .qrImage(qrImage)
                .build();
                
        } catch (WriterException | IOException e) {
            log.error("Failed to generate QR code", e);
            throw new RuntimeException("Failed to generate QR code", e);
        }
    }
    
    public QrApproveResponse approveQrLogin(QrApproveRequest request) {
        // Get authenticated user from security context
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        String userId = authentication.getName();
        
        // Find challenge in Redis
        QrChallenge challenge = challengeRepository.findByChallengeId(request.getChallengeId())
            .orElseThrow(() -> new InvalidChallengeException("Invalid or expired challenge"));
        
        // Verify nonce
        if (!challenge.getNonce().equals(request.getNonce())) {
            throw new InvalidChallengeException("Invalid nonce");
        }
        
        // Check if already approved or exchanged
        if (challenge.getStatus() != QrChallenge.QrStatus.PENDING) {
            throw new InvalidChallengeException("Challenge is no longer pending");
        }
        
        // Generate OTC
        String otc = generateBase64UrlSafeString(32);
        
        // Update challenge
        challenge.setStatus(QrChallenge.QrStatus.APPROVED);
        challenge.setUserId(userId);
        challenge.setOtc(otc);
        challenge.setApprovedAt(LocalDateTime.now());
        
        // Save updated challenge and OTC mapping
        challengeRepository.update(challenge);
        challengeRepository.saveOtc(otc, challenge.getChallengeId());
        
        // SSE 알림: QR 승인됨 (OTC 포함)
        try {
            // OTC 만료 시간 계산 (60초 후)
            java.time.Instant expiresAt = java.time.Instant.now().plusSeconds(60);
            qrSseNotifier.notifyApproved(challenge.getChallengeId(), otc, expiresAt);
        } catch (Exception e) {
            log.warn("Failed to send SSE notification for approved QR: {}", challenge.getChallengeId(), e);
        }
        
        log.info("QR login approved for challengeId: {} by user: {}", request.getChallengeId(), userId);
        
        return QrApproveResponse.builder()
            .otc(otc)
            .message("QR login approved successfully")
            .build();
    }
    
    public QrStatusResponse getQrStatus(String challengeId) {
        QrChallenge challenge = challengeRepository.findByChallengeId(challengeId)
            .orElse(null);
        
        if (challenge == null) {
            return QrStatusResponse.builder()
                .challengeId(challengeId)
                .status(QrChallenge.QrStatus.EXPIRED)
                .build();
        }
        
        QrStatusResponse.QrStatusResponseBuilder responseBuilder = QrStatusResponse.builder()
            .challengeId(challengeId)
            .status(challenge.getStatus());
        
        // Include OTC only if status is APPROVED
        if (challenge.getStatus() == QrChallenge.QrStatus.APPROVED && challenge.getOtc() != null) {
            responseBuilder.otc(challenge.getOtc());
        }
        
        return responseBuilder.build();
    }
    
    public QrExchangeResponse exchangeOtcForToken(QrExchangeRequest request) {
        String otc = request.getOtc();
        
        // Find challengeId by OTC
        String challengeId = challengeRepository.findChallengeIdByOtc(otc)
            .orElseThrow(() -> new InvalidOtcException("Invalid or expired OTC"));
        
        // Find challenge
        QrChallenge challenge = challengeRepository.findByChallengeId(challengeId)
            .orElseThrow(() -> new InvalidOtcException("Invalid or expired OTC"));
        
        // Verify status is APPROVED
        if (challenge.getStatus() != QrChallenge.QrStatus.APPROVED) {
            throw new InvalidOtcException("OTC is not in approved state");
        }
        
        // Verify OTC matches
        if (!otc.equals(challenge.getOtc())) {
            throw new InvalidOtcException("OTC mismatch");
        }
        
        // Get user info for desktop token generation
        String userId = challenge.getUserId();
        com.example.qrlogin.user.User user = userService.getUserById(Long.valueOf(userId));
        
        // Generate desktop access token with user info
        java.util.Set<String> roleNames = user.getRoles().stream()
            .map(com.example.qrlogin.user.Role::name)
            .collect(java.util.stream.Collectors.toSet());
        
        String desktopAccessToken = jwtUtil.generateAccessToken(userId, user.getEmail(), roleNames, user.getOrinId());
        String refreshToken = jwtUtil.generateRefreshToken(userId);
        
        // Save refresh token
        tokenService.saveRefreshToken(userId, refreshToken);
        
        // Update status to EXCHANGED and remove OTC
        challenge.setStatus(QrChallenge.QrStatus.EXCHANGED);
        challenge.setExchangedAt(LocalDateTime.now());
        challengeRepository.update(challenge);
        
        // Delete OTC from Redis
        challengeRepository.deleteOtc(otc);
        
        log.info("OTC exchanged for desktop JWT token for user: {}", userId);
        
        return QrExchangeResponse.builder()
            .accessToken(desktopAccessToken)
            .refreshToken(refreshToken)
            .tokenType("Bearer")
            .accessTokenExpiresIn(jwtUtil.getAccessTokenExpirationTime() / 1000)
            .refreshTokenExpiresIn(jwtUtil.getRefreshTokenExpirationTime() / 1000)
            .orinId(user.getOrinId())
            .build();
    }
    
    private String generateBase64UrlSafeString(int byteLength) {
        byte[] bytes = new byte[byteLength];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }
}