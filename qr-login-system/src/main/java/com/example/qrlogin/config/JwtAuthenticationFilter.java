package com.example.qrlogin.config;

import com.example.qrlogin.util.JwtUtil;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Collection;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    
    private final JwtUtil jwtUtil;
    private static final String AUTHORIZATION_HEADER = "Authorization";
    private static final String BEARER_PREFIX = "Bearer ";
    
    @Override
    protected void doFilterInternal(HttpServletRequest request, 
                                  HttpServletResponse response, 
                                  FilterChain filterChain) throws ServletException, IOException {
        
        String authorizationHeader = request.getHeader(AUTHORIZATION_HEADER);
        
        if (authorizationHeader != null && authorizationHeader.startsWith(BEARER_PREFIX)) {
            String token = authorizationHeader.substring(BEARER_PREFIX.length());
            
            try {
                if (jwtUtil.validateAccessToken(token)) {
                    String userId = jwtUtil.extractUserId(token);
                    
                    // Extract roles from JWT claims
                    Collection<GrantedAuthority> authorities = extractAuthorities(token);
                    
                    // Create authentication object
                    UsernamePasswordAuthenticationToken authentication = 
                        new UsernamePasswordAuthenticationToken(userId, null, authorities);
                    
                    authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    
                    // Set authentication in security context
                    SecurityContextHolder.getContext().setAuthentication(authentication);
                    
                    log.debug("Successfully authenticated user: {} with roles: {}", userId, authorities);
                }
            } catch (Exception e) {
                log.debug("JWT validation failed: {}", e.getMessage());
                SecurityContextHolder.clearContext();
            }
        }
        
        filterChain.doFilter(request, response);
    }
    
    @SuppressWarnings("unchecked")
    private Collection<GrantedAuthority> extractAuthorities(String token) {
        try {
            var claims = jwtUtil.extractAllClaims(token);
            Object rolesObj = claims.get("roles");
            
            if (rolesObj instanceof List) {
                List<String> roles = (List<String>) rolesObj;
                return roles.stream()
                    .map(role -> new SimpleGrantedAuthority("ROLE_" + role))
                    .collect(Collectors.toList());
            }
        } catch (Exception e) {
            log.debug("Failed to extract authorities from token: {}", e.getMessage());
        }
        
        return List.of(new SimpleGrantedAuthority("ROLE_USER"));
    }
}