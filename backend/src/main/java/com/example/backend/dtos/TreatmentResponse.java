package com.example.backend.dtos;

import com.example.backend.config.ClinicProperties.Tariff;
import com.example.backend.entities.AppointmentSession.TreatmentCategory;
import com.example.backend.entities.AppointmentSession.TreatmentName;

import java.math.BigDecimal;

// One bookable treatment, priced from the tariff.
public record TreatmentResponse(
        TreatmentName treatmentName,
        TreatmentCategory category,
        int durationMinutes,
        BigDecimal price
) {
    public static TreatmentResponse of(TreatmentName treatment, Tariff tariff) {
        return new TreatmentResponse(
                treatment,
                treatment.category(),
                tariff.durationMinutes(),
                tariff.price());
    }
}
