package com.example.qrlogin.controller;

import com.example.qrlogin.dto.OrinIdUpdateRequest;
import com.example.qrlogin.dto.OrinIdResponse;
import com.example.qrlogin.user.User;
import com.example.qrlogin.user.UserService;
import com.example.qrlogin.util.JwtUtil;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/orin")
@RequiredArgsConstructor
@Tag(name = "OrinId Management", description = "OrinId 관리 API")
@SecurityRequirement(name = "bearerAuth")
public class OrinIdController {
    
    private final UserService userService;
    private final JwtUtil jwtUtil;
    
    @GetMapping("/my")
    @Operation(summary = "내 OrinId 조회", description = "현재 로그인한 사용자의 OrinId를 조회합니다")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "조회 성공"),
        @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    public ResponseEntity<OrinIdResponse> getMyOrinId(Authentication authentication) {
        String userId = authentication.getName();
        User user = userService.getCurrentUser(userId);
        
        return ResponseEntity.ok(OrinIdResponse.builder()
            .userId(user.getId())
            .email(user.getEmail())
            .orinId(user.getOrinId())
            .build());
    }
    
    @PutMapping("/my")
    @Operation(summary = "내 OrinId 변경", description = "현재 로그인한 사용자의 OrinId를 변경합니다")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "변경 성공"),
        @ApiResponse(responseCode = "400", description = "잘못된 요청 또는 이미 사용중인 OrinId"),
        @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    public ResponseEntity<OrinIdResponse> updateMyOrinId(
            Authentication authentication,
            @Valid @RequestBody OrinIdUpdateRequest request) {
        String userId = authentication.getName();
        User updatedUser = userService.updateOrinId(Long.valueOf(userId), request.getOrinId());
        
        return ResponseEntity.ok(OrinIdResponse.builder()
            .userId(updatedUser.getId())
            .email(updatedUser.getEmail())
            .orinId(updatedUser.getOrinId())
            .build());
    }
    
    @DeleteMapping("/my")
    @Operation(summary = "내 OrinId 삭제", description = "현재 로그인한 사용자의 OrinId를 삭제합니다")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "삭제 성공"),
        @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    public ResponseEntity<OrinIdResponse> deleteMyOrinId(Authentication authentication) {
        String userId = authentication.getName();
        User updatedUser = userService.updateOrinId(Long.valueOf(userId), null);
        
        return ResponseEntity.ok(OrinIdResponse.builder()
            .userId(updatedUser.getId())
            .email(updatedUser.getEmail())
            .orinId(updatedUser.getOrinId())
            .build());
    }
    
    @GetMapping("/check/{orinId}")
    @Operation(summary = "OrinId 사용 가능 여부 확인", description = "지정한 OrinId가 사용 가능한지 확인합니다")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "조회 성공"),
        @ApiResponse(responseCode = "401", description = "인증 실패")
    })
    public ResponseEntity<Map<String, Object>> checkOrinIdAvailability(
            @Parameter(description = "확인할 OrinId") @PathVariable String orinId) {
        boolean available = userService.isOrinIdAvailable(orinId);
        
        Map<String, Object> response = new HashMap<>();
        response.put("orinId", orinId);
        response.put("available", available);
        
        return ResponseEntity.ok(response);
    }
    
    @GetMapping("/user/{orinId}")
    @Operation(summary = "OrinId로 사용자 조회", description = "지정한 OrinId를 가진 사용자 정보를 조회합니다")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "조회 성공"),
        @ApiResponse(responseCode = "401", description = "인증 실패"),
        @ApiResponse(responseCode = "404", description = "사용자를 찾을 수 없음")
    })
    public ResponseEntity<OrinIdResponse> getUserByOrinId(
            @Parameter(description = "조회할 OrinId") @PathVariable String orinId) {
        User user = userService.getUserByOrinId(orinId);
        
        return ResponseEntity.ok(OrinIdResponse.builder()
            .userId(user.getId())
            .email(user.getEmail())
            .orinId(user.getOrinId())
            .build());
    }
}