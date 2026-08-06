package com.example.backend.repositories;

import com.example.backend.entities.SessionRecord;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface SessionRecordRepository extends JpaRepository<SessionRecord, UUID> {

    List<SessionRecord> findBySessionAppointmentPatientUserIdOrderByCreatedAtDesc(UUID patientUserId);
}
