package com.example.backend.security;

import com.example.backend.appointment.Appointment;
import com.example.backend.appointment.AppointmentRepository;
import com.example.backend.patient.PatientRepository;
import com.example.backend.treatment.TreatmentRecordRepository;
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
    private final TreatmentRecordRepository treatmentRecords;

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

    @Transactional(readOnly = true)
    public boolean ownsAppointment(UUID appointmentId) {
        return currentUser.id()
                .flatMap(userId -> appointments.findById(appointmentId)
                        .map(appointment -> appointment.isFor(userId)))
                .orElse(false);
    }

    @Transactional(readOnly = true)
    public boolean doctorOn(UUID appointmentId) {
        return currentUser.id()
                .flatMap(userId -> appointments.findById(appointmentId)
                        .map(appointment -> appointment.isTreatedBy(userId)))
                .orElse(false);
    }

    @Transactional(readOnly = true)
    public boolean partyTo(UUID appointmentId) {
        return currentUser.id()
                .flatMap(userId -> appointments.findById(appointmentId)
                        .map(appointment -> involves(appointment, userId)))
                .orElse(false);
    }

    @Transactional(readOnly = true)
    public boolean ownsRecord(UUID recordId) {
        return currentUser.id()
                .flatMap(userId -> treatmentRecords.findById(recordId)
                        .map(record -> record.getAppointment().isFor(userId)))
                .orElse(false);
    }

    @Transactional(readOnly = true)
    public boolean wroteRecord(UUID recordId) {
        return currentUser.id()
                .flatMap(userId -> treatmentRecords.findById(recordId)
                        .map(record -> record.getAppointment().isTreatedBy(userId)))
                .orElse(false);
    }

    public boolean isSelf(UUID userId) {
        return currentUser.is(userId);
    }

    private boolean involves(Appointment appointment, UUID userId) {
        return appointment.isFor(userId) || appointment.isTreatedBy(userId);
    }
}
