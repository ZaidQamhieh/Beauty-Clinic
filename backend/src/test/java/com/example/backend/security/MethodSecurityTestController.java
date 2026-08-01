package com.example.backend.security;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
class MethodSecurityTestController {

    @GetMapping("/test/doctor-only")
    @PreAuthorize("hasRole('DOCTOR')")
    String doctorOnly() {
        return "ok";
    }

    @GetMapping("/test/open")
    String open() {
        return "ok";
    }
}
