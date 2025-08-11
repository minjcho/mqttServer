package com.example.qrlogin.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureTestDatabase;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureWebMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@AutoConfigureWebMvc
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("local")
@Transactional
class AuthControllerTest {
    
    @Autowired
    private MockMvc mockMvc;
    
    @Autowired
    private ObjectMapper objectMapper;
    
    @Test
    void testSignupLoginAndGetUserInfo() throws Exception {
        // 1. Signup
        SignupRequest signupRequest = new SignupRequest("test@example.com", "password123");
        
        MvcResult signupResult = mockMvc.perform(post("/api/auth/signup")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(signupRequest)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.email").value("test@example.com"))
                .andReturn();
        
        // 2. Login
        LoginRequest loginRequest = new LoginRequest("test@example.com", "password123");
        
        MvcResult loginResult = mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").exists())
                .andExpect(jsonPath("$.refreshToken").exists())
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andReturn();
        
        // Extract access token
        String responseBody = loginResult.getResponse().getContentAsString();
        var tokenResponse = objectMapper.readValue(responseBody, com.example.qrlogin.dto.TokenResponse.class);
        String accessToken = tokenResponse.getAccessToken();
        
        // 3. Get user info with token
        mockMvc.perform(get("/api/users/me")
                .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value("test@example.com"))
                .andExpect(jsonPath("$.roles").exists());
    }
    
    @Test
    void testSignupWithDuplicateEmail() throws Exception {
        // Signup first time
        SignupRequest signupRequest = new SignupRequest("duplicate@example.com", "password123");
        
        mockMvc.perform(post("/api/auth/signup")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(signupRequest)))
                .andExpect(status().isCreated());
        
        // Try to signup with same email
        mockMvc.perform(post("/api/auth/signup")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(signupRequest)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("Email already exists"));
    }
    
    @Test
    void testLoginWithInvalidCredentials() throws Exception {
        LoginRequest loginRequest = new LoginRequest("nonexistent@example.com", "wrongpassword");
        
        mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isUnauthorized());
    }
}