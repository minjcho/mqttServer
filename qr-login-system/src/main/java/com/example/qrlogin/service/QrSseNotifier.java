package com.example.qrlogin.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.lang.Nullable;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.time.Instant;
import java.util.Iterator;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * SSE 기반 QR 상태 알림 서비스
 * 
 * 프론트엔드 JavaScript 예시:
 * <pre>
 * const es = new EventSource(`/api/qr/stream/${challengeId}`);
 * es.onmessage = (e) => {
 *   const msg = JSON.parse(e.data);
 *   if (msg.status === 'APPROVED') {
 *     // 필요시 교환 API 호출 후 페이지 전환
 *     // await fetch('/api/qr/exchange', { method:'POST', body: JSON.stringify({ otc }) })
 *     window.location.reload();
 *   }
 *   if (msg.status === 'EXPIRED') {
 *     // QR 재생성 UI 노출
 *   }
 * };
 * es.onerror = () => { es.close(); };
 * </pre>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class QrSseNotifier {
    
    private final ObjectMapper objectMapper;
    
    // challengeId -> List of SseEmitters
    private final ConcurrentHashMap<String, CopyOnWriteArrayList<SseEmitter>> emitters = new ConcurrentHashMap<>();
    
    /**
     * SSE 연결 등록
     */
    public void register(String challengeId, SseEmitter emitter) {
        emitters.computeIfAbsent(challengeId, k -> new CopyOnWriteArrayList<>()).add(emitter);
        
        // 연결 종료 시 정리 처리
        emitter.onCompletion(() -> removeEmitter(challengeId, emitter));
        emitter.onTimeout(() -> removeEmitter(challengeId, emitter));
        emitter.onError((throwable) -> {
            log.debug("SSE error for challengeId {}: {}", challengeId, throwable.getMessage());
            removeEmitter(challengeId, emitter);
        });
        
        log.debug("Registered SSE emitter for challengeId: {}", challengeId);
    }
    
    /**
     * QR 승인 시 구독자들에게 알림 전송 후 연결 종료
     */
    public void notifyApproved(String challengeId, @Nullable Instant expiresAt) {
        try {
            Map<String, Object> message = Map.of(
                "challengeId", challengeId,
                "status", "APPROVED",
                "expiresAt", expiresAt != null ? expiresAt.toString() : ""
            );
            
            String jsonData = objectMapper.writeValueAsString(message);
            sendToAllAndClose(challengeId, jsonData);
            
            log.info("Notified APPROVED status for challengeId: {}", challengeId);
        } catch (Exception e) {
            log.error("Failed to notify approved status for challengeId: {}", challengeId, e);
        }
    }
    
    /**
     * QR 만료 시 구독자들에게 알림 전송 후 연결 종료
     */
    public void notifyExpired(String challengeId) {
        try {
            Map<String, Object> message = Map.of(
                "challengeId", challengeId,
                "status", "EXPIRED"
            );
            
            String jsonData = objectMapper.writeValueAsString(message);
            sendToAllAndClose(challengeId, jsonData);
            
            log.info("Notified EXPIRED status for challengeId: {}", challengeId);
        } catch (Exception e) {
            log.error("Failed to notify expired status for challengeId: {}", challengeId, e);
        }
    }
    
    /**
     * 하트비트 전송 (15초마다)
     * 연결 유지 및 끊어진 연결 정리
     */
    @Scheduled(fixedRate = 15000)
    public void sendHeartbeat() {
        for (Map.Entry<String, CopyOnWriteArrayList<SseEmitter>> entry : emitters.entrySet()) {
            String challengeId = entry.getKey();
            CopyOnWriteArrayList<SseEmitter> emitterList = entry.getValue();
            
            Iterator<SseEmitter> iterator = emitterList.iterator();
            while (iterator.hasNext()) {
                SseEmitter emitter = iterator.next();
                try {
                    emitter.send(SseEmitter.event().comment("ping"));
                } catch (IOException e) {
                    log.debug("Heartbeat failed for challengeId: {}, removing emitter", challengeId);
                    iterator.remove();
                    try {
                        emitter.complete();
                    } catch (Exception ignored) {}
                }
            }
            
            // 빈 리스트 제거
            if (emitterList.isEmpty()) {
                emitters.remove(challengeId);
            }
        }
    }
    
    /**
     * 모든 구독자에게 메시지 전송 후 연결 종료
     */
    private void sendToAllAndClose(String challengeId, String jsonData) {
        CopyOnWriteArrayList<SseEmitter> emitterList = emitters.get(challengeId);
        if (emitterList != null) {
            for (SseEmitter emitter : emitterList) {
                try {
                    emitter.send(SseEmitter.event()
                        .name("message")
                        .data(jsonData));
                    emitter.complete();
                } catch (IOException e) {
                    log.debug("Failed to send message to emitter for challengeId: {}", challengeId);
                    try {
                        emitter.completeWithError(e);
                    } catch (Exception ignored) {}
                }
            }
            // 모든 emitter 전송 후 정리
            emitters.remove(challengeId);
        }
    }
    
    /**
     * 특정 emitter 제거
     */
    private void removeEmitter(String challengeId, SseEmitter emitter) {
        CopyOnWriteArrayList<SseEmitter> emitterList = emitters.get(challengeId);
        if (emitterList != null) {
            emitterList.remove(emitter);
            if (emitterList.isEmpty()) {
                emitters.remove(challengeId);
            }
        }
        log.debug("Removed SSE emitter for challengeId: {}", challengeId);
    }
    
    /**
     * 현재 등록된 구독자 수 반환 (모니터링용)
     */
    public int getSubscriberCount(String challengeId) {
        CopyOnWriteArrayList<SseEmitter> emitterList = emitters.get(challengeId);
        return emitterList != null ? emitterList.size() : 0;
    }
    
    /**
     * 전체 활성 연결 수 반환 (모니터링용)
     */
    public int getTotalActiveConnections() {
        return emitters.values().stream().mapToInt(CopyOnWriteArrayList::size).sum();
    }
}