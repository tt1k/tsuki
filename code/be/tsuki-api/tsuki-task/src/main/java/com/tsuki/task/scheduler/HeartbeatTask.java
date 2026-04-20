package com.tsuki.task.scheduler;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class HeartbeatTask {

    private static final Logger LOGGER = LoggerFactory.getLogger(HeartbeatTask.class);

    @Scheduled(fixedDelay = 60000)
    public void heartbeat() {
        LOGGER.info("tsuki-task heartbeat");
    }
}
