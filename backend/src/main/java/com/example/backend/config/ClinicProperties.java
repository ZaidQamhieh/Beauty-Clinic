package com.example.backend.config;

import com.example.backend.entities.AppointmentSession.TreatmentName;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

import java.math.BigDecimal;
import java.time.ZoneId;
import java.util.EnumSet;
import java.util.Map;

// Working hours are wall clock, so resolve against the clinic's zone, not UTC.
@ConfigurationProperties(prefix = "app.clinic")
@Validated
public record ClinicProperties(
        @NotBlank String timezone,
        @Valid Map<TreatmentName, Tariff> tariff,
        // Longest session anyone may book; past it, only a doctor or an admin may.
        Integer standardSessionMaxMinutes
) {

    public static final int DEFAULT_STANDARD_SESSION_MAX_MINUTES = 90;

    public ClinicProperties {
        // Fail at startup on an unknown zone, not on the first booking.
        if (timezone != null && !timezone.isBlank()) {
            ZoneId.of(timezone);
        }

        if (standardSessionMaxMinutes == null) {
            standardSessionMaxMinutes = DEFAULT_STANDARD_SESSION_MAX_MINUTES;
        }

        if (tariff == null) {
            tariff = Map.of();
        }
        tariff = Map.copyOf(tariff);

        // An unpriced treatment is a startup problem, not a 500 the first time somebody books it.
        EnumSet<TreatmentName> unpriced = EnumSet.allOf(TreatmentName.class);
        unpriced.removeAll(tariff.keySet());
        if (!unpriced.isEmpty()) {
            throw new IllegalStateException("No tariff configured for " + unpriced);
        }
    }

    public ZoneId zone() {
        return ZoneId.of(timezone);
    }

    // Total by construction: the constructor refuses to start without every treatment.
    public Tariff tariffFor(TreatmentName treatment) {
        return tariff.get(treatment);
    }

    // Copied onto the session at booking, so editing the tariff never re-prices booked work.
    public record Tariff(
            @NotNull @PositiveOrZero BigDecimal price,
            @NotNull @Positive Integer durationMinutes
    ) {
    }
}
