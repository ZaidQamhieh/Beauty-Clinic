package com.example.backend.dtos;

import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;

public record RescheduleAppointmentRequest(
        @NotNull @FutureOrPresent Instant startTime
) {
}
