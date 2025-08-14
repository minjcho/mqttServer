package com.example.qrlogin.user;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
public class UserService {
    
    private final UserRepository userRepository;
    
    @Transactional(readOnly = true)
    public User getCurrentUser(String userId) {
        Long id = Long.valueOf(userId);
        return userRepository.findByIdAndEnabledTrue(id)
            .orElseThrow(() -> new UsernameNotFoundException("User not found"));
    }
    
    @Transactional(readOnly = true)
    public User getUserById(Long id) {
        return userRepository.findByIdAndEnabledTrue(id)
            .orElseThrow(() -> new UsernameNotFoundException("User not found"));
    }
    
    @Transactional(readOnly = true)
    public User getUserByEmail(String email) {
        return userRepository.findByEmailAndEnabledTrue(email)
            .orElseThrow(() -> new UsernameNotFoundException("User not found"));
    }
    
    @Transactional
    public User updateOrinId(Long userId, String orinId) {
        User user = getUserById(userId);
        
        // Allow duplicate orinId - no check needed
        user.setOrinId(orinId);
        return userRepository.save(user);
    }
    
    @Transactional(readOnly = true)
    public User getUserByOrinId(String orinId) {
        return userRepository.findByOrinIdAndEnabledTrue(orinId)
            .orElseThrow(() -> new UsernameNotFoundException("User not found with orinId: " + orinId));
    }
    
    @Transactional(readOnly = true)
    public boolean isOrinIdAvailable(String orinId) {
        // Always return true since we allow duplicate orinIds
        return true;
    }
}