package com.example.backend.security;

import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.PatientRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

// Ownership half of the policy. Roles use tags; anything about whose data it is comes here.
@Component("access")
@RequiredArgsConstructor
public class AccessRules {

    private final CurrentUser currentUser;
    private final PatientRepository patients;
    private final AppointmentRepository appointments;

    @Transactional(readOnly = true)
    public boolean ownsPatient(UUID patientId) {
        return currentUser.id()
                .map(userId -> patients.existsByIdAndUserId(patientId, userId))
                .orElse(false);
    }

    @Transactional(readOnly = true)
    public boolean treats(UUID patientId) {
        return currentUser.id()
                .map(doctorUserId ->
                        appointments.existsByDoctorUserIdAndPatientId(doctorUserId, patientId))
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
