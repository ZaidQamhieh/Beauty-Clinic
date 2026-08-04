package com.example.backend.security;

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
}
