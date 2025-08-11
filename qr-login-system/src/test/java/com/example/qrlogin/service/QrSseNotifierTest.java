package com.example.qrlogin.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.time.Instant;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class QrSseNotifierTest {
    
    private QrSseNotifier qrSseNotifier;
    private ObjectMapper objectMapper;
    
    @BeforeEach
    void setUp() {
        objectMapper = new ObjectMapper();
        qrSseNotifier = new QrSseNotifier(objectMapper);
    }
    
    @Test
    void testRegisterAndNotifyApproved() throws Exception {
        // Given
        String challengeId = "test-challenge-123";
        Instant expiresAt = Instant.now().plusSeconds(60);
        
        SseEmitter mockEmitter = mock(SseEmitter.class);
        CountDownLatch messageLatch = new CountDownLatch(1);
        AtomicReference<SseEmitter.SseEventBuilder> capturedEvent = new AtomicReference<>();
        
        // Mock emitter behavior
        doAnswer(invocation -> {
            SseEmitter.SseEventBuilder eventBuilder = invocation.getArgument(0);
            capturedEvent.set(eventBuilder);
            messageLatch.countDown();
            return null;
        }).when(mockEmitter).send(any(SseEmitter.SseEventBuilder.class));
        
        // When
        qrSseNotifier.register(challengeId, mockEmitter);
        qrSseNotifier.notifyApproved(challengeId, expiresAt);
        
        // Then
        assertTrue(messageLatch.await(1, TimeUnit.SECONDS));
        verify(mockEmitter, times(1)).send(any(SseEmitter.SseEventBuilder.class));
        verify(mockEmitter, times(1)).complete();
        
        assertEquals(1, qrSseNotifier.getSubscriberCount(challengeId));
    }
    
    @Test
    void testNotifyExpired() throws Exception {
        // Given
        String challengeId = "test-challenge-456";
        SseEmitter mockEmitter = mock(SseEmitter.class);
        CountDownLatch messageLatch = new CountDownLatch(1);
        
        doAnswer(invocation -> {
            messageLatch.countDown();
            return null;
        }).when(mockEmitter).send(any(SseEmitter.SseEventBuilder.class));
        
        // When
        qrSseNotifier.register(challengeId, mockEmitter);
        qrSseNotifier.notifyExpired(challengeId);
        
        // Then
        assertTrue(messageLatch.await(1, TimeUnit.SECONDS));
        verify(mockEmitter, times(1)).send(any(SseEmitter.SseEventBuilder.class));
        verify(mockEmitter, times(1)).complete();
    }
    
    @Test
    void testMultipleSubscribersForSameChallenge() throws Exception {
        // Given
        String challengeId = "test-challenge-789";
        SseEmitter mockEmitter1 = mock(SseEmitter.class);
        SseEmitter mockEmitter2 = mock(SseEmitter.class);
        CountDownLatch messageLatch = new CountDownLatch(2);
        
        doAnswer(invocation -> {
            messageLatch.countDown();
            return null;
        }).when(mockEmitter1).send(any(SseEmitter.SseEventBuilder.class));
        
        doAnswer(invocation -> {
            messageLatch.countDown();
            return null;
        }).when(mockEmitter2).send(any(SseEmitter.SseEventBuilder.class));
        
        // When
        qrSseNotifier.register(challengeId, mockEmitter1);
        qrSseNotifier.register(challengeId, mockEmitter2);
        assertEquals(2, qrSseNotifier.getSubscriberCount(challengeId));
        
        qrSseNotifier.notifyApproved(challengeId, null);
        
        // Then
        assertTrue(messageLatch.await(1, TimeUnit.SECONDS));
        verify(mockEmitter1, times(1)).send(any(SseEmitter.SseEventBuilder.class));
        verify(mockEmitter2, times(1)).send(any(SseEmitter.SseEventBuilder.class));
        verify(mockEmitter1, times(1)).complete();
        verify(mockEmitter2, times(1)).complete();
    }
    
    @Test
    void testEmitterCleanupOnError() throws Exception {
        // Given
        String challengeId = "test-challenge-error";
        SseEmitter mockEmitter = mock(SseEmitter.class);
        
        // Emitter가 에러를 던지도록 설정
        doThrow(new RuntimeException("Connection error"))
            .when(mockEmitter).send(any(SseEmitter.SseEventBuilder.class));
        
        // When
        qrSseNotifier.register(challengeId, mockEmitter);
        assertEquals(1, qrSseNotifier.getSubscriberCount(challengeId));
        
        qrSseNotifier.notifyApproved(challengeId, null);
        
        // Then - 에러 발생 시 emitter가 정리되어야 함
        verify(mockEmitter, times(1)).send(any(SseEmitter.SseEventBuilder.class));
        verify(mockEmitter, times(1)).completeWithError(any(Exception.class));
    }
    
    @Test
    void testHeartbeatRemovesFailedEmitters() throws Exception {
        // Given
        String challengeId = "test-challenge-heartbeat";
        SseEmitter mockEmitter = mock(SseEmitter.class);
        
        // Heartbeat 시 IOException 발생하도록 설정
        doThrow(new java.io.IOException("Connection closed"))
            .when(mockEmitter).send(any(SseEmitter.SseEventBuilder.class));
        
        // When
        qrSseNotifier.register(challengeId, mockEmitter);
        assertEquals(1, qrSseNotifier.getSubscriberCount(challengeId));
        
        qrSseNotifier.sendHeartbeat(); // 하트비트 실행
        
        // Then - 실패한 emitter가 제거되어야 함
        assertEquals(0, qrSseNotifier.getSubscriberCount(challengeId));
        verify(mockEmitter, times(1)).complete();
    }
    
    @Test
    void testGetTotalActiveConnections() {
        // Given
        SseEmitter mockEmitter1 = mock(SseEmitter.class);
        SseEmitter mockEmitter2 = mock(SseEmitter.class);
        SseEmitter mockEmitter3 = mock(SseEmitter.class);
        
        // When
        qrSseNotifier.register("challenge1", mockEmitter1);
        qrSseNotifier.register("challenge1", mockEmitter2);
        qrSseNotifier.register("challenge2", mockEmitter3);
        
        // Then
        assertEquals(3, qrSseNotifier.getTotalActiveConnections());
        assertEquals(2, qrSseNotifier.getSubscriberCount("challenge1"));
        assertEquals(1, qrSseNotifier.getSubscriberCount("challenge2"));
    }
}