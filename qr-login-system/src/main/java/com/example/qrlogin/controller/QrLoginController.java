package com.example.qrlogin.controller;

import com.example.qrlogin.dto.*;
import com.example.qrlogin.service.QrLoginService;
import com.example.qrlogin.service.TokenService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@RequestMapping("/api/qr")
@RequiredArgsConstructor
@Tag(name = "QR 로그인", description = "QR 코드 기반 로그인 시스템 API")
public class QrLoginController {
    
    private final QrLoginService qrLoginService;
    private final TokenService tokenService;
    
    @Operation(summary = "QR 코드 생성", description = "새로운 QR 로그인 세션을 시작하고 QR 코드 이미지를 생성합니다.")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "QR 코드 생성 성공", 
            content = @Content(mediaType = "image/png")),
        @ApiResponse(responseCode = "500", description = "QR 코드 생성 실패")
    })
    @PostMapping("/init")
    public ResponseEntity<?> initializeQrLogin() {
        try {
            QrInitResponse response = qrLoginService.initializeQrLogin();
            
            // Return QR image as PNG
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.IMAGE_PNG);
            headers.add("X-Challenge-Id", response.getChallengeId());
            headers.add("X-Nonce", response.getNonce());
            
            return ResponseEntity.ok()
                .headers(headers)
                .body(response.getQrImage());
                
        } catch (Exception e) {
            log.error("Failed to initialize QR login", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body("Failed to generate QR code");
        }
    }
    
    @Operation(summary = "QR 코드 승인", description = "모바일에서 QR 코드를 승인합니다. JWT 인증이 필요합니다.")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "QR 코드 승인 성공",
            content = @Content(mediaType = "application/json", schema = @Schema(implementation = QrApproveResponse.class))),
        @ApiResponse(responseCode = "400", description = "잘못된 요청 또는 만료된 챌린지"),
        @ApiResponse(responseCode = "401", description = "인증 필요")
    })
    @SecurityRequirement(name = "bearerAuth")
    @PostMapping("/approve")
    public ResponseEntity<QrApproveResponse> approveQrLogin(
        @Parameter(description = "QR 승인 요청 정보", required = true)
        @Valid @RequestBody QrApproveRequest request) {
        log.info("QR approve request received - challengeId: {}, nonce: {}", 
            request.getChallengeId(), request.getNonce());
        try {
            QrApproveResponse response = qrLoginService.approveQrLogin(request);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Failed to approve QR login - challengeId: {}, nonce: {}", 
                request.getChallengeId(), request.getNonce(), e);
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(QrApproveResponse.builder()
                    .message(e.getMessage())
                    .build());
        }
    }
    
    @GetMapping("/status/{challengeId}")
    public ResponseEntity<QrStatusResponse> getQrStatus(@PathVariable String challengeId) {
        QrStatusResponse response = qrLoginService.getQrStatus(challengeId);
        return ResponseEntity.ok(response);
    }
    
    @PostMapping("/exchange")
    public ResponseEntity<QrExchangeResponse> exchangeOtcForToken(@Valid @RequestBody QrExchangeRequest request) {
        try {
            QrExchangeResponse response = qrLoginService.exchangeOtcForToken(request);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Failed to exchange OTC for token", e);
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(QrExchangeResponse.builder()
                    .accessToken(null)
                    .refreshToken(null)
                    .tokenType("Bearer")
                    .accessTokenExpiresIn(0L)
                    .refreshTokenExpiresIn(0L)
                    .build());
        }
    }
    
    @PostMapping("/token/refresh")
    public ResponseEntity<TokenResponse> refreshToken(@Valid @RequestBody RefreshTokenRequest request) {
        try {
            TokenResponse response = tokenService.refreshTokens(request);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("Failed to refresh token", e);
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(TokenResponse.builder()
                    .accessToken(null)
                    .refreshToken(null)
                    .tokenType("Bearer")
                    .accessTokenExpiresIn(0L)
                    .refreshTokenExpiresIn(0L)
                    .build());
        }
    }
}