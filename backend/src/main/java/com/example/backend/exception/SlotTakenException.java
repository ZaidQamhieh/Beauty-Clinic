package com.example.backend.exception;

import java.time.Instant;
import java.util.UUID;

// A booking that lost its slot between being offered one and confirming it.
public class SlotTakenException extends RuntimeException {

    // Null until a caller names the pick; the checks themselves only know times.
    private final String treatmentName;
    private final UUID practitionerUserId;
    private final Instant startTime;

    public SlotTakenException(String message) {
        this(message, null, null, null);
    }

    private SlotTakenException(
            String message, String treatmentName, UUID practitionerUserId, Instant startTime) {
        super(message);
        this.treatmentName = treatmentName;
        this.practitionerUserId = practitionerUserId;
        this.startTime = startTime;
    }

    // Which pick lost, so a client drops that one and keeps the rest.
    public SlotTakenException forSlot(String treatment, UUID practitioner, Instant start) {
        return new SlotTakenException(getMessage(), treatment, practitioner, start);
    }

    public String getTreatmentName() {
        return treatmentName;
    }

    public UUID getPractitionerUserId() {
        return practitionerUserId;
    }

    public Instant getStartTime() {
        return startTime;
    }
}
