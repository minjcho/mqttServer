package com.example.websocket.controller;

import com.example.websocket.service.CoordinateService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;

import java.util.Map;

@Controller
public class WebController {

    private final CoordinateService coordinateService;

    public WebController(CoordinateService coordinateService) {
        this.coordinateService = coordinateService;
    }

    // /**
    //  * 테스트 페이지 제공
    //  */
    // @GetMapping("/")
    // public String index() {
    //     return "redirect:/index.html";
    // }

    /**
     * 서버 상태 API
     */
    @GetMapping("/api/status")
    @ResponseBody
    public Map<String, Object> getStatus() {
        return coordinateService.getRedisStats();
    }

    /**
     * 현재 좌표 API
     */
    @GetMapping("/api/coordinates")
    @ResponseBody
    public Object getCurrentCoordinates() {
        return coordinateService.getLatestCoordinates();
    }
}