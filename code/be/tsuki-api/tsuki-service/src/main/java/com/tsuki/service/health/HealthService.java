package com.tsuki.service.health;

import com.tsuki.integration.health.ExternalHealthClient;
import com.tsuki.repository.health.HealthRepository;
import java.util.HashMap;
import java.util.Map;
import org.springframework.stereotype.Service;

@Service
public class HealthService {

    private final HealthRepository healthRepository;
    private final ExternalHealthClient externalHealthClient;

    public HealthService(HealthRepository healthRepository, ExternalHealthClient externalHealthClient) {
        this.healthRepository = healthRepository;
        this.externalHealthClient = externalHealthClient;
    }

    public Map<String, String> healthSnapshot() {
        Map<String, String> snapshot = new HashMap<>();
        snapshot.put("service", healthRepository.currentStatus());
        snapshot.put("integration", externalHealthClient.dependencyStatus());
        return snapshot;
    }
}
