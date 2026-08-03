package com.example.backend.security;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

@ConfigurationProperties(prefix = "app.auth.tokens")
public record TokenProperties(
    @NotBlank String issuer,
    @NotNull Duration accessTtl,
    @NotNull Duration refreshTtl,
    @NotBlank String secret
) {

}
