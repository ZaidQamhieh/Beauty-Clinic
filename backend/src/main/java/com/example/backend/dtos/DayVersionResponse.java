package com.example.backend.dtos;

import java.time.LocalDate;

// Polled instead of the slot list.
public record DayVersionResponse(
        LocalDate date,
        String version
) {
}
