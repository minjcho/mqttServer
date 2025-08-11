package com.example.qrlogin.auth;

import com.example.qrlogin.dto.RefreshTokenRequest;
import com.example.qrlogin.dto.TokenResponse;
import com.example.qrlogin.user.User;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@Tag(name = "인증", description = "사용자 인증 관련 API")
public class AuthController {
    
    private final AuthService authService;
    
    @Operation(summary = "사용자 회원가입", description = "새로운 사용자 계정을 생성합니다.")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "201", description = "회원가입 성공",
            content = @Content(mediaType = "application/json",
                examples = @ExampleObject(value = "{\"id\":1,\"email\":\"user@example.com\",\"message\":\"User created successfully\"}"))),
        @ApiResponse(responseCode = "400", description = "잘못된 요청 또는 이미 존재하는 이메일",
            content = @Content(mediaType = "application/json",
                examples = @ExampleObject(value = "{\"error\":\"Email already exists\"}")))
    })
    @PostMapping("/signup")
    public ResponseEntity<?> signup(
        @Parameter(description = "회원가입 요청 정보", required = true)
        @Valid @RequestBody SignupRequest request) {
        try {
            User user = authService.signup(request);
            
            return ResponseEntity.status(HttpStatus.CREATED)
                .body(Map.of(
                    "id", user.getId(),
                    "email", user.getEmail(),
                    "message", "User created successfully"
                ));
                
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            log.error("Signup failed for email: {}", request.getEmail(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("error", "Registration failed"));
        }
    }
    
    @Operation(summary = "사용자 로그인", description = "이메일과 패스워드로 로그인하여 JWT 토큰을 받습니다.")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "로그인 성공",
            content = @Content(mediaType = "application/json", schema = @Schema(implementation = TokenResponse.class))),
        @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    @PostMapping("/login")
    public ResponseEntity<TokenResponse> login(
        @Parameter(description = "로그인 요청 정보", required = true)
        @Valid @RequestBody LoginRequest request) {
        try {
            TokenResponse tokenResponse = authService.login(request);
            return ResponseEntity.ok(tokenResponse);
            
        } catch (Exception e) {
            log.warn("Login failed for email: {}", request.getEmail());
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(TokenResponse.builder()
                    .accessToken(null)
                    .refreshToken(null)
                    .tokenType("Bearer")
                    .accessTokenExpiresIn(0L)
                    .refreshTokenExpiresIn(0L)
                    .build());
        }
    }
    
    @PostMapping("/refresh")
    public ResponseEntity<TokenResponse> refresh(@Valid @RequestBody RefreshTokenRequest request) {
        try {
            TokenResponse tokenResponse = authService.refresh(request);
            return ResponseEntity.ok(tokenResponse);
            
        } catch (Exception e) {
            log.warn("Token refresh failed");
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                .body(TokenResponse.builder()
                    .accessToken(null)
                    .refreshToken(null)
                    .tokenType("Bearer")
                    .accessTokenExpiresIn(0L)
                    .refreshTokenExpiresIn(0L)
                    .build());
        }
    }
}