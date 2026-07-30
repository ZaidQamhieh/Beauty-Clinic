package com.example.backend.security;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
class RoleGuardTestController {

    @GetMapping("/test/doctor-only")
    @RequireRole(Role.DOCTOR)
    String doctorOnly() {
        return "ok";
    }

    @GetMapping("/test/open")
    String open() {
        return "ok";
    }
}
