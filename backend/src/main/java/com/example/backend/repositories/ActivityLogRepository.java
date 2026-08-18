package com.example.backend.repositories;

import com.example.backend.entities.ActivityLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.UUID;

public interface ActivityLogRepository
        extends JpaRepository<ActivityLog, UUID> {
    Page<ActivityLog> findByPatientUserIdAndActionOrderByCreatedAtDesc(
            UUID patientUserId, com.example.backend.entities.ActivityAction action, Pageable pageable);

    @Query("""
            select log from ActivityLog log
            where (:action is null or log.action = :action)
              and (:from is null or log.createdAt >= :from)
              and (:to is null or log.createdAt < :to)
              and (:search is null or (lower(coalesce(log.attemptedIdentifier, '')) like lower(concat('%', :search, '%'))
                   or lower(coalesce(log.entityType, '')) like lower(concat('%', :search, '%'))
                   or cast(log.userId as string) like concat('%', :search, '%')
                   or cast(log.patientUserId as string) like concat('%', :search, '%')
                   or cast(log.entityId as string) like concat('%', :search, '%')))
            """)
    Page<ActivityLog> search(
            @Param("action") com.example.backend.entities.ActivityAction action,
            @Param("from") Instant from,
            @Param("to") Instant to,
            @Param("search") String search,
            Pageable pageable
    );
}
