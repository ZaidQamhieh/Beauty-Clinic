package com.example.backend.dtos;

import java.time.Instant;

public record FreeSlotResponse(Instant startTime, Instant endTime) {
}
