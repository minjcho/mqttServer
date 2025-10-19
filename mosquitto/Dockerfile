FROM eclipse-mosquitto:2.0

# Copy configuration files
COPY mosquitto.conf /mosquitto/config/
COPY passwd /mosquitto/config/

# Create entrypoint script to initialize password file
RUN echo '#!/bin/sh' > /docker-entrypoint.sh && \
    echo 'if [ ! -s /mosquitto/config/passwd ]; then' >> /docker-entrypoint.sh && \
    echo '  echo "Initializing MQTT password file..."' >> /docker-entrypoint.sh && \
    echo '  mosquitto_passwd -b /mosquitto/config/passwd ${MQTT_USERNAME:-mqttuser} ${MQTT_PASSWORD:-mqttpass}' >> /docker-entrypoint.sh && \
    echo 'fi' >> /docker-entrypoint.sh && \
    echo 'exec mosquitto -c /mosquitto/config/mosquitto.conf' >> /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

EXPOSE 3123

ENTRYPOINT ["/docker-entrypoint.sh"]