package com.tsuki.integration.health;

import org.springframework.stereotype.Component;

@Component
public class ExternalHealthClient {

    public String dependencyStatus() {
        return "READY";
    }
}
