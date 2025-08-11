package com.example.qrlogin.dto;

import com.example.qrlogin.entity.QrChallenge;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class QrStatusResponse {
    private String challengeId;
    private QrChallenge.QrStatus status;
    private String otc;
}