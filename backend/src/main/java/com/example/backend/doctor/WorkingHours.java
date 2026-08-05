package com.example.backend.doctor;

import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import java.time.LocalTime;

// One weekly working window for a doctor, stored as jsonb on the doctor row.
//
// dayOfWeek runs Sunday=0 through Saturday=6, matching JavaScript's
// Date.getDay() rather than java.time's Monday=1..Sunday=7 - the clinic week
// starts on Sunday, and clients send the number straight through.
//
// start and end are the clinic's local wall clock, resolved against
// app.clinic.timezone. They are not UTC and not the server's zone.
public record WorkingHours(
        @NotNull @Min(0) @Max(6) Short dayOfWeek,

        @NotNull
        @JsonFormat(pattern = "HH:mm")
        LocalTime start,

        @NotNull
        @JsonFormat(pattern = "HH:mm")
        LocalTime end
) {
}
