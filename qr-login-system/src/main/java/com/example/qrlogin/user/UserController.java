package com.example.qrlogin.user;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.stream.Collectors;

@Slf4j
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
@Tag(name = "사용자", description = "사용자 정보 관련 API")
public class UserController {
    
    private final UserService userService;
    
    @Operation(summary = "현재 사용자 정보 조회", description = "JWT 토큰으로 인증된 현재 사용자의 정보를 조회합니다.")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "사용자 정보 조회 성공",
            content = @Content(mediaType = "application/json",
                examples = @ExampleObject(value = "{\"id\":1,\"email\":\"user@example.com\",\"roles\":[\"USER\"],\"enabled\":true,\"createdAt\":\"2025-01-01T00:00:00\"}"))),
        @ApiResponse(responseCode = "401", description = "인증 필요")
    })
    @SecurityRequirement(name = "bearerAuth")
    @GetMapping("/me")
    public ResponseEntity<?> getCurrentUser() {
        try {
            Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
            String userId = authentication.getName();
            
            User user = userService.getCurrentUser(userId);
            
            return ResponseEntity.ok(Map.of(
                "id", user.getId(),
                "email", user.getEmail(),
                "roles", user.getRoles().stream()
                    .map(Role::name)
                    .collect(Collectors.toSet()),
                "enabled", user.getEnabled(),
                "createdAt", user.getCreatedAt()
            ));
            
        } catch (Exception e) {
            log.error("Failed to get current user info", e);
            return ResponseEntity.status(401)
                .body(Map.of("error", "Unauthorized"));
        }
    }
}