package com.example.backend.controllers;

import com.example.backend.dtos.AddSessionRequest;
import com.example.backend.dtos.AppointmentSessionResponse;
import com.example.backend.security.access.ClinicStaffOnly;
import com.example.backend.services.AppointmentSessionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/appointments/{appointmentId}/sessions")
@RequiredArgsConstructor
public class AppointmentSessionController {

    private final AppointmentSessionService sessions;

    @GetMapping
    @ClinicStaffOnly
    public List<AppointmentSessionResponse> list(@PathVariable UUID appointmentId) {
        return sessions.list(appointmentId);
    }

    // A later treatment in the same visit, possibly a different practitioner.
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @ClinicStaffOnly
    public AppointmentSessionResponse add(
            @PathVariable UUID appointmentId,
            @Valid @RequestBody AddSessionRequest request
    ) {
        return sessions.add(appointmentId, request);
    }

    @PutMapping("/{sessionId}/cancel")
    @ClinicStaffOnly
    public AppointmentSessionResponse cancel(
            @PathVariable UUID appointmentId,
            @PathVariable UUID sessionId
    ) {
        return sessions.cancel(appointmentId, sessionId);
    }

    @PutMapping("/{sessionId}/attended")
    @ClinicStaffOnly
    public AppointmentSessionResponse markAttended(
            @PathVariable UUID appointmentId,
            @PathVariable UUID sessionId
    ) {
        return sessions.markAttended(appointmentId, sessionId);
    }

    @PutMapping("/{sessionId}/no-show")
    @ClinicStaffOnly
    public AppointmentSessionResponse markNoShow(
            @PathVariable UUID appointmentId,
            @PathVariable UUID sessionId
    ) {
        return sessions.markNoShow(appointmentId, sessionId);
    }
}
