package com.example.backend.dtos;

import java.time.Instant;
import java.util.UUID;

// Carries its doctor, so one flat list groups by doctor or by time on the client.
public record FreeSlotResponse(
        UUID practitionerUserId,
        String practitionerName,
        Instant startTime,
        Instant endTime
) {
}
