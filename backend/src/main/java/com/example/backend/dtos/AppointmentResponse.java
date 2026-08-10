package com.example.backend.dtos;

import com.example.backend.entities.Appointment;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

// Appointment holds no collection of sessions, so callers fetch and pass them in.
public record AppointmentResponse(
        UUID id,
        UUID patientUserId,
        String patientName,
        Instant scheduledAt,
        String status,
        UUID replacesAppointmentId,
        List<AppointmentSessionResponse> sessions
) {
    public static AppointmentResponse of(Appointment appointment, List<AppointmentSessionResponse> sessions) {
        return new AppointmentResponse(
                appointment.getId(),
                appointment.getPatient().getUserId(),
                appointment.getPatient().getUser().fullName(),
                appointment.getScheduledAt(),
                appointment.getStatus().name(),
                replacedIdOf(appointment),
                sessions
        );
    }

    // Null for a first booking: only a reschedule leaves an appointment behind.
    private static UUID replacedIdOf(Appointment appointment) {
        if (appointment.getReplaces() == null) {
            return null;
        }
        return appointment.getReplaces().getId();
    }
}
