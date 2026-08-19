package com.example.backend.dtos;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.List;

// One turn from the patient.
public record ChatRequest(
        @NotBlank @Size(max = 300) String message,
        @Size(max = 40) List<@Valid ChatTurn> history
) {

    public List<ChatTurn> historyOrEmpty() {
        return history == null ? List.of() : history;
    }
}
