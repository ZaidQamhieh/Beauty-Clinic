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
import java.time.Duration;
import java.time.ZoneId;
import java.util.EnumSet;
import java.util.Map;

// Working hours are wall clock, so resolve against the clinic's zone, not UTC.
@ConfigurationProperties(prefix = "app.clinic")
@Validated
public record ClinicProperties(
        @NotBlank String timezone,
        // Prices are quoted in this currency.
        String currency,
        @Valid Map<TreatmentName, Tariff> tariff,
        // How far ahead the calendar is open at all.
        Integer maxHorizonDays,
        // Slots are offered on this grid, so a 45-minute treatment is never offered at 09:47.
        Integer slotGranularityMinutes,
        // Room turnover held either side of every booking, on top of its own length.
        Integer turnoverMinutes,
        // How late a patient may still cancel, counted back from the visit's start.
        Integer cancellationCutoffMinutes
) {

    public static final String DEFAULT_CURRENCY = "ILS";
    public static final int DEFAULT_MAX_HORIZON_DAYS = 180;
    public static final int DEFAULT_SLOT_GRANULARITY_MINUTES = 15;
    public static final int DEFAULT_TURNOVER_MINUTES = 10;
    public static final int DEFAULT_CANCELLATION_CUTOFF_MINUTES = 60;

    public ClinicProperties {
        // Fail at startup on an unknown zone, not on the first booking.
        if (timezone != null && !timezone.isBlank()) {
            ZoneId.of(timezone);
        }

        if (currency == null || currency.isBlank()) {
            currency = DEFAULT_CURRENCY;
        }

        if (maxHorizonDays == null) {
            maxHorizonDays = DEFAULT_MAX_HORIZON_DAYS;
        }

        if (slotGranularityMinutes == null) {
            slotGranularityMinutes = DEFAULT_SLOT_GRANULARITY_MINUTES;
        }

        if (turnoverMinutes == null) {
            turnoverMinutes = DEFAULT_TURNOVER_MINUTES;
        }

        if (cancellationCutoffMinutes == null) {
            cancellationCutoffMinutes = DEFAULT_CANCELLATION_CUTOFF_MINUTES;
        }

        // A zero grid would loop forever walking a window; the rest may legitimately be zero.
        if (slotGranularityMinutes < 1) {
            throw new IllegalStateException("slot-granularity-minutes must be at least 1");
        }

        // A negative cutoff would let a patient cancel after the visit began.
        if (cancellationCutoffMinutes < 0) {
            throw new IllegalStateException("cancellation-cutoff-minutes must not be negative");
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

    public Duration horizon() {
        return Duration.ofDays(maxHorizonDays);
    }

    public Duration slotGranularity() {
        return Duration.ofMinutes(slotGranularityMinutes);
    }

    public Duration turnover() {
        return Duration.ofMinutes(turnoverMinutes);
    }

    public Duration cancellationCutoff() {
        return Duration.ofMinutes(cancellationCutoffMinutes);
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
