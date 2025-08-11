package com.example.qrlogin.exception;

public class InvalidChallengeException extends RuntimeException {
    
    public InvalidChallengeException(String message) {
        super(message);
    }
    
    public InvalidChallengeException(String message, Throwable cause) {
        super(message, cause);
    }
}