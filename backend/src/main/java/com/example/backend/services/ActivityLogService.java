package com.example.backend.services;

import com.example.backend.entities.ActivityAction;
import com.example.backend.entities.ActivityLog;
import com.example.backend.repositories.ActivityLogRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class ActivityLogService {

    private final ActivityLogRepository activityLogs;

    @Transactional
    public void recordLogin(UUID userId) {
        recordUserEvent(userId, ActivityAction.LOGIN);
    }

    @Transactional
    public void recordLogout(UUID userId) {
        recordUserEvent(userId, ActivityAction.LOGOUT);
    }

    // Must survive the rejected login transaction rolling back.
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordFailedLogin(String attemptedIdentifier) {
        activityLogs.save(
                ActivityLog.failedLogin(attemptedIdentifier)
        );
    }

    // Permission denial may cause the original transaction to roll back.
    @Transactional
    public void recordPermissionDenied(Optional<UUID> userId) {
        activityLogs.save(
                ActivityLog.permissionDenied(userId.orElse(null))
        );
    }

    private void recordUserEvent(
            UUID userId,
            ActivityAction action
    ) {
        activityLogs.save(
                ActivityLog.forUser(userId, action)
        );
    }
}
