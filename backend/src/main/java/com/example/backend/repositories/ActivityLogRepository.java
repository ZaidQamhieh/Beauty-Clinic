package com.example.backend.repositories;

import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.ActivityLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Collection;
import java.util.UUID;

public interface ActivityLogRepository
        extends JpaRepository<ActivityLog, UUID>, JpaSpecificationExecutor<ActivityLog> {

    // Id settles rows sharing a timestamp.
    Page<ActivityLog> findByPatientUserIdAndActionOrderByCreatedAtDescIdDesc(
            UUID patientUserId, ActivityAction action, Pageable pageable);

    // Every parameter bound, so Postgres types it.
    @Query("""
            select log from ActivityLog log
            where (:action is null or log.action = :action)
              and log.createdAt >= :from
              and log.createdAt < :to
              and (
                    :searching = false
                 or log.userId = :id
                 or log.patientUserId = :id
                 or log.entityId = :id
                 or lower(coalesce(log.attemptedIdentifier, '')) like :text escape '!'
                 or lower(coalesce(log.entityType, '')) like :text escape '!'
                 or log.userId in :actorIds
                 or log.patientUserId in :actorIds
              )
            """)
    Page<ActivityLog> search(
            @Param("action") ActivityAction action,
            @Param("from") Instant from,
            @Param("to") Instant to,
            @Param("searching") boolean searching,
            @Param("text") String text,
            @Param("id") UUID id,
            @Param("actorIds") Collection<UUID> actorIds,
            Pageable pageable
    );
}
