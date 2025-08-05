FROM eclipse-mosquitto:2.0

COPY mosquitto.conf /mosquitto/config/
COPY passwd /mosquitto/config/


EXPOSE 3123
CMD ["mosquitto", "-c", "/mosquitto/config/mosquitto.conf"]