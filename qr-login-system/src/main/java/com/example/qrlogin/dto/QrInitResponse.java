package com.example.qrlogin.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class QrInitResponse {
    private String challengeId;
    private String nonce;
    private byte[] qrImage;
}