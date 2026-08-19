package com.example.backend.dtos;

import com.example.backend.entities.AppointmentSession.TreatmentName;
import jakarta.validation.Valid;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

// A body: carries picks not yet stored.
public record FreeSlotQuery(
        @NotNull TreatmentName treatmentName,
        // Null means today, clinic zone.
        LocalDate date,
        // Null asks every qualified doctor.
        UUID doctorId,
        // Null means caller; staff must name.
        UUID patientUserId,
        // Earlier picks; hold doctor and patient.
        @Size(max = 10) List<@Valid HeldSlot> held,
        // Replaced visit; its times are offered.
        UUID replacesAppointmentId
) {

    public FreeSlotQuery {
        if (held == null) {
            held = List.of();
        }
        held = List.copyOf(held);
    }

    public record HeldSlot(
            @NotNull UUID practitionerUserId,
            @NotNull Instant startTime,
            @NotNull Instant endTime
    ) {

        // Backwards picks would widen the search.
        @AssertTrue(message = "endTime must be after startTime")
        private boolean isSpanOrdered() {
            return startTime == null || endTime == null || endTime.isAfter(startTime);
        }
    }
}
