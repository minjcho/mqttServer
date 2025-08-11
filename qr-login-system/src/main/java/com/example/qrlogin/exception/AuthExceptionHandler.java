package com.example.qrlogin.exception;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.Map;

@Slf4j
@RestControllerAdvice
public class AuthExceptionHandler {
    
    @ExceptionHandler(UsernameNotFoundException.class)
    public ResponseEntity<Map<String, String>> handleUsernameNotFoundException(UsernameNotFoundException e) {
        log.warn("User not found: {}", e.getMessage());
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
            .body(Map.of(
                "error", "Authentication Failed",
                "message", "Invalid credentials"
            ));
    }
    
    @ExceptionHandler(BadCredentialsException.class)
    public ResponseEntity<Map<String, String>> handleBadCredentialsException(BadCredentialsException e) {
        log.warn("Bad credentials: {}", e.getMessage());
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
            .body(Map.of(
                "error", "Authentication Failed",
                "message", "Invalid credentials"
            ));
    }
    
    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, String>> handleIllegalArgumentException(IllegalArgumentException e) {
        log.warn("Illegal argument: {}", e.getMessage());
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
            .body(Map.of(
                "error", "Invalid Request",
                "message", e.getMessage()
            ));
    }
}