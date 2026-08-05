package com.example.backend.repositories;

import com.example.backend.entities.TreatmentRecord;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface TreatmentRecordRepository extends JpaRepository<TreatmentRecord, UUID> {

    List<TreatmentRecord> findByAppointmentPatientIdOrderByCreatedAtDesc(UUID patientId);
}
