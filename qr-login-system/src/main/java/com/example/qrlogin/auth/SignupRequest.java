package com.example.qrlogin.auth;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Schema(description = "회원가입 요청")
public class SignupRequest {
    
    @NotBlank(message = "Email is required")
    @Email(message = "Invalid email format")
    @Schema(description = "사용자 이메일 주소", example = "user@example.com", required = true)
    private String email;
    
    @NotBlank(message = "Password is required")
    @Size(min = 8, message = "Password must be at least 8 characters long")
    @Schema(description = "사용자 비밀번호 (최소 8자)", example = "password123", required = true)
    private String password;
}