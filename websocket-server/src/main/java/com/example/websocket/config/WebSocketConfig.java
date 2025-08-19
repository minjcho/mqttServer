package com.example.websocket.config;

import com.example.websocket.handler.CoordinateWebSocketHandler;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {

    private final CoordinateWebSocketHandler coordinateWebSocketHandler;

    public WebSocketConfig(CoordinateWebSocketHandler coordinateWebSocketHandler) {
        this.coordinateWebSocketHandler = coordinateWebSocketHandler;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(coordinateWebSocketHandler, "/ws/coordinates")
                .setAllowedOriginPatterns("*");
        registry.addHandler(coordinateWebSocketHandler, "/coordinates")
                .setAllowedOriginPatterns("*")
                .withSockJS();
    }
}