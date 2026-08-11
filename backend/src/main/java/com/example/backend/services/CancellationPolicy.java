package com.example.backend.services;

import com.example.backend.config.ClinicProperties;
import com.example.backend.security.CurrentUser;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;

// The one cancellation cutoff. Cancelling a visit and cancelling one of its treatments ask here.
@Service
@RequiredArgsConstructor
public class CancellationPolicy {

    private final ClinicProperties clinic;
    private final CurrentUser currentUser;
    private final Clock clock;

    // Measured from the visit's own start, so one visit has one deadline whatever is dropped.
    public void assertCancellable(Instant visitStart) {
        Instant now = clock.instant();

        if (currentUser.isClinicStaff()) {
            if (!visitStart.isAfter(now)) {
                throw new ResponseStatusException(
                        HttpStatus.CONFLICT, "That appointment has already started");
            }
            return;
        }

        Duration cutoff = clinic.cancellationCutoff();
        Instant deadline = visitStart.minus(cutoff);

        // Inclusive: exactly the cutoff before the start is still in time.
        if (now.isAfter(deadline)) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "Cancellation closes " + cutoff.toMinutes() + " minutes before the appointment");
        }
    }

    // A patient may not book what they would have no right to cancel. The desk still may.
    public void assertLeavesRoomToCancel(Instant startTime) {
        if (currentUser.isClinicStaff()) {
            return;
        }

        Duration cutoff = clinic.cancellationCutoff();

        if (startTime.isBefore(clock.instant().plus(cutoff))) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "Patients book at least " + cutoff.toMinutes()
                            + " minutes ahead, so the booking can still be cancelled");
        }
    }

    // Asked about the patient whatever the caller's role, so staff can see the window they hold.
    public boolean patientWindowOpen(Instant visitStart) {
        return !clock.instant().isAfter(visitStart.minus(clinic.cancellationCutoff()));
    }
}
