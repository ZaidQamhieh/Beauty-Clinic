package com.example.backend.dtos;

import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.UUID;

public record BookAppointmentRequest(
        @NotNull UUID patientId,
        @NotNull UUID doctorId,
        @NotNull UUID serviceId,
        @NotNull @FutureOrPresent Instant startTime,
        @Size(max = 255) String reason
) {
}
