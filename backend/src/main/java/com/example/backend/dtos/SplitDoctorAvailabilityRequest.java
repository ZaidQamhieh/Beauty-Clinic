package com.example.backend.dtos;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

// Splits an already-started availability window in two, atomically: the
// existing row is truncated to end the day before splitDate, leaving exactly
// what it already covered untouched, and newSegment (when present) becomes a
// fresh row starting on splitDate. A null newSegment just drops everything
// from splitDate onward with nothing to replace it - a "delete the future,
// keep the past" removal rather than an edit.
public record SplitDoctorAvailabilityRequest(
        @NotNull LocalDate splitDate,
        @Valid CreateDoctorAvailabilityRequest newSegment
) {
}
