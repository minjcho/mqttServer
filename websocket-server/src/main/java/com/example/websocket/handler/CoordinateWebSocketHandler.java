package com.example.websocket.handler;

import com.example.websocket.service.CoordinateService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.util.concurrent.CopyOnWriteArraySet;

@Component
public class CoordinateWebSocketHandler extends TextWebSocketHandler {

    private static final Logger logger = LoggerFactory.getLogger(CoordinateWebSocketHandler.class);
    
    // Thread-safe set to store active WebSocket sessions
    private final CopyOnWriteArraySet<WebSocketSession> sessions = new CopyOnWriteArraySet<>();
    
    private final CoordinateService coordinateService;

    public CoordinateWebSocketHandler(CoordinateService coordinateService) {
        this.coordinateService = coordinateService;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        sessions.add(session);
        logger.info("WebSocket connection established: {}", session.getId());
        logger.info("Total active sessions: {}", sessions.size());
        
        // 연결 시 환영 메시지 전송
        session.sendMessage(new TextMessage("{\"type\":\"connected\",\"message\":\"Connected to coordinate stream\"}"));
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) throws Exception {
        sessions.remove(session);
        logger.info("WebSocket connection closed: {} with status: {}", session.getId(), status);
        logger.info("Total active sessions: {}", sessions.size());
    }

    @Override
    public void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        logger.debug("Received message from {}: {}", session.getId(), message.getPayload());
        
        // 클라이언트로부터 메시지를 받았을 때의 처리
        // 현재는 단순히 로깅만 하지만, 필요에 따라 명령 처리 로직 추가 가능
        String payload = message.getPayload();
        
        if ("ping".equals(payload)) {
            session.sendMessage(new TextMessage("{\"type\":\"pong\",\"timestamp\":" + System.currentTimeMillis() + "}"));
        }
    }

    @Override
    public void handleTransportError(WebSocketSession session, Throwable exception) throws Exception {
        logger.error("Transport error for session {}: {}", session.getId(), exception.getMessage());
        sessions.remove(session);
    }

    /**
     * 모든 활성 세션에 좌표 데이터를 브로드캐스트
     */
    public void broadcastCoordinates(String coordinateData) {
        if (sessions.isEmpty()) {
            return;
        }

        logger.debug("Broadcasting to {} sessions: {}", sessions.size(), coordinateData);
        
        // 비활성 세션 제거를 위한 리스트
        sessions.removeIf(session -> {
            try {
                if (session.isOpen()) {
                    session.sendMessage(new TextMessage(coordinateData));
                    return false; // 세션 유지
                } else {
                    logger.warn("Removing closed session: {}", session.getId());
                    return true; // 세션 제거
                }
            } catch (Exception e) {
                logger.error("Error sending message to session {}: {}", session.getId(), e.getMessage());
                return true; // 오류 발생 시 세션 제거
            }
        });
    }

    /**
     * 현재 활성 세션 수 반환
     */
    public int getActiveSessionCount() {
        return sessions.size();
    }
}