# Multi-stage build for Spring Boot QR Login System
FROM eclipse-temurin:17-jdk AS builder

# Set working directory
WORKDIR /app

# Copy Gradle wrapper
COPY gradlew .
COPY gradle gradle

# Copy build files first (for caching)
COPY build.gradle .
COPY settings.gradle .

# Copy source code
COPY src src

# Make gradlew executable
RUN chmod +x gradlew

# Build application (skip tests for faster build)
RUN ./gradlew build -x test --no-daemon

# Runtime stage
FROM eclipse-temurin:17-jre

# Set working directory
WORKDIR /app

# Create non-root user for security
RUN groupadd -g 1001 spring && \
    useradd -u 1001 -g spring spring

# Set environment variables
ENV SPRING_PROFILES_ACTIVE=docker
ENV JAVA_OPTS="-Xmx512m -Xms256m"

# Copy JAR from builder stage
COPY --from=builder /app/build/libs/*.jar app.jar

# Change ownership to spring user
RUN chown -R spring:spring /app

# Switch to non-root user
USER spring

# Expose port
EXPOSE 8090

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8090/actuator/health || exit 1

# Entry point
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]