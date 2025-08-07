package com.example.websocket.service;

import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.eclipse.paho.client.mqttv3.MqttMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class MqttService {
    
    private static final Logger logger = LoggerFactory.getLogger(MqttService.class);
    
    @Autowired
    private MqttClient mqttClient;
    
    public void sendFollowingCommand(String orinId) {
        String topic = String.format("commands/%s", orinId);
        String message = "following";
        
        try {
            if (!mqttClient.isConnected()) {
                mqttClient.reconnect();
            }
            
            MqttMessage mqttMessage = new MqttMessage(message.getBytes());
            mqttMessage.setQos(1);
            mqttMessage.setRetained(false);
            
            mqttClient.publish(topic, mqttMessage);
            logger.info("Successfully sent following command to topic: {}", topic);
            
        } catch (MqttException e) {
            logger.error("Failed to send MQTT message to topic: {}", topic, e);
            throw new RuntimeException("Failed to send MQTT command", e);
        }
    }
}