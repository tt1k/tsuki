package com.tsuki.api.controller;

import com.tsuki.common.constant.ApplicationConstants;
import com.tsuki.service.health.HealthService;
import java.util.HashMap;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/health")
public class HealthController {

    private final HealthService healthService;

    public HealthController(HealthService healthService) {
        this.healthService = healthService;
    }

    @GetMapping
    public Map<String, Object> health() {
        Map<String, Object> payload = new HashMap<>();
        payload.put("project", ApplicationConstants.PROJECT_NAME);
        payload.put("status", healthService.healthSnapshot());
        return payload;
    }
}
