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
        summary = "Send tracking command to IoT device",
        description = "Sends a 'tracking' command to the specified IoT device via MQTT"
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
    @PostMapping("/commands/{orinId}/tracking")
    public ResponseEntity<Map<String, Object>> sendTrackingCommand(
            @Parameter(description = "The origin ID of the IoT device", required = true, example = "device123")
            @PathVariable String orinId) {
        Map<String, Object> response = new HashMap<>();
        
        try {
            mqttService.sendTrackingCommand(orinId);
            response.put("success", true);
            response.put("message", "Tracking command sent successfully");
            response.put("orinId", orinId);
            response.put("command", "tracking");
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            response.put("success", false);
            response.put("message", "Failed to send tracking command: " + e.getMessage());
            response.put("orinId", orinId);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }
    
    @Operation(
        summary = "Send slam command to IoT device",
        description = "Sends a 'slam' command to the specified IoT device via MQTT"
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
    @PostMapping("/commands/{orinId}/slam")
    public ResponseEntity<Map<String, Object>> sendSlamCommand(
            @Parameter(description = "The origin ID of the IoT device", required = true, example = "device123")
            @PathVariable String orinId) {
        Map<String, Object> response = new HashMap<>();
        
        try {
            mqttService.sendSlamCommand(orinId);
            response.put("success", true);
            response.put("message", "Slam command sent successfully");
            response.put("orinId", orinId);
            response.put("command", "slam");
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            response.put("success", false);
            response.put("message", "Failed to send slam command: " + e.getMessage());
            response.put("orinId", orinId);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }
    
    @Operation(
        summary = "Send none command to IoT device",
        description = "Sends a 'none' command to the specified IoT device via MQTT"
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
    @PostMapping("/commands/{orinId}/none")
    public ResponseEntity<Map<String, Object>> sendNoneCommand(
            @Parameter(description = "The origin ID of the IoT device", required = true, example = "device123")
            @PathVariable String orinId) {
        Map<String, Object> response = new HashMap<>();
        
        try {
            mqttService.sendNoneCommand(orinId);
            response.put("success", true);
            response.put("message", "None command sent successfully");
            response.put("orinId", orinId);
            response.put("command", "none");
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            response.put("success", false);
            response.put("message", "Failed to send none command: " + e.getMessage());
            response.put("orinId", orinId);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }
    
    @Operation(
        summary = "Send any command to IoT device",
        description = "Sends a custom command to the specified IoT device via MQTT"
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
            responseCode = "400",
            description = "Invalid command",
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
    @PostMapping("/commands/{orinId}")
    public ResponseEntity<Map<String, Object>> sendCommand(
            @Parameter(description = "The origin ID of the IoT device", required = true, example = "device123")
            @PathVariable String orinId,
            @Parameter(description = "The command to send", required = true)
            @RequestBody Map<String, String> request) {
        Map<String, Object> response = new HashMap<>();
        
        String command = request.get("command");
        if (command == null || command.trim().isEmpty()) {
            response.put("success", false);
            response.put("message", "Command is required");
            response.put("orinId", orinId);
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
        }
        
        try {
            mqttService.sendCustomCommand(orinId, command);
            response.put("success", true);
            response.put("message", "Command sent successfully");
            response.put("orinId", orinId);
            response.put("command", command);
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            response.put("success", false);
            response.put("message", "Failed to send command: " + e.getMessage());
            response.put("orinId", orinId);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }
}