package com.example.backend.dtos;

import java.time.LocalDate;

public record DoctorAvailabilityDayStatus(LocalDate date, DayAvailabilityStatus status) {
}
