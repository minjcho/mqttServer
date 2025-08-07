package com.example.websocket.controller;

import com.example.websocket.service.MqttService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/mqtt")
@CrossOrigin(origins = "*")
@Tag(name = "MQTT Controller", description = "APIs for sending MQTT commands to IoT devices")
public class MqttController {
    
    @Autowired
    private MqttService mqttService;
    
    @Operation(
        summary = "Send following command to IoT device",
        description = "Sends a 'following' command to the specified IoT device via MQTT"
    )
    @ApiResponses(value = {
        @ApiResponse(
            responseCode = "200",
            description = "Command sent successfully",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = Map.class)
            )
        ),
        @ApiResponse(
            responseCode = "500",
            description = "Failed to send command",
            content = @Content(
                mediaType = "application/json",
                schema = @Schema(implementation = Map.class)
            )
        )
    })
    @PostMapping("/commands/{orinId}/following")
    public ResponseEntity<Map<String, Object>> sendFollowingCommand(
            @Parameter(description = "The origin ID of the IoT device", required = true, example = "device123")
            @PathVariable String orinId) {
        Map<String, Object> response = new HashMap<>();
        
        try {
            mqttService.sendFollowingCommand(orinId);
            response.put("success", true);
            response.put("message", "Following command sent successfully");
            response.put("orinId", orinId);
            response.put("command", "following");
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            response.put("success", false);
            response.put("message", "Failed to send following command: " + e.getMessage());
            response.put("orinId", orinId);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }
}