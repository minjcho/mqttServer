package com.example.websocket.model;

import com.fasterxml.jackson.annotation.JsonProperty;

public class CoordinateData {
    
    @JsonProperty("coordX")
    private Double coordX;
    
    @JsonProperty("coordY")
    private Double coordY;
    
    @JsonProperty("timestamp")
    private String timestamp;
    
    @JsonProperty("source")
    private String source;
    
    public CoordinateData() {}
    
    public CoordinateData(Double coordX, Double coordY, String timestamp, String source) {
        this.coordX = coordX;
        this.coordY = coordY;
        this.timestamp = timestamp;
        this.source = source;
    }
    public Double getCoordX() {
        return coordX;
    }
    
    public void setCoordX(Double coordX) {
        this.coordX = coordX;
    }
    
    public Double getCoordY() {
        return coordY;
    }
    
    public void setCoordY(Double coordY) {
        this.coordY = coordY;
    }
    
    public String getTimestamp() {
        return timestamp;
    }
    
    public void setTimestamp(String timestamp) {
        this.timestamp = timestamp;
    }
    
    public String getSource() {
        return source;
    }
    
    public void setSource(String source) {
        this.source = source;
    }
    
    @Override
    public String toString() {
        return "CoordinateData{" +
                "coordX=" + coordX +
                ", coordY=" + coordY +
                ", timestamp='" + timestamp + '\'' +
                ", source='" + source + '\'' +
                '}';
    }
}