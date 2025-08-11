package com.example.qrlogin.exception;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {
    
    @ExceptionHandler(InvalidChallengeException.class)
    public ResponseEntity<Map<String, String>> handleInvalidChallengeException(InvalidChallengeException e) {
        log.warn("Invalid challenge: {}", e.getMessage());
        Map<String, String> error = new HashMap<>();
        error.put("error", "Invalid Challenge");
        error.put("message", e.getMessage());
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }
    
    @ExceptionHandler(InvalidOtcException.class)
    public ResponseEntity<Map<String, String>> handleInvalidOtcException(InvalidOtcException e) {
        log.warn("Invalid OTC: {}", e.getMessage());
        Map<String, String> error = new HashMap<>();
        error.put("error", "Invalid OTC");
        error.put("message", e.getMessage());
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }
    
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidationExceptions(MethodArgumentNotValidException ex) {
        Map<String, Object> errors = new HashMap<>();
        Map<String, String> fieldErrors = new HashMap<>();
        
        ex.getBindingResult().getAllErrors().forEach((error) -> {
            String fieldName = ((FieldError) error).getField();
            String errorMessage = error.getDefaultMessage();
            fieldErrors.put(fieldName, errorMessage);
        });
        
        errors.put("error", "Validation Failed");
        errors.put("fields", fieldErrors);
        
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errors);
    }
    
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> handleGenericException(Exception e) {
        log.error("Unexpected error occurred", e);
        Map<String, String> error = new HashMap<>();
        error.put("error", "Internal Server Error");
        error.put("message", "An unexpected error occurred");
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
    }
}