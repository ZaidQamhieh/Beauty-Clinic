package com.example.backend.dtos;

import com.example.backend.entities.TreatmentRecord;

import java.time.Instant;
import java.util.UUID;

public record TreatmentRecordResponse(
        UUID id,
        UUID appointmentId,
        String diagnosis,
        String treatment,
        String notes,
        String recordedByName,
        Instant createdAt,
        UUID amendsId
) {
    public static TreatmentRecordResponse of(TreatmentRecord record) {
        return new TreatmentRecordResponse(
                record.getId(),
                record.getAppointment().getId(),
                record.getDiagnosis(),
                record.getTreatment(),
                record.getNotes(),
                record.getRecordedBy().getFullName(),
                record.getCreatedAt(),
                record.getAmends() != null ? record.getAmends().getId() : null
        );
    }
}
