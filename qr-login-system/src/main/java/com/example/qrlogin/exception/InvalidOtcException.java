package com.example.qrlogin.exception;

public class InvalidOtcException extends RuntimeException {
    
    public InvalidOtcException(String message) {
        super(message);
    }
    
    public InvalidOtcException(String message, Throwable cause) {
        super(message, cause);
    }
}