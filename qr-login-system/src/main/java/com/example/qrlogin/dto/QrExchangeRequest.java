package com.example.qrlogin.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class QrExchangeRequest {
    
    @NotBlank(message = "OTC is required")
    private String otc;
}