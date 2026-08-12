package com.example.backend.dtos;

import com.example.backend.config.ClinicProperties;

// Booking rules the client must respect.
public record BookingRulesResponse(
        String timezone,
        int maxHorizonDays,
        int slotGranularityMinutes,
        int turnoverMinutes,
        int cancellationCutoffMinutes
) {
    public static BookingRulesResponse of(ClinicProperties clinic) {
        return new BookingRulesResponse(
                clinic.timezone(),
                clinic.maxHorizonDays(),
                clinic.slotGranularityMinutes(),
                clinic.turnoverMinutes(),
                clinic.cancellationCutoffMinutes());
    }
}
