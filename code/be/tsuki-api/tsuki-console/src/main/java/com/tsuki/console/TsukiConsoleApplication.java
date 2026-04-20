package com.tsuki.console;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages = "com.tsuki")
public class TsukiConsoleApplication {
    public static void main(String[] args) {
        SpringApplication.run(TsukiConsoleApplication.class, args);
    }
}
