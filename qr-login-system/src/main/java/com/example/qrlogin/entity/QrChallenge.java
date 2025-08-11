package com.example.qrlogin.entity;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class QrChallenge implements Serializable {
    
    private String challengeId;
    private String nonce;
    private QrStatus status;
    private String userId;
    private String otc;
    private LocalDateTime createdAt;
    private LocalDateTime approvedAt;
    private LocalDateTime exchangedAt;
    
    public enum QrStatus {
        PENDING,
        APPROVED,
        EXPIRED,
        EXCHANGED
    }
}