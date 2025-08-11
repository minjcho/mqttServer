package com.example.qrlogin.service;

import com.example.qrlogin.dto.QrApproveRequest;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureWebMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureWebMvc
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("local")
@Transactional
class QrApproveSecurityTest {
    
    @Autowired
    private MockMvc mockMvc;
    
    @Autowired
    private ObjectMapper objectMapper;
    
    @Test
    void testQrApproveRequiresAuthentication() throws Exception {
        QrApproveRequest approveRequest = new QrApproveRequest("test-challenge-id");
        
        // Try to approve without authentication token
        mockMvc.perform(post("/api/qr/approve")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(approveRequest)))
                .andExpect(status().isUnauthorized());
    }
    
    @Test
    void testQrApproveWithInvalidToken() throws Exception {
        QrApproveRequest approveRequest = new QrApproveRequest("test-challenge-id");
        
        // Try to approve with invalid JWT token
        mockMvc.perform(post("/api/qr/approve")
                .header("Authorization", "Bearer invalid.jwt.token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(approveRequest)))
                .andExpect(status().isUnauthorized());
    }
}