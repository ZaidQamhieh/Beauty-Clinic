package com.example.backend.services;

import com.example.backend.config.ClinicProperties;
import com.example.backend.entities.AppointmentSession;
import com.example.backend.repositories.AppointmentSessionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.Instant;

// A session nobody ever marked attended, past the same attendance window
// that lets a doctor add its record, becomes a no-show on its own - staff
// shouldn't have to notice and do it by hand, and the dashboard's no-show
// count depends on this actually being written to the database rather than
// just inferred on read. The cutoff deliberately reuses attendanceWindow()
// rather than its own setting, so a session goes to NO_SHOW at the exact
// moment it's no longer possible to mark it attended instead - the two can
// never drift out of sync.
@Component
@RequiredArgsConstructor
@Slf4j
public class NoShowSweep {

    private final AppointmentSessionRepository sessions;
    private final AppointmentSessionService sessionService;
    private final ClinicProperties clinic;
    private final Clock clock;

    @Value("${app.appointments.no-show-sweep.enabled:true}")
    private boolean enabled;

    @Scheduled(cron = "${app.appointments.no-show-sweep.cron:0 */5 * * * *}")
    public void sweep() {
        if (!enabled) {
            return;
        }

        Instant cutoff = clock.instant().minus(clinic.attendanceWindow());
        int marked = 0;

        for (AppointmentSession session : sessions.findPlannedEndedBefore(cutoff)) {
            try {
                // Reuses the same locking, validation, and cache eviction as a
                // staff-initiated no-show - one short transaction per session,
                // not one long one holding every row's lock at once.
                sessionService.markNoShow(session.getAppointment().getId(), session.getId());
                marked++;
            } catch (ResponseStatusException e) {
                // Raced with something else (attended, cancelled, already
                // marked) between the query and this call - leave it be.
            }
        }

        if (marked > 0) {
            log.info("No-show sweep: marked={}", marked);
        }
    }
}
