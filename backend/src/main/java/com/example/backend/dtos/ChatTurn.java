package com.example.backend.dtos;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

// One past line from the client.
public record ChatTurn(
        @NotNull Boolean fromPatient,
        @Size(max = 4000) String text
) {
}
