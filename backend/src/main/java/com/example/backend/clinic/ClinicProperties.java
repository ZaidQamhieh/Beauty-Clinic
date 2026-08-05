package com.example.backend.clinic;

import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.time.ZoneId;

// The clinic's wall clock. Working hours are local times ("09:00-17:00") and a
// day's schedule is a local date, so both have to be resolved against the zone
// the clinic actually sits in rather than UTC.
@ConfigurationProperties(prefix = "app.clinic")
@Validated
public record ClinicProperties(@NotBlank String timezone) {

    public ClinicProperties {
        // Fail at startup on an unknown zone rather than on the first booking.
        // A missing value is left to @NotBlank, which reports it far better than
        // the NullPointerException ZoneId.of would raise here.
        if (timezone != null && !timezone.isBlank()) {
            ZoneId.of(timezone);
        }
    }

    public ZoneId zone() {
        return ZoneId.of(timezone);
    }
}
