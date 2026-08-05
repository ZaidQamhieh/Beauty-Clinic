package com.example.backend.dtos;

import com.example.backend.entities.ClinicService;

import java.math.BigDecimal;
import java.util.UUID;

public record ServiceResponse(
        UUID id,
        String name,
        String nameAr,
        Integer durationMinutes,
        BigDecimal price,
        boolean active
) {
    public static ServiceResponse of(ClinicService service) {
        return new ServiceResponse(
                service.getId(),
                service.getName(),
                service.getNameAr(),
                service.getDurationMinutes(),
                service.getPrice(),
                service.isActive()
        );
    }
}
