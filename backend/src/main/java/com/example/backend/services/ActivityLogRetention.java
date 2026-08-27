package com.example.backend.services;

import com.example.backend.entities.ActivityCategory;
import com.example.backend.repositories.ActivityLogRepository;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;

// Audit rows age out by category.
@Component
@RequiredArgsConstructor
@Slf4j
public class ActivityLogRetention {

    private final ActivityLogRepository activityLogs;
    private final EntityManager entityManager;

    @Value("${app.activity-log.retention.enabled:true}")
    private boolean enabled;

    @Value("${app.activity-log.retention.clinical-months:0}")
    private int clinicalMonths;

    @Value("${app.activity-log.retention.admin-months:24}")
    private int adminMonths;

    @Value("${app.activity-log.retention.security-months:24}")
    private int securityMonths;

    @Transactional
    @Scheduled(cron = "${app.activity-log.retention.cron:0 40 3 * * *}")
    public void purge() {
        if (!enabled) {
            return;
        }

        // Trigger yields only to flagged transactions.
        entityManager.createNativeQuery("SET LOCAL app.purge = 'on'").executeUpdate();

        purge(ActivityCategory.CLINICAL, clinicalMonths);
        purge(ActivityCategory.ADMIN, adminMonths);
        purge(ActivityCategory.SECURITY, securityMonths);
    }

    // Zero months means keep forever.
    private void purge(ActivityCategory category, int months) {
        if (months <= 0) {
            return;
        }

        Instant before = Instant.now().minus(Duration.ofDays(months * 30L));
        int removed = activityLogs.deleteByCategoryOlderThan(category, before);

        if (removed > 0) {
            log.info("Activity log purge: category={} removed={}", category, removed);
        }
    }
}
