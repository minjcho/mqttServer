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
public class RefreshToken implements Serializable {
    
    private String tokenId;
    private String userId;
    private String refreshToken;
    private LocalDateTime createdAt;
    private LocalDateTime expiresAt;
    private Boolean used;
    private String replacedByToken;
}