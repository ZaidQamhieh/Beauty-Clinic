package com.example.backend.doctor;

import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import java.time.LocalTime;

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
