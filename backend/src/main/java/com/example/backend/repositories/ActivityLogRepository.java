package com.example.backend.repositories;

import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.ActivityLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import java.util.UUID;

public interface ActivityLogRepository
        extends JpaRepository<ActivityLog, UUID>, JpaSpecificationExecutor<ActivityLog> {

    // Id settles rows sharing a timestamp.
    Page<ActivityLog> findByPatientUserIdAndActionOrderByCreatedAtDescIdDesc(
            UUID patientUserId, ActivityAction action, Pageable pageable);
}
