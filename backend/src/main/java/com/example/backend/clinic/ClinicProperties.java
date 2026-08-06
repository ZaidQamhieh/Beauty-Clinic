package com.example.backend.clinic;

import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.time.ZoneId;

// Working hours are wall clock, so resolve against the clinic's zone, not UTC.
@ConfigurationProperties(prefix = "app.clinic")
@Validated
public record ClinicProperties(@NotBlank String timezone) {

    public ClinicProperties {
        // Fail at startup on an unknown zone, not on the first booking.
        if (timezone != null && !timezone.isBlank()) {
            ZoneId.of(timezone);
        }
    }

    public ZoneId zone() {
        return ZoneId.of(timezone);
    }
}
