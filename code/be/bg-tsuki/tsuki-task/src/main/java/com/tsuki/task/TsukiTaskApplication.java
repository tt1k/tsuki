package com.tsuki.task;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@EnableScheduling
@SpringBootApplication(scanBasePackages = "com.tsuki")
public class TsukiTaskApplication {
    public static void main(String[] args) {
        SpringApplication.run(TsukiTaskApplication.class, args);
    }
}
