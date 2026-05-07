package com.tsuki.console.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/console")
public class ConsoleController {

    @GetMapping("/ping")
    public Map<String, String> ping() {
        return Map.of("message", "console-ok");
    }
}
