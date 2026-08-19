package com.example.backend.dtos;

import jakarta.validation.constraints.Size;

// Patient editing themselves. No clinical field, so none can be written.
public record EditOwnProfileRequest(
        @Size(max = 30) String phone
) {
}
