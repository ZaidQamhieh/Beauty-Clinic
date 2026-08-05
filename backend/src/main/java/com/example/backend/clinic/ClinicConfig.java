package com.example.backend.clinic;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(ClinicProperties.class)
class ClinicConfig {
}
