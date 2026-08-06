package com.example.backend.security;

import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.AppointmentSessionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

// Ownership half of the policy; roles use tags. Patient identity is the account id.
@Component("access")
@RequiredArgsConstructor
public class AccessRules {

    private final CurrentUser currentUser;
    private final AppointmentRepository appointments;
    private final AppointmentSessionRepository sessions;

    @Transactional(readOnly = true)
    public boolean treats(UUID patientUserId) {
        return currentUser.id()
                .map(doctorUserId -> sessions.existsByPractitionerAndPatient(doctorUserId, patientUserId))
                .orElse(false);
    }

    // The appointment belongs to the patient record the caller owns.
    @Transactional(readOnly = true)
    public boolean ownsAppointment(UUID appointmentId) {
        return currentUser.id()
                .map(userId -> appointments.existsByIdAndPatientUserId(appointmentId, userId))
                .orElse(false);
    }

    public boolean isSelf(UUID userId) {
        return currentUser.is(userId);
    }
}
