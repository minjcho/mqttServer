package com.example.websocket.config;

import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttConnectOptions;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MqttConfig {

    private static final Logger logger = LoggerFactory.getLogger(MqttConfig.class);

    // Retry configuration
    private static final int MAX_RETRY_ATTEMPTS = 10;
    private static final long INITIAL_RETRY_DELAY_MS = 2000; // 2 seconds
    private static final double BACKOFF_MULTIPLIER = 2.0;
    private static final long MAX_RETRY_DELAY_MS = 30000; // 30 seconds

    @Value("${mqtt.broker.url:tcp://mosquitto:1883}")
    private String brokerUrl;

    @Value("${mqtt.client.id:spring-boot-mqtt-client}")
    private String clientId;

    @Value("${mqtt.username:#{null}}")
    private String username;

    @Value("${mqtt.password:#{null}}")
    private String password;

    @Bean
    public MqttClient mqttClient() throws MqttException {
        logger.info("🔌 Initializing MQTT client for broker: {}", brokerUrl);

        MemoryPersistence persistence = new MemoryPersistence();
        MqttClient client = new MqttClient(brokerUrl, clientId, persistence);

        // Don't connect immediately - let the connection manager handle it with retries
        logger.info("✅ MQTT client initialized (not yet connected)");
        return client;
    }

    @Bean
    public MqttConnectOptions mqttConnectOptions() {
        MqttConnectOptions options = new MqttConnectOptions();
        options.setCleanSession(true);
        options.setConnectionTimeout(30);
        options.setKeepAliveInterval(60);
        options.setAutomaticReconnect(true);

        // Add authentication if credentials are provided
        if (username != null && !username.trim().isEmpty()) {
            logger.info("🔐 MQTT authentication enabled for user: {}", username);
            options.setUserName(username);

            if (password != null && !password.trim().isEmpty()) {
                options.setPassword(password.toCharArray());
            } else {
                logger.warn("⚠️  MQTT password is empty");
            }
        } else {
            logger.warn("⚠️  MQTT authentication not configured - anonymous access");
        }

        return options;
    }

    /**
     * Connection manager that handles lazy connection with exponential backoff retry.
     * This allows the application to start even if Mosquitto is not ready yet.
     */
    @Bean
    public MqttConnectionManager mqttConnectionManager(
            MqttClient mqttClient,
            MqttConnectOptions mqttConnectOptions) {
        return new MqttConnectionManager(mqttClient, mqttConnectOptions);
    }

    /**
     * Manages MQTT connection lifecycle with retry logic.
     */
    public static class MqttConnectionManager {
        private static final Logger logger = LoggerFactory.getLogger(MqttConnectionManager.class);

        private final MqttClient mqttClient;
        private final MqttConnectOptions mqttConnectOptions;
        private volatile boolean connecting = true;
        private final Object connectionLock = new Object();

        public MqttConnectionManager(MqttClient mqttClient, MqttConnectOptions mqttConnectOptions) {
            this.mqttClient = mqttClient;
            this.mqttConnectOptions = mqttConnectOptions;

            // Start connection in background thread
            connectAsync();
        }

        /**
         * Attempts to connect to MQTT broker asynchronously with exponential backoff.
         */
        private void connectAsync() {
            new Thread(() -> {
                int attempts = 0;
                long delay = INITIAL_RETRY_DELAY_MS;

                logger.info("🔄 Starting MQTT connection attempts...");

                while (attempts < MAX_RETRY_ATTEMPTS) {
                    synchronized (connectionLock) {
                        try {
                            if (!mqttClient.isConnected()) {
                                attempts++;
                                logger.info("🔌 MQTT connection attempt {}/{}", attempts, MAX_RETRY_ATTEMPTS);

                                mqttClient.connect(mqttConnectOptions);
                                logger.info("✅ MQTT connected successfully to broker");
                                connecting = false;
                                return; // Success!
                            }
                        } catch (MqttException e) {
                            logger.warn("⚠️  MQTT connection attempt {} failed: {} - {}",
                                    attempts, e.getReasonCode(), e.getMessage());

                            if (attempts >= MAX_RETRY_ATTEMPTS) {
                                logger.error("❌ Failed to connect to MQTT broker after {} attempts", MAX_RETRY_ATTEMPTS);
                                logger.error("❌ MQTT functionality will not be available");
                                logger.error("❌ Please check that Mosquitto broker is running and credentials are correct");
                                connecting = false;
                                return;
                            }
                        }
                    }

                    // Exponential backoff (outside synchronized block)
                    try {
                        logger.info("⏳ Retrying in {}ms...", delay);
                        Thread.sleep(delay);
                        delay = Math.min((long) (delay * BACKOFF_MULTIPLIER), MAX_RETRY_DELAY_MS);
                    } catch (InterruptedException ie) {
                        Thread.currentThread().interrupt();
                        logger.error("❌ MQTT connection retry interrupted");
                        connecting = false;
                        return;
                    }
                }
            }, "mqtt-connection-thread").start();
        }

        /**
         * Checks if MQTT client is connected.
         * Thread-safe method to check connection status.
         */
        public synchronized boolean isConnected() {
            return mqttClient.isConnected();
        }

        /**
         * Checks if connection attempt is still in progress.
         */
        public boolean isConnecting() {
            return connecting;
        }

        /**
         * Gets the MQTT client (may not be connected).
         * Thread-safe method to get client instance.
         */
        public synchronized MqttClient getClient() {
            return mqttClient;
        }
    }
}