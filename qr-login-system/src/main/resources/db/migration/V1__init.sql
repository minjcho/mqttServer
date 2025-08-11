-- V1__init.sql
-- Initial database schema for QR Login System

-- Users table
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create unique index on email
CREATE UNIQUE INDEX idx_users_email ON users(email);

-- User roles table (ElementCollection)
CREATE TABLE user_roles (
    user_id BIGINT NOT NULL,
    role VARCHAR(50) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create index on user_roles
CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);

-- Insert default admin user
-- Password is 'admin123' hashed with BCrypt
INSERT INTO users (email, password_hash, enabled, created_at, updated_at) 
VALUES ('admin@example.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2uheWG/igi.', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- Insert admin role for default user
INSERT INTO user_roles (user_id, role) 
VALUES (1, 'ADMIN');

-- Insert default regular user
-- Password is 'user123' hashed with BCrypt  
INSERT INTO users (email, password_hash, enabled, created_at, updated_at)
VALUES ('user@example.com', '$2a$10$NRy6oMkv3tRDzY8L8yp1.ORyWKnV8FZ1kG8Jl8Xx1tNy8M9k2FO1.', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- Insert user role for default user
INSERT INTO user_roles (user_id, role)
VALUES (2, 'USER');