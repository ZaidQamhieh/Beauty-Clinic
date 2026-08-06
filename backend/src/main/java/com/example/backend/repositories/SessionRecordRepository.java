package com.example.backend.repositories;

import com.example.backend.entities.SessionRecord;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface SessionRecordRepository extends JpaRepository<SessionRecord, UUID> {

    Page<SessionRecord> findBySessionAppointmentPatientUserIdOrderByCreatedAtDesc(
            UUID patientUserId, Pageable pageable);
}
