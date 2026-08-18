package com.example.backend.repositories;

import com.example.backend.entities.ActivityLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface ActivityLogRepository
        extends JpaRepository<ActivityLog, UUID> {
    Page<ActivityLog> findByPatientUserIdAndActionOrderByCreatedAtDesc(
            UUID patientUserId, com.example.backend.entities.ActivityAction action, Pageable pageable);
}
