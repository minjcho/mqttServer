package com.example.qrlogin.auth;

import com.example.qrlogin.dto.RefreshTokenRequest;
import com.example.qrlogin.dto.TokenResponse;
import com.example.qrlogin.service.TokenService;
import com.example.qrlogin.user.Role;
import com.example.qrlogin.user.User;
import com.example.qrlogin.user.UserRepository;
import com.example.qrlogin.util.JwtUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Set;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {
    
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final TokenService tokenService;
    private final JwtUtil jwtUtil;
    
    @Transactional
    public User signup(SignupRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new IllegalArgumentException("Email already exists");
        }
        
        String hashedPassword = passwordEncoder.encode(request.getPassword());
        
        // Check if orinId is provided and available
        if (request.getOrinId() != null && !request.getOrinId().isEmpty()) {
            if (!userRepository.existsByOrinId(request.getOrinId())) {
                // OrinId is available
            } else {
                throw new IllegalArgumentException("OrinId is already in use");
            }
        }
        
        User user = User.builder()
            .email(request.getEmail())
            .passwordHash(hashedPassword)
            .orinId(request.getOrinId())
            .roles(Set.of(Role.USER))
            .enabled(true)
            .build();
        
        User savedUser = userRepository.save(user);
        log.info("New user registered: {}", savedUser.getEmail());
        
        return savedUser;
    }
    
    @Transactional(readOnly = true)
    public TokenResponse login(LoginRequest request) {
        User user = userRepository.findByEmailAndEnabledTrue(request.getEmail())
            .orElseThrow(() -> new UsernameNotFoundException("User not found"));
        
        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new BadCredentialsException("Invalid credentials");
        }
        
        // Generate tokens with user info
        String accessToken = generateAccessTokenForUser(user);
        String refreshToken = jwtUtil.generateRefreshToken(user.getId().toString());
        
        // Save refresh token
        tokenService.saveRefreshToken(user.getId().toString(), refreshToken);
        
        log.info("User logged in: {}", user.getEmail());
        
        return TokenResponse.builder()
            .accessToken(accessToken)
            .refreshToken(refreshToken)
            .tokenType("Bearer")
            .accessTokenExpiresIn(jwtUtil.getAccessTokenExpirationTime() / 1000)
            .refreshTokenExpiresIn(jwtUtil.getRefreshTokenExpirationTime() / 1000)
            .orinId(user.getOrinId())
            .build();
    }
    
    @Transactional(readOnly = true)
    public TokenResponse refresh(RefreshTokenRequest request) {
        return tokenService.refreshTokens(request);
    }
    
    private String generateAccessTokenForUser(User user) {
        Set<String> roleNames = user.getRoles().stream()
            .map(Role::name)
            .collect(Collectors.toSet());
        
        return jwtUtil.generateAccessToken(
            user.getId().toString(),
            user.getEmail(),
            roleNames,
            user.getOrinId()
        );
    }
}