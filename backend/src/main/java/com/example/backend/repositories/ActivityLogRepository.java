package com.example.backend.repositories;

import com.example.backend.entities.ActivityLog;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface ActivityLogRepository
        extends JpaRepository<ActivityLog, UUID> {
}
