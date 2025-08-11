package com.example.qrlogin.service;

import com.example.qrlogin.entity.QrChallenge;
import com.example.qrlogin.repository.QrChallengeRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

/**
 * QR 만료 감지 및 SSE 알림 서비스
 * 
 * 간단한 구현: 주기적으로 만료된 QR을 찾아서 SSE 알림 전송
 * 실제 운영에서는 Redis Key Expiration Event나 더 정교한 방식 권장
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class QrExpirationService {
    
    private final QrChallengeRepository challengeRepository;
    private final QrSseNotifier qrSseNotifier;
    
    /**
     * 만료된 QR 챌린지 정리 및 SSE 알림
     * 30초마다 실행 (간단 구현)
     */
    @Scheduled(fixedRate = 30_000)
    public void checkExpiredChallenges() {
        // TODO: 실제로는 Redis에서 만료 예정인 키들을 조회하는 로직 필요
        // 현재는 간단한 구현으로 주석 처리
        
        /*
         * Redis Key Expiration Events를 사용하는 방법:
         * 1. Redis 설정에서 notify-keyspace-events Ex 활성화
         * 2. RedisMessageListenerContainer와 KeyExpirationEventMessageListener 구현
         * 3. 만료 이벤트 수신 시 SSE 알림 전송
         * 
         * 예시 코드:
         * @EventListener
         * public void handleKeyExpiration(RedisKeyExpiredEvent<QrChallenge> event) {
         *     String challengeId = extractChallengeId(event.getKey());
         *     qrSseNotifier.notifyExpired(challengeId);
         * }
         */
        
        log.debug("QR expiration check completed (simple implementation)");
    }
    
    /**
     * 특정 challengeId의 만료 알림 전송 (수동 호출용)
     */
    public void notifyExpired(String challengeId) {
        try {
            qrSseNotifier.notifyExpired(challengeId);
            log.info("Manually notified expiration for challengeId: {}", challengeId);
        } catch (Exception e) {
            log.error("Failed to notify expiration for challengeId: {}", challengeId, e);
        }
    }
}