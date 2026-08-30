package com.example.backend.repositories;

import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.ActivityCategory;
import com.example.backend.entities.ActivityLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public interface ActivityLogRepository
        extends JpaRepository<ActivityLog, UUID>, JpaSpecificationExecutor<ActivityLog> {

    // Id settles rows sharing a timestamp.
    Page<ActivityLog> findByPatientUserIdAndActionOrderByCreatedAtDescIdDesc(
            UUID patientUserId, ActivityAction action, Pageable pageable);

    Page<ActivityLog> findByPatientUserIdAndActionInOrderByCreatedAtDescIdDesc(
            UUID patientUserId, List<ActivityAction> actions, Pageable pageable);

    long countByAction(ActivityAction action);

    // One view row per actor, patient, window.
    boolean existsByUserIdAndPatientUserIdAndActionAndCreatedAtAfter(
            UUID userId, UUID patientUserId, ActivityAction action, Instant since);

    // Purge runs with the guard flag set.
    @Modifying
    @Query("delete from ActivityLog l where l.category = :category and l.createdAt < :before")
    int deleteByCategoryOlderThan(
            @Param("category") ActivityCategory category, @Param("before") Instant before);
}
