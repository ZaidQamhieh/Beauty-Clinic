package com.example.backend.dtos;

import com.example.backend.entities.AppointmentSession.TreatmentName;
import jakarta.validation.Valid;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

// A body, not a query string: it carries picks made for a visit that is not stored yet.
public record FreeSlotQuery(
        @NotNull TreatmentName treatmentName,
        @NotNull LocalDate date,
        // Null asks every doctor qualified for the treatment.
        UUID doctorId,
        // Null skips the patient's own clashes; naming them keeps unbookable times off the list.
        UUID patientUserId,
        // Earlier picks in the same visit. They hold their doctor and the patient alike.
        List<@Valid HeldSlot> held,
        // While rescheduling: the visit being replaced, whose times are offered, not held.
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

        // A backwards or empty pick would silently widen the search instead of narrowing it.
        @AssertTrue(message = "endTime must be after startTime")
        private boolean isSpanOrdered() {
            return startTime == null || endTime == null || endTime.isAfter(startTime);
        }
    }
}
