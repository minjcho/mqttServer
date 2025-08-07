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
import java.util.concurrent.ConcurrentHashMap;
import java.net.URI;

@Component
public class CoordinateWebSocketHandler extends TextWebSocketHandler {

    private static final Logger logger = LoggerFactory.getLogger(CoordinateWebSocketHandler.class);
    
    // Thread-safe set to store active WebSocket sessions
    private final CopyOnWriteArraySet<WebSocketSession> sessions = new CopyOnWriteArraySet<>();
    
    // Thread-safe map to store session -> ORIN ID mapping
    private final ConcurrentHashMap<String, String> sessionOrinMap = new ConcurrentHashMap<>();
    
    private final CoordinateService coordinateService;

    public CoordinateWebSocketHandler(CoordinateService coordinateService) {
        this.coordinateService = coordinateService;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        sessions.add(session);
        
        // URL에서 ORIN ID 파라미터 추출
        String orinId = extractOrinIdFromSession(session);
        if (orinId != null) {
            sessionOrinMap.put(session.getId(), orinId);
            logger.info("WebSocket connection established: {} for ORIN ID: {}", session.getId(), orinId);
        } else {
            logger.info("WebSocket connection established: {} (no ORIN ID specified)", session.getId());
        }
        logger.info("Total active sessions: {}", sessions.size());
        
        // 연결 시 환영 메시지 전송
        String welcomeMessage = String.format(
            "{\"type\":\"connected\",\"message\":\"Connected to coordinate stream\",\"orinId\":\"%s\"}", 
            orinId != null ? orinId : "all"
        );
        session.sendMessage(new TextMessage(welcomeMessage));
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) throws Exception {
        sessions.remove(session);
        sessionOrinMap.remove(session.getId());
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
        sessionOrinMap.remove(session.getId());
    }

    /**
     * 특정 ORIN ID의 좌표 데이터를 해당 세션들에만 브로드캐스트
     */
    public void broadcastCoordinatesForOrin(String orinId, String coordinateData) {
        if (sessions.isEmpty()) {
            return;
        }

        logger.debug("Broadcasting to sessions subscribed to ORIN {}: {}", orinId, coordinateData);
        
        // 비활성 세션 제거를 위한 리스트
        sessions.removeIf(session -> {
            try {
                if (!session.isOpen()) {
                    logger.warn("Removing closed session: {}", session.getId());
                    sessionOrinMap.remove(session.getId());
                    return true; // 세션 제거
                }
                
                // 세션의 ORIN ID 확인
                String sessionOrinId = sessionOrinMap.get(session.getId());
                
                // ORIN ID가 매치하거나 전체 데이터를 구독하는 경우 전송
                if (sessionOrinId == null || sessionOrinId.equals(orinId)) {
                    session.sendMessage(new TextMessage(coordinateData));
                }
                
                return false; // 세션 유지
                
            } catch (Exception e) {
                logger.error("Error sending message to session {}: {}", session.getId(), e.getMessage());
                sessionOrinMap.remove(session.getId());
                return true; // 오류 발생 시 세션 제거
            }
        });
    }

    /**
     * 모든 활성 세션에 좌표 데이터를 브로드캐스트 (기존 호환성)
     */
    public void broadcastCoordinates(String coordinateData) {
        broadcastCoordinatesForOrin(null, coordinateData);
    }

    /**
     * WebSocket 세션의 URL에서 ORIN ID 파라미터 추출
     */
    private String extractOrinIdFromSession(WebSocketSession session) {
        try {
            URI uri = session.getUri();
            if (uri != null && uri.getQuery() != null) {
                String query = uri.getQuery();
                String[] params = query.split("&");
                
                for (String param : params) {
                    String[] keyValue = param.split("=");
                    if (keyValue.length == 2 && "orinId".equals(keyValue[0])) {
                        return keyValue[1];
                    }
                }
            }
        } catch (Exception e) {
            logger.warn("Failed to extract ORIN ID from session {}: {}", session.getId(), e.getMessage());
        }
        return null;
    }

    /**
     * 현재 활성 세션 수 반환
     */
    public int getActiveSessionCount() {
        return sessions.size();
    }
}