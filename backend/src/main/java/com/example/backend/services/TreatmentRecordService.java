package com.example.backend.services;

import com.example.backend.dtos.AmendTreatmentRecordRequest;
import com.example.backend.dtos.CreateTreatmentRecordRequest;
import com.example.backend.dtos.TreatmentRecordResponse;
import com.example.backend.entities.Appointment;
import com.example.backend.entities.TreatmentRecord;
import com.example.backend.repositories.AppointmentRepository;
import com.example.backend.repositories.TreatmentRecordRepository;
import com.example.backend.repositories.UserAccountRepository;
import com.example.backend.security.CurrentUser;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class TreatmentRecordService {

    private final TreatmentRecordRepository records;
    private final AppointmentRepository appointments;
    private final UserAccountRepository users;
    private final CurrentUser currentUser;

    @Transactional(readOnly = true)
    public List<TreatmentRecordResponse> list(UUID patientId) {
        return records.findByAppointmentPatientIdOrderByCreatedAtDesc(patientId).stream()
                .map(TreatmentRecordResponse::of)
                .toList();
    }

    @Transactional
    public TreatmentRecordResponse create(UUID patientId, CreateTreatmentRecordRequest request) {
        Appointment appointment = appointments.findById(request.appointmentId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such appointment"));

        if (!appointment.getPatient().getId().equals(patientId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No such appointment for this patient");
        }

        TreatmentRecord record = new TreatmentRecord(appointment, users.getReferenceById(currentUser.requireId()));
        record.setDiagnosis(request.diagnosis());
        record.setTreatment(request.treatment());
        record.setNotes(request.notes());

        return TreatmentRecordResponse.of(records.save(record));
    }

    @Transactional
    public TreatmentRecordResponse amend(UUID patientId, UUID recordId, AmendTreatmentRecordRequest request) {
        TreatmentRecord original = records.findById(recordId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No such treatment record"));

        if (!original.getAppointment().getPatient().getId().equals(patientId)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "No such treatment record for this patient");
        }

        TreatmentRecord correction = new TreatmentRecord(
                original.getAppointment(), users.getReferenceById(currentUser.requireId())
        );
        correction.setDiagnosis(request.diagnosis());
        correction.setTreatment(request.treatment());
        correction.setNotes(request.notes());
        correction.setAmends(original);

        return TreatmentRecordResponse.of(records.save(correction));
    }
}
