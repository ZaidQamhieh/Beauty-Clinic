package com.example.backend.dtos;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.UUID;

// One visit, every treatment chosen for it. Reuses AddSessionRequest rather than repeating it.
public record BookAppointmentRequest(
        @NotNull UUID patientUserId,
        // Capped: the checks are pairwise and run while the patient's row is locked.
        @NotEmpty @Size(max = 10) List<@Valid @NotNull AddSessionRequest> sessions,
        // On a reschedule, the visit this replaces; cancelled in the same transaction.
        UUID replacesAppointmentId
) {
}
