package com.example.websocket.config;

import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttConnectOptions;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MqttConfig {

    @Value("${mqtt.broker.url:tcp://mosquitto:3123}")
    private String brokerUrl;

    @Value("${mqtt.client.id:spring-boot-mqtt-client}")
    private String clientId;

    @Value("${mqtt.username:mqttuser}")
    private String username;

    @Value("${mqtt.password:mqttpass}")
    private String password;

    @Bean
    public MqttClient mqttClient() throws MqttException {
        MemoryPersistence persistence = new MemoryPersistence();
        MqttClient client = new MqttClient(brokerUrl, clientId, persistence);

        MqttConnectOptions options = new MqttConnectOptions();
        options.setCleanSession(true);
        options.setConnectionTimeout(30);
        options.setKeepAliveInterval(60);
        options.setAutomaticReconnect(true);

        // Set MQTT authentication
        options.setUserName(username);
        options.setPassword(password.toCharArray());

        client.connect(options);
        return client;
    }
}