package com.example.backend.dtos;

public record AmendTreatmentRecordRequest(
        String diagnosis,
        String treatment,
        String notes
) {
}
