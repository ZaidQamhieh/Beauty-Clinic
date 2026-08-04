package com.example.backend.security;

import com.example.backend.security.access.AdminOnly;
import com.example.backend.security.access.Authenticated;
import com.example.backend.security.access.ClinicStaffOnly;
import com.example.backend.security.access.PatientOnly;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequiredArgsConstructor
class MethodSecurityTestController {

    private final CurrentUser currentUser;

    @GetMapping("/test/doctor-only")
    @PreAuthorize("hasRole('DOCTOR')")
    String doctorOnly() {
        return "ok";
    }

    @GetMapping("/test/open")
    String open() {
        return "ok";
    }

    @GetMapping("/test/me")
    String me() {
        return currentUser.requireId().toString();
    }

    @GetMapping("/test/owned-by/{userId}")
    @PreAuthorize("@currentUser.is(#userId)")
    String ownedBy(@PathVariable UUID userId) {
        return "ok";
    }

    @GetMapping("/test/meta/staff")
    @ClinicStaffOnly
    String staffOnly() {
        return "ok";
    }

    @GetMapping("/test/meta/admin")
    @AdminOnly
    String adminOnly() {
        return "ok";
    }

    @GetMapping("/test/meta/patient")
    @PatientOnly
    String patientOnly() {
        return "ok";
    }

    @GetMapping("/test/meta/any")
    @Authenticated
    String anySignedIn() {
        return "ok";
    }
}
