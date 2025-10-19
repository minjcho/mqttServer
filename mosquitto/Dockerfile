FROM eclipse-mosquitto:2.0

# Copy configuration files
COPY mosquitto.conf /mosquitto/config/

# Create empty password file
RUN touch /mosquitto/config/passwd && chmod 600 /mosquitto/config/passwd

EXPOSE 3123

# Use default mosquitto entrypoint
# Password file will be initialized via docker-compose command