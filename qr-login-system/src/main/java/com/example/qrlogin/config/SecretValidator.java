package com.example.qrlogin.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.ApplicationListener;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.List;

/**
 * Validates critical secrets on application startup.
 * Ensures that weak or default values are not used in production.
 */
@Component
public class SecretValidator implements ApplicationListener<ApplicationReadyEvent> {

    private static final Logger logger = LoggerFactory.getLogger(SecretValidator.class);

    @Value("${jwt.secret:}")
    private String jwtSecret;

    @Value("${spring.datasource.password:}")
    private String databasePassword;

    // Insecure patterns that should not appear in secrets
    private static final List<String> INSECURE_PATTERNS = Arrays.asList(
            "CHANGE", "change",
            "SECRET", "secret",
            "PLEASE", "please",
            "PASSWORD", "password",
            "EXAMPLE", "example",
            "TEST", "test",
            "TEMP", "temp",
            "DEFAULT", "default",
            "123456", "qwerty",
            "admin", "ADMIN"
    );

    @Override
    public void onApplicationEvent(ApplicationReadyEvent event) {
        logger.info("🔐 Validating critical secrets...");

        try {
            validateJwtSecret();
            validateDatabasePassword();
            logger.info("✅ All secrets validated successfully");
        } catch (IllegalStateException e) {
            logger.error("❌ Secret validation failed: {}", e.getMessage());
            logger.error("❌ Application will shut down");
            System.exit(1);
        }
    }

    private void validateJwtSecret() {
        if (jwtSecret == null || jwtSecret.trim().isEmpty()) {
            throw new IllegalStateException(
                    "JWT_SECRET is not set! " +
                            "Please set jwt.secret in application.properties or JWT_SECRET environment variable. " +
                            "Generate a secure secret: openssl rand -base64 64"
            );
        }

        // Check minimum length (64 characters for 512-bit key)
        if (jwtSecret.length() < 64) {
            throw new IllegalStateException(
                    String.format(
                            "JWT_SECRET is too short (%d characters). Minimum 64 characters required. " +
                                    "Generate a secure secret: openssl rand -base64 64",
                            jwtSecret.length()
                    )
            );
        }

        // Check for insecure patterns
        for (String pattern : INSECURE_PATTERNS) {
            if (jwtSecret.contains(pattern)) {
                throw new IllegalStateException(
                        String.format(
                                "JWT_SECRET contains insecure pattern '%s'. " +
                                        "This appears to be a default or placeholder value. " +
                                        "Generate a secure secret: openssl rand -base64 64",
                                pattern
                        )
                );
            }
        }

        logger.info("✅ JWT secret validated (length: {} characters)", jwtSecret.length());
    }

    private void validateDatabasePassword() {
        if (databasePassword == null || databasePassword.trim().isEmpty()) {
            logger.warn("⚠️  DATABASE_PASSWORD is not set or empty");
            return; // May be using external database without password
        }

        // Check minimum length
        if (databasePassword.length() < 12) {
            throw new IllegalStateException(
                    String.format(
                            "DATABASE_PASSWORD is too short (%d characters). Minimum 12 characters required. " +
                                    "Generate a secure password: openssl rand -base64 24",
                            databasePassword.length()
                    )
            );
        }

        // Common weak passwords
        List<String> weakPasswords = Arrays.asList(
                "postgres", "password", "admin", "root", "123456",
                "qrlogin123", "postgres123", "admin123"
        );

        if (weakPasswords.contains(databasePassword.toLowerCase())) {
            throw new IllegalStateException(
                    String.format(
                            "DATABASE_PASSWORD is a common weak password: '%s'. " +
                                    "Use a strong password. " +
                                    "Generate: openssl rand -base64 24",
                            databasePassword
                    )
            );
        }

        logger.info("✅ Database password validated (length: {} characters)", databasePassword.length());
    }
}
