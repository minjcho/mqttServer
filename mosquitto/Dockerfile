FROM eclipse-mosquitto:2.0

# Copy configuration
COPY mosquitto.conf /mosquitto/config/

# Copy entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 1883

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["mosquitto", "-c", "/mosquitto/config/mosquitto.conf"]
