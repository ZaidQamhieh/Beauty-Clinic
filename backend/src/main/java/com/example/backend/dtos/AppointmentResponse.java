package com.example.backend.dtos;

import com.example.backend.entities.Appointment;

import java.time.Instant;
import java.util.UUID;

public record AppointmentResponse(
        UUID id,
        UUID patientId,
        String patientName,
        UUID doctorId,
        String doctorName,
        UUID serviceId,
        String serviceName,
        Instant startTime,
        Instant endTime,
        String status,
        String reason
) {
    public static AppointmentResponse of(Appointment appointment) {
        return new AppointmentResponse(
                appointment.getId(),
                appointment.getPatient().getId(),
                appointment.getPatient().getFirstName() + " " + appointment.getPatient().getLastName(),
                appointment.getDoctor().getUserId(),
                appointment.getDoctor().getUser().getFullName(),
                appointment.getService().getId(),
                appointment.getService().getName(),
                appointment.getStartTime(),
                appointment.getEndTime(),
                appointment.getStatus().name(),
                appointment.getReason()
        );
    }
}
