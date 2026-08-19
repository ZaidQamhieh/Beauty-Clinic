package com.example.backend.dtos;

import com.example.backend.entities.AppointmentSession;
import com.example.backend.entities.AppointmentSession.TreatmentCategory;
import com.example.backend.entities.AppointmentSession.TreatmentName;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record AppointmentSessionResponse(
        UUID id,
        UUID appointmentId,
        UUID practitionerUserId,
        String practitionerName,
        TreatmentCategory category,
        TreatmentName treatmentName,
        BigDecimal priceCharged,
        int durationMinutes,
        String status,
        Instant startTime,
        Instant endTime,
        String beforePhotoKey,
        String afterPhotoKey
) {
    public static AppointmentSessionResponse of(AppointmentSession session) {
        return new AppointmentSessionResponse(
                session.getId(),
                session.getAppointment().getId(),
                session.getPractitioner().getUserId(),
                session.getPractitioner().getUser().fullName(),
                session.getCategory(),
                session.getTreatmentName(),
                session.getPriceCharged(),
                session.getDurationMinutes(),
                session.getStatus().name(),
                session.getStartTime(),
                session.getEndTime(),
                session.getBeforePhotoKey(),
                session.getAfterPhotoKey()
        );
    }
}
