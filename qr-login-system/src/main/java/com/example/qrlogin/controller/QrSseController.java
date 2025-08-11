package com.example.qrlogin.controller;

import com.example.qrlogin.service.QrSseNotifier;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * SSE 기반 QR 상태 실시간 업데이트 컨트롤러
 * 
 * 사용법:
 * GET /api/qr/stream/{challengeId}
 * - 클라이언트는 EventSource로 연결
 * - QR 상태 변경 시 실시간 알림 수신
 * - 타임아웃: 120초
 */
@Slf4j
@RestController
@RequestMapping("/api/qr")
@RequiredArgsConstructor
public class QrSseController {
    
    private final QrSseNotifier qrSseNotifier;
    
    // 간단한 IP별 레이트 제한 (in-memory 토큰 버킷)
    private final ConcurrentHashMap<String, AtomicLong> rateLimitMap = new ConcurrentHashMap<>();
    private static final long RATE_LIMIT_WINDOW_MS = 60_000; // 1분
    private static final long MAX_CONNECTIONS_PER_IP = 10; // IP당 최대 연결 수
    
    /**
     * SSE 스트림 엔드포인트
     * 
     * @param challengeId QR 챌린지 ID
     * @param request HTTP 요청 (IP 추출용)
     * @return SseEmitter
     */
    @GetMapping(value = "/stream/{challengeId}", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter streamQrStatus(@PathVariable String challengeId,
                                   jakarta.servlet.http.HttpServletRequest request) {
        
        String clientIp = getClientIp(request);
        
        // 간단한 레이트 제한 검사
        if (!isRateLimitAllowed(clientIp)) {
            log.warn("Rate limit exceeded for IP: {} on challengeId: {}", clientIp, challengeId);
            SseEmitter errorEmitter = new SseEmitter(0L);
            try {
                errorEmitter.completeWithError(new RuntimeException("Too many connections"));
            } catch (Exception ignored) {}
            return errorEmitter;
        }
        
        // SSE Emitter 생성 (120초 타임아웃)
        SseEmitter emitter = new SseEmitter(120_000L);
        
        // 응답 헤더 설정
        try {
            // 초기 연결 확인 메시지
            emitter.send(SseEmitter.event()
                .name("connected")
                .data("{\"status\":\"connected\",\"challengeId\":\"" + challengeId + "\"}"));
            
        } catch (IOException e) {
            log.error("Failed to send initial connection message for challengeId: {}", challengeId, e);
            emitter.completeWithError(e);
            return emitter;
        }
        
        // Notifier에 등록
        qrSseNotifier.register(challengeId, emitter);
        
        log.info("SSE connection established for challengeId: {} from IP: {}", challengeId, clientIp);
        
        return emitter;
    }
    
    /**
     * 모니터링용 엔드포인트 - 활성 연결 수 조회
     */
    @GetMapping("/stream/stats/{challengeId}")
    public Object getStreamStats(@PathVariable String challengeId) {
        return java.util.Map.of(
            "challengeId", challengeId,
            "subscriberCount", qrSseNotifier.getSubscriberCount(challengeId),
            "totalActiveConnections", qrSseNotifier.getTotalActiveConnections()
        );
    }
    
    /**
     * 클라이언트 IP 추출
     */
    private String getClientIp(jakarta.servlet.http.HttpServletRequest request) {
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isEmpty()) {
            return xForwardedFor.split(",")[0].trim();
        }
        
        String xRealIp = request.getHeader("X-Real-IP");
        if (xRealIp != null && !xRealIp.isEmpty()) {
            return xRealIp;
        }
        
        return request.getRemoteAddr();
    }
    
    /**
     * 간단한 IP별 레이트 제한 검사
     * TODO: 실제 운영 환경에서는 Redis 기반 분산 레이트 리미터 사용 권장
     */
    private boolean isRateLimitAllowed(String clientIp) {
        long currentTime = System.currentTimeMillis();
        AtomicLong connectionCount = rateLimitMap.computeIfAbsent(clientIp, k -> new AtomicLong(0));
        
        // 시간 윈도우가 지나면 카운트 리셋
        long lastReset = connectionCount.get() >>> 32; // 상위 32비트에 타임스탬프 저장
        if (currentTime - lastReset > RATE_LIMIT_WINDOW_MS) {
            connectionCount.set((currentTime << 32) | 1); // 새 윈도우 시작
            return true;
        }
        
        long currentConnections = connectionCount.get() & 0xFFFFFFFFL; // 하위 32비트에서 카운트 추출
        if (currentConnections >= MAX_CONNECTIONS_PER_IP) {
            return false;
        }
        
        connectionCount.incrementAndGet();
        return true;
    }
}