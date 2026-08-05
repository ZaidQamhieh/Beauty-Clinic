package com.example.backend.dtos;

import com.example.backend.entities.ClinicService;

import java.math.BigDecimal;
import java.util.UUID;

public record ClinicServiceResponse(
        UUID id,
        String name,
        String nameAr,
        Integer durationMinutes,
        BigDecimal price,
        boolean active
) {
    public static ClinicServiceResponse of(ClinicService service) {
        return new ClinicServiceResponse(
                service.getId(),
                service.getName(),
                service.getNameAr(),
                service.getDurationMinutes(),
                service.getPrice(),
                service.isActive()
        );
    }
}
