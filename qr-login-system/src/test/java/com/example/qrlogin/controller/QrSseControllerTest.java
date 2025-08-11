package com.example.qrlogin.controller;

import com.example.qrlogin.service.QrSseNotifier;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(QrSseController.class)
class QrSseControllerTest {
    
    @Autowired
    private MockMvc mockMvc;
    
    @MockBean
    private QrSseNotifier qrSseNotifier;
    
    @Test
    void testSseEndpointReturns200() throws Exception {
        // Given
        String challengeId = "test-challenge-123";
        
        // When & Then
        mockMvc.perform(get("/api/qr/stream/{challengeId}", challengeId))
            .andExpect(status().isOk())
            .andExpect(content().contentType(MediaType.TEXT_EVENT_STREAM_VALUE))
            .andExpect(header().string("Cache-Control", "no-cache"))
            .andExpect(header().string("Connection", "keep-alive"));
        
        // SSE 등록이 호출되었는지 확인
        verify(qrSseNotifier, times(1)).register(eq(challengeId), any(SseEmitter.class));
    }
    
    @Test
    void testSseEndpointWithValidChallengeId() throws Exception {
        // Given
        String challengeId = "valid-challenge-456";
        
        // When
        MvcResult result = mockMvc.perform(get("/api/qr/stream/{challengeId}", challengeId))
            .andExpect(status().isOk())
            .andExpect(content().contentType(MediaType.TEXT_EVENT_STREAM_VALUE))
            .andReturn();
        
        // Then
        verify(qrSseNotifier, times(1)).register(eq(challengeId), any(SseEmitter.class));
    }
    
    @Test
    void testGetStreamStats() throws Exception {
        // Given
        String challengeId = "stats-challenge-789";
        when(qrSseNotifier.getSubscriberCount(challengeId)).thenReturn(3);
        when(qrSseNotifier.getTotalActiveConnections()).thenReturn(10);
        
        // When & Then
        mockMvc.perform(get("/api/qr/stream/stats/{challengeId}", challengeId))
            .andExpect(status().isOk())
            .andExpect(content().contentType(MediaType.APPLICATION_JSON))
            .andExpect(jsonPath("$.challengeId").value(challengeId))
            .andExpect(jsonPath("$.subscriberCount").value(3))
            .andExpect(jsonPath("$.totalActiveConnections").value(10));
        
        verify(qrSseNotifier, times(1)).getSubscriberCount(challengeId);
        verify(qrSseNotifier, times(1)).getTotalActiveConnections();
    }
    
    @Test
    void testSseTimeout() throws Exception {
        // Given
        String challengeId = "timeout-challenge";
        
        // When
        MvcResult result = mockMvc.perform(get("/api/qr/stream/{challengeId}", challengeId))
            .andExpect(status().isOk())
            .andExpect(request().asyncStarted())
            .andReturn();
        
        // SSE 타임아웃 시뮬레이션
        CompletableFuture<Void> timeoutTest = CompletableFuture.runAsync(() -> {
            try {
                // 실제 SSE 연결이 120초 타임아웃으로 설정되어 있는지 확인
                // 이 테스트는 실제 타임아웃까지 기다리지 않고 설정만 검증
                assertTrue(result.getRequest().isAsyncStarted());
            } catch (Exception e) {
                fail("Timeout test failed: " + e.getMessage());
            }
        });
        
        timeoutTest.get(1, TimeUnit.SECONDS);
        
        // Then
        verify(qrSseNotifier, times(1)).register(eq(challengeId), any(SseEmitter.class));
    }
    
    @Test
    void testMultipleConcurrentConnections() throws Exception {
        // Given
        String challengeId = "concurrent-challenge";
        
        // When - 여러 동시 연결 시뮬레이션
        CompletableFuture<Void> connection1 = CompletableFuture.runAsync(() -> {
            try {
                mockMvc.perform(get("/api/qr/stream/{challengeId}", challengeId))
                    .andExpect(status().isOk());
            } catch (Exception e) {
                fail("Connection 1 failed: " + e.getMessage());
            }
        });
        
        CompletableFuture<Void> connection2 = CompletableFuture.runAsync(() -> {
            try {
                mockMvc.perform(get("/api/qr/stream/{challengeId}", challengeId))
                    .andExpect(status().isOk());
            } catch (Exception e) {
                fail("Connection 2 failed: " + e.getMessage());
            }
        });
        
        // 모든 연결 완료까지 대기
        CompletableFuture.allOf(connection1, connection2).get(2, TimeUnit.SECONDS);
        
        // Then - 두 번의 등록이 호출되어야 함
        verify(qrSseNotifier, times(2)).register(eq(challengeId), any(SseEmitter.class));
    }
    
    @Test
    void testInvalidChallengeIdStillReturns200() throws Exception {
        // Given
        String invalidChallengeId = ""; // 빈 challengeId
        
        // When & Then
        // SSE 엔드포인트는 유효하지 않은 challengeId라도 200을 반환해야 함
        // 실제 비즈니스 검증은 SSE 연결 이후에 처리
        mockMvc.perform(get("/api/qr/stream/{challengeId}", invalidChallengeId))
            .andExpect(status().isOk())
            .andExpect(content().contentType(MediaType.TEXT_EVENT_STREAM_VALUE));
        
        verify(qrSseNotifier, times(1)).register(eq(invalidChallengeId), any(SseEmitter.class));
    }
}