package com.example.qrlogin.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "JWT 토큰 응답")
public class TokenResponse {
    @Schema(description = "액세스 토큰", example = "eyJhbGciOiJIUzUxMiJ9...")
    private String accessToken;
    
    @Schema(description = "리프레시 토큰", example = "eyJhbGciOiJIUzUxMiJ9...")
    private String refreshToken;
    
    @Schema(description = "토큰 타입", example = "Bearer")
    private String tokenType;
    
    @Schema(description = "액세스 토큰 만료 시간 (초)", example = "900")
    private Long accessTokenExpiresIn;
    
    @Schema(description = "리프레시 토큰 만료 시간 (초)", example = "604800")
    private Long refreshTokenExpiresIn;
    
    @Schema(description = "사용자 OrinID", example = "ORIN123456")
    private String orinId;
}