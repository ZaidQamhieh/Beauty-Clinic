package com.example.backend.security;

import jakarta.validation.constraints.Positive;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.time.Duration;

// How hard one address may hit the endpoints that carry no token.
@ConfigurationProperties(prefix = "app.auth.rate-limit")
@Validated
public record RateLimitProperties(
        @Positive Integer maxRequests,
        @Positive Integer windowSeconds
) {

    public static final int DEFAULT_MAX_REQUESTS = 20;
    public static final int DEFAULT_WINDOW_SECONDS = 60;

    public RateLimitProperties {
        if (maxRequests == null) {
            maxRequests = DEFAULT_MAX_REQUESTS;
        }
        if (windowSeconds == null) {
            windowSeconds = DEFAULT_WINDOW_SECONDS;
        }
    }

    public Duration window() {
        return Duration.ofSeconds(windowSeconds);
    }
}
