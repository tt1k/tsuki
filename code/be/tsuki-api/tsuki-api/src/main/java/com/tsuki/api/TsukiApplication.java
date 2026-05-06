package com.tsuki.api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages = "com.tsuki")
public class TsukiApplication {
    public static void main(String[] args) {
        SpringApplication.run(TsukiApplication.class, args);
    }
}
