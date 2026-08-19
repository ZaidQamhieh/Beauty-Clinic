package com.example.backend.services;

import com.example.backend.config.ClinicProperties;
import com.example.backend.dtos.BookingRulesResponse;
import com.example.backend.dtos.TreatmentResponse;
import com.example.backend.entities.AppointmentSession.TreatmentName;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.List;

// The read side of the treatment tariff.
@Service
@RequiredArgsConstructor
public class TreatmentCatalogService {

    private final ClinicProperties clinic;

    public List<TreatmentResponse> list() {
        return Arrays.stream(TreatmentName.values())
                .map(treatment -> TreatmentResponse.of(treatment, clinic.tariffFor(treatment)))
                .toList();
    }

    public BookingRulesResponse rules() {
        return BookingRulesResponse.of(clinic);
    }
}
