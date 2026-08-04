package com.example.backend.catalogue.dto;

import com.example.backend.catalogue.ClinicService;

import java.math.BigDecimal;
import java.util.UUID;

public record ServiceView(
        UUID id,
        String name,
        String nameAr,
        Integer durationMinutes,
        BigDecimal price,
        boolean active
) {
    public static ServiceView of(ClinicService service) {
        return new ServiceView(
                service.getId(),
                service.getName(),
                service.getNameAr(),
                service.getDurationMinutes(),
                service.getPrice(),
                service.isActive()
        );
    }
}
