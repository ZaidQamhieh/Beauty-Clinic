package com.example.backend.controllers;

import com.example.backend.dtos.DoctorResponse;
import com.example.backend.dtos.EditDoctorProfileRequest;
import com.example.backend.dtos.RegisterDoctorRequest;
import com.example.backend.dtos.SetDoctorServicesRequest;
import com.example.backend.dtos.SetWorkingHoursRequest;
import com.example.backend.security.access.AdminOnly;
import com.example.backend.security.access.Authenticated;
import com.example.backend.security.access.DoctorSelfOrAdmin;
import com.example.backend.services.DoctorService;
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
@RequestMapping("/api/doctors")
@RequiredArgsConstructor
public class DoctorController {

    private final DoctorService doctors;

    @GetMapping
    @Authenticated
    public List<DoctorResponse> list() {
        return doctors.list();
    }

    @GetMapping("/{userId}")
    @Authenticated
    public DoctorResponse read(@PathVariable UUID userId) {
        return doctors.read(userId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @AdminOnly
    public DoctorResponse register(@Valid @RequestBody RegisterDoctorRequest request) {
        return doctors.register(request);
    }

    @PutMapping("/{userId}")
    @DoctorSelfOrAdmin
    public DoctorResponse updateProfile(
            @PathVariable UUID userId,
            @Valid @RequestBody EditDoctorProfileRequest request
    ) {
        return doctors.updateProfile(userId, request);
    }

    @PutMapping("/{userId}/working-hours")
    @DoctorSelfOrAdmin
    public DoctorResponse setWorkingHours(
            @PathVariable UUID userId,
            @Valid @RequestBody SetWorkingHoursRequest request
    ) {
        return doctors.setWorkingHours(userId, request);
    }

    @PutMapping("/{userId}/services")
    @DoctorSelfOrAdmin
    public DoctorResponse setServices(
            @PathVariable UUID userId,
            @Valid @RequestBody SetDoctorServicesRequest request
    ) {
        return doctors.setServices(userId, request);
    }
}
