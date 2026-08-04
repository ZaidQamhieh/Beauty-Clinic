package com.example.backend.catalogue.dto;

import com.example.backend.catalogue.ClinicService;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.util.UUID;

public final class ServiceDtos {

    private ServiceDtos() {
    }

    public record View(
            UUID id,
            String name,
            String nameAr,
            Integer durationMinutes,
            BigDecimal price,
            boolean active
    ) {
        public static View of(ClinicService service) {
            return new View(
                    service.getId(),
                    service.getName(),
                    service.getNameAr(),
                    service.getDurationMinutes(),
                    service.getPrice(),
                    service.isActive()
            );
        }
    }

    public record Upsert(
            @NotBlank @Size(max = 150) String name,
            @Size(max = 150) String nameAr,
            @NotNull @Positive Integer durationMinutes,
            @NotNull @PositiveOrZero BigDecimal price
    ) {
    }
}
