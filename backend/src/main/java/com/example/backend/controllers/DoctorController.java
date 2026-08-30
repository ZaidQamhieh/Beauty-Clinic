package com.example.backend.controllers;

import com.example.backend.dtos.CreateDoctorAvailabilityRequest;
import com.example.backend.dtos.DoctorAvailabilityDayStatus;
import com.example.backend.dtos.DoctorAvailabilityResponse;
import com.example.backend.dtos.DoctorResponse;
import com.example.backend.dtos.DoctorProfileRequest;
import com.example.backend.dtos.SplitDoctorAvailabilityRequest;
import com.example.backend.security.access.AdminOnly;
import com.example.backend.security.access.Authenticated;
import com.example.backend.security.access.DoctorSelfOrAdmin;
import com.example.backend.services.DoctorAvailabilityService;
import com.example.backend.services.DoctorService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/doctors")
@RequiredArgsConstructor
public class DoctorController {

    private final DoctorService doctors;
    private final DoctorAvailabilityService availability;

    // The landing page reads the doctor directory before sign-in.
    @GetMapping
    public List<DoctorResponse> list() {
        return doctors.list();
    }

    @GetMapping("/{userId}")
    @Authenticated
    public DoctorResponse read(@PathVariable UUID userId) {
        return doctors.read(userId);
    }

    // The path identifies the account, so register and edit share one body.
    @PostMapping("/{userId}")
    @ResponseStatus(HttpStatus.CREATED)
    @AdminOnly
    public DoctorResponse register(
            @PathVariable UUID userId,
            @Valid @RequestBody DoctorProfileRequest request) {
        return doctors.register(userId, request);
    }

    @PutMapping("/{userId}")
    @DoctorSelfOrAdmin
    public DoctorResponse updateProfile(
            @PathVariable UUID userId,
            @Valid @RequestBody DoctorProfileRequest request) {
        return doctors.updateProfile(userId, request);
    }

    @DeleteMapping("/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @AdminOnly
    public void delete(@PathVariable UUID userId) {
        doctors.delete(userId);
    }

    @GetMapping("/{userId}/availability")
    @Authenticated
    public List<DoctorAvailabilityResponse> listAvailability(@PathVariable UUID userId) {
        return availability.list(userId);
    }

    @GetMapping("/{userId}/availability/calendar")
    @Authenticated
    public List<DoctorAvailabilityDayStatus> availabilityCalendar(
            @PathVariable UUID userId,
            @RequestParam LocalDate from,
            @RequestParam LocalDate to) {
        return availability.calendarStatus(userId, from, to);
    }

    @PostMapping("/{userId}/availability")
    @ResponseStatus(HttpStatus.CREATED)
    @DoctorSelfOrAdmin
    public DoctorAvailabilityResponse addAvailability(
            @PathVariable UUID userId,
            @Valid @RequestBody CreateDoctorAvailabilityRequest request) {
        return availability.add(userId, request);
    }

    @PutMapping("/{userId}/availability/{availabilityId}")
    @DoctorSelfOrAdmin
    public DoctorAvailabilityResponse updateAvailability(
            @PathVariable UUID userId,
            @PathVariable UUID availabilityId,
            @Valid @RequestBody CreateDoctorAvailabilityRequest request) {
        return availability.update(userId, availabilityId, request);
    }

    @DeleteMapping("/{userId}/availability/{availabilityId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @DoctorSelfOrAdmin
    public void removeAvailability(
            @PathVariable UUID userId,
            @PathVariable UUID availabilityId) {
        availability.remove(userId, availabilityId);
    }

    @PostMapping("/{userId}/availability/{availabilityId}/split")
    @DoctorSelfOrAdmin
    public List<DoctorAvailabilityResponse> splitAvailability(
            @PathVariable UUID userId,
            @PathVariable UUID availabilityId,
            @Valid @RequestBody SplitDoctorAvailabilityRequest request) {
        return availability.split(userId, availabilityId, request);
    }

}
