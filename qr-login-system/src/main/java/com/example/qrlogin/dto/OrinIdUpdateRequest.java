package com.example.qrlogin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "OrinId 변경 요청")
public class OrinIdUpdateRequest {
    
    @Size(max = 50, message = "OrinId must not exceed 50 characters")
    @Pattern(regexp = "^[a-zA-Z0-9-_]*$", message = "OrinId can only contain alphanumeric characters, hyphens, and underscores")
    @Schema(description = "새로운 Orin 디바이스 ID", example = "orin-device-001")
    private String orinId;
}