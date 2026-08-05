package com.example.backend.dtos;

import jakarta.validation.constraints.NotNull;

import java.util.Set;
import java.util.UUID;

public record SetDoctorServicesRequest(
        @NotNull Set<UUID> serviceIds
) {
}
