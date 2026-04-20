package com.tsuki.repository.health;

import org.springframework.stereotype.Repository;

@Repository
public class DefaultHealthRepository implements HealthRepository {

    @Override
    public String currentStatus() {
        return "UP";
    }
}
