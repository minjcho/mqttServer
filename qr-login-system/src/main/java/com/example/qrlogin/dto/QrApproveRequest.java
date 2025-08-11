package com.example.qrlogin.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class QrApproveRequest {
    
    @NotBlank(message = "Challenge ID is required")
    private String challengeId;
    
    @NotBlank(message = "Nonce is required")
    private String nonce;
}