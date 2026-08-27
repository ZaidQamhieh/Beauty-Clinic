package com.example.backend.services;

import com.example.backend.repositories.RefreshTokenRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

// Abandoned sessions age out of the table.
@Component
@RequiredArgsConstructor
@Slf4j
public class RefreshTokenRetention {

    private final RefreshTokenRepository refreshTokens;

    @Value("${app.auth.tokens.retention.enabled:true}")
    private boolean enabled;

    @Transactional
    @Scheduled(cron = "${app.auth.tokens.retention.cron:0 50 3 * * *}")
    public void purge() {
        if (!enabled) {
            return;
        }

        // Already unusable; rotation checks expiry.
        int removed = refreshTokens.deleteExpiredBefore(Instant.now());

        if (removed > 0) {
            log.info("Refresh token purge: removed={}", removed);
        }
    }
}
