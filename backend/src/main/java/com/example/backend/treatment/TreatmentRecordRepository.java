package com.example.backend.treatment;

import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface TreatmentRecordRepository extends JpaRepository<TreatmentRecord, UUID> {

    Sort NEWEST_FIRST = Sort.by(Sort.Direction.DESC, "createdAt");

    List<TreatmentRecord> findByAppointmentPatientId(UUID patientId, Sort sort);

    List<TreatmentRecord> findByAppointmentId(UUID appointmentId, Sort sort);
}
