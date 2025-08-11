package com.example.qrlogin.user;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
    
    Optional<User> findByEmail(String email);
    
    boolean existsByEmail(String email);
    
    @Query("SELECT u FROM User u JOIN FETCH u.roles WHERE u.email = :email AND u.enabled = true")
    Optional<User> findByEmailAndEnabledTrue(@Param("email") String email);
    
    @Query("SELECT u FROM User u JOIN FETCH u.roles WHERE u.id = :id AND u.enabled = true")
    Optional<User> findByIdAndEnabledTrue(@Param("id") Long id);
}