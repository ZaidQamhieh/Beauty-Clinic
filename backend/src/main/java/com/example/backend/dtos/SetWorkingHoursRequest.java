package com.example.backend.dtos;

import com.example.backend.entities.WorkingHours;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

import java.util.List;

// The list is wrapped rather than posted bare because @Valid on a raw
// List<WorkingHours> body validates the list object itself, which carries no
// constraints - the per-window rules would never run. The element-level @Valid
// below is what actually reaches them.
public record SetWorkingHoursRequest(
        @NotNull List<@Valid WorkingHours> availability
) {
}
