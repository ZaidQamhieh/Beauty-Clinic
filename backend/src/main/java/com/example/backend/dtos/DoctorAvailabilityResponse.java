package com.example.backend.dtos;

import com.example.backend.entities.DoctorAvailability.AvailabilityKind;
import com.example.backend.entities.DoctorAvailability;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

public record DoctorAvailabilityResponse(
        UUID id,
        AvailabilityKind kind,
        DayOfWeek dayOfWeek,
        LocalTime startTime,
        LocalTime endTime,
        LocalDate effectiveFrom,
        LocalDate effectiveTo
) {
    public static DoctorAvailabilityResponse of(DoctorAvailability availability) {
        return new DoctorAvailabilityResponse(
                availability.getId(),
                availability.getKind(),
                availability.getDayOfWeek(),
                availability.getStartTime(),
                availability.getEndTime(),
                availability.getEffectiveFrom(),
                availability.getEffectiveTo()
        );
    }
}
